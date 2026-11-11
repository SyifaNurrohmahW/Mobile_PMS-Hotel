import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';

final apiClientProvider = Provider<Dio>((ref) {
  const storage = SecureStorageService();
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final customBaseUrl = await storage.read('custom_api_base_url');
        if (customBaseUrl != null && customBaseUrl.trim().isNotEmpty) {
          AppConfig.runtimeApiBaseUrl = customBaseUrl.trim();
        }
        options.baseUrl = AppConfig.effectiveApiBaseUrl;

        final accessToken = await storage.read('access_token');
        final branchCode = await storage.read('active_branch_code');
        final timestamp = DateTime.now().toUtc().toIso8601String();

        options.headers['X-Timestamp'] = timestamp;
        options.headers['x-uniqueid'] = 'USR000000';
        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        options.headers['X-Branch-Code'] =
            (branchCode != null && branchCode.isNotEmpty)
                ? branchCode
                : 'CAB0001';
        handler.next(options);
      },
      onError: (error, handler) async {
        final request = error.requestOptions;

        // Auto-failover jika IP Wi-Fi berubah dan custom_api_base_url lama timeout
        if ((error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.connectionError) &&
            request.extra['retriedCandidateHost'] != true) {
          request.extra['retriedCandidateHost'] = true;
          for (final candidate in AppConfig.fallbackCandidateUrls) {
            if (candidate == request.baseUrl) continue;
            try {
              final probeDio = Dio(
                BaseOptions(
                  baseUrl: candidate,
                  connectTimeout: const Duration(seconds: 3),
                  receiveTimeout: const Duration(seconds: 4),
                ),
              );
              final retryReq = request.copyWith(
                baseUrl: candidate,
                headers: {
                  ...request.headers,
                  'X-Timestamp': DateTime.now().toUtc().toIso8601String(),
                },
              );
              final probeRes = await probeDio.fetch(retryReq);
              AppConfig.runtimeApiBaseUrl = candidate;
              await storage.write('custom_api_base_url', candidate);
              handler.resolve(probeRes);
              return;
            } catch (_) {}
          }
        }

        if (error.response?.statusCode == 401 &&
            request.extra['retriedAfterRefresh'] != true &&
            !request.path.endsWith('/auth/refresh-token') &&
            !request.path.endsWith('/auth/login')) {
          final refreshed = await _handleRefreshToken(dio, storage);
          if (refreshed) {
            request.extra['retriedAfterRefresh'] = true;
            final token = await storage.read('access_token');
            final branchCode = await storage.read('active_branch_code');
            request.headers['X-Timestamp'] =
                DateTime.now().toUtc().toIso8601String();
            if (token != null && token.isNotEmpty) {
              request.headers['Authorization'] = 'Bearer $token';
            }
            if (branchCode != null && branchCode.isNotEmpty) {
              request.headers['X-Branch-Code'] = branchCode;
            }
            try {
              final retryResponse = await dio.fetch(request);
              handler.resolve(retryResponse);
              return;
            } on DioException catch (retryError) {
              handler.next(retryError);
              return;
            }
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

Future<bool> _handleRefreshToken(Dio dio, SecureStorageService storage) async {
  final refreshToken = await storage.read('refresh_token');
  final userCode = await storage.read('user_code');
  if (refreshToken == null ||
      refreshToken.isEmpty ||
      userCode == null ||
      userCode.isEmpty) {
    await storage.clear();
    return false;
  }

  try {
    final response = await dio.post(
      '/auth/refresh-token',
      data: {
        'user_code': userCode,
        'refresh_token': refreshToken,
        'remember_me': await storage.read('remember_me') ?? '0',
      },
      options: Options(
        headers: {
          'X-Timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      ),
    );

    if (response.statusCode == 200 && response.data is Map) {
      final body = Map<String, dynamic>.from(response.data as Map);
      final data = body['data'];
      if (data is Map) {
        final newAccess = data['access_token']?.toString();
        final newRefresh = data['refresh_token']?.toString();
        if (newAccess != null &&
            newAccess.isNotEmpty &&
            newRefresh != null &&
            newRefresh.isNotEmpty) {
          await storage.write('access_token', newAccess);
          await storage.write('refresh_token', newRefresh);
          return true;
        }
      }
    }
    await storage.clear();
    return false;
  } on DioException {
    await storage.clear();
    return false;
  }
}

class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await dio.get(path);
      return _handleResponse(response);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    try {
      final response = await dio.post(path, data: data ?? const {});
      return _handleResponse(response);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    final body = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};

    final statusCode = response.statusCode ?? 200;
    final businessStatus = body['status']?.toString();

    if (statusCode >= 400) {
      throw ApiException(
        message: body['message']?.toString() ?? 'Permintaan gagal diproses.',
        statusCode: statusCode,
        code: businessStatus,
      );
    }

    // Check business envelope status ("00" = SUKSES, "03" = NOT_FOUND, "01" = GAGAL, "99" = BAD_REQUEST)
    if (businessStatus != null &&
        businessStatus != '00' &&
        businessStatus != 'SUKSES') {
      throw ApiException(
        message: body['message']?.toString() ?? 'Operasi gagal diproses.',
        statusCode: statusCode,
        code: businessStatus,
      );
    }

    return body;
  }

  ApiException _mapDioException(DioException error) {
    final response = error.response;
    if (response?.data is Map) {
      final map = Map<String, dynamic>.from(response!.data as Map);
      final msg = map['message']?.toString();
      final code = map['status']?.toString();
      if (msg != null && msg.isNotEmpty) {
        return ApiException(
          message: msg,
          statusCode: response.statusCode,
          code: code,
        );
      }
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const ApiException(
          message:
              'Waktu koneksi ke server habis. Periksa jaringan Wi-Fi/Data Anda.',
        ),
      DioExceptionType.connectionError => const ApiException(
          message:
              'Tidak dapat terhubung ke server PMS. Pastikan layanan backend aktif.',
        ),
      _ => ApiException(
          message: error.message ?? 'Terjadi gangguan jaringan.',
          statusCode: response?.statusCode,
        ),
    };
  }
}
