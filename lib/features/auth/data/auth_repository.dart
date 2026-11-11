import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/user_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ApiClient(ref.watch(apiClientProvider)),
    const SecureStorageService(),
  );
});

class AuthRepository {
  AuthRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  Future<UserSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _apiClient.post('/auth/login', {
      'username': username,
      'password': password,
      'remember_me': rememberMe ? '1' : '0',
    });

    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : null;
    final userInfo = data?['user_info'] is Map
        ? Map<String, dynamic>.from(data!['user_info'] as Map)
        : null;
    final accessToken = data?['access_token']?.toString();
    final refreshToken = data?['refresh_token']?.toString();

    if (accessToken == null ||
        refreshToken == null ||
        userInfo == null ||
        (userInfo['user_code']?.toString().isEmpty ?? true)) {
      throw const FormatException(
        'Respons login tidak memuat data sesi yang diperlukan.',
      );
    }

    final session = UserSession.fromJson(userInfo);
    await _persistSession(
      session: session,
      accessToken: accessToken,
      refreshToken: refreshToken,
      rememberMe: rememberMe ? '1' : '0',
    );
    return session;
  }

  Future<UserSession> fetchMe() async {
    final response = await _apiClient.post('/auth/me');
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};

    final session = UserSession.fromJson(data);
    await _persistSession(session: session);
    return session;
  }

  Future<UserSession> switchBranch({
    required String targetKodeCabang,
    required UserSession currentSession,
  }) async {
    final response = await _apiClient.post('/auth/switch-branch', {
      'target_kode_cabang': targetKodeCabang,
    });

    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};

    final accessToken = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();
    final activeBranch = data['active_branch'] is Map
        ? Map<String, dynamic>.from(data['active_branch'] as Map)
        : <String, dynamic>{};

    final newKode = activeBranch['kode_cabang']?.toString() ?? targetKodeCabang;
    final newName =
        activeBranch['nama_hotel']?.toString() ?? currentSession.activeBranchName;
    final newId = int.tryParse(activeBranch['id']?.toString() ?? '') ??
        currentSession.activeBranchId;

    final updatedSession = currentSession.copyWith(
      activeBranchId: newId,
      activeKodeCabang: newKode,
      activeBranchName: newName,
    );

    await _persistSession(
      session: updatedSession,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    return updatedSession;
  }

  Future<UserSession?> restoreSession() async {
    final token = await _storage.read('access_token');
    if (token == null || token.isEmpty) return null;

    try {
      return await fetchMe();
    } catch (_) {
      final cachedRaw = await _storage.read('user_session_json');
      final cached = UserSession.tryFromEncodedJson(cachedRaw);
      if (cached != null) {
        await _storage.clear();
      } else {
        await _storage.clear();
      }
      return null;
    }
  }

  Future<UserSession?> readCachedSession() async {
    final raw = await _storage.read('user_session_json');
    final parsed = UserSession.tryFromEncodedJson(raw);
    if (parsed != null) return parsed;

    final branchCode = await _storage.read('active_branch_code');
    if (branchCode == null || branchCode.isEmpty) return null;

    final fullName = await _storage.read('full_name') ?? 'Front Office';
    final role = await _storage.read('role') ?? 'frontdesk';
    final userCode = await _storage.read('user_code') ?? '';

    return UserSession(
      userId: 0,
      userCode: userCode,
      username: userCode,
      fullname: fullName,
      role: role,
      activeBranchId: 0,
      activeKodeCabang: branchCode,
      activeBranchName: branchCode,
      defaultKodeCabang: branchCode,
      defaultBranchName: branchCode,
      canSwitchBranch: false,
      allowedBranches: const [],
    );
  }

  Future<void> logout() => _storage.clear();

  Future<void> _persistSession({
    required UserSession session,
    String? accessToken,
    String? refreshToken,
    String? rememberMe,
  }) async {
    if (accessToken != null && accessToken.isNotEmpty) {
      await _storage.write('access_token', accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write('refresh_token', refreshToken);
    }
    if (rememberMe != null) {
      await _storage.write('remember_me', rememberMe);
    }
    await _storage.write('user_code', session.userCode);
    await _storage.write('full_name', session.fullname);
    await _storage.write('role', session.role);
    await _storage.write('active_branch_code', session.activeKodeCabang);
    await _storage.write('active_branch_name', session.activeBranchName);
    await _storage.write('user_session_json', session.toEncodedJson());
  }
}
