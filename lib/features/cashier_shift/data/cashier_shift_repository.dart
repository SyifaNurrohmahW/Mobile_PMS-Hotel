import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/cashier_shift_models.dart';

final cashierShiftRepositoryProvider = Provider<CashierShiftRepository>((ref) {
  return CashierShiftRepository(ApiClient(ref.watch(apiClientProvider)));
});

class CashierShiftRepository {
  CashierShiftRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CashierShift?> getCurrentShift() async {
    final response = await _apiClient.post('/kasir/shift-current');
    final data = response['data'];
    if (data is Map) {
      return CashierShift.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<List<CashierCounter>> getCounters({required String branchCode}) async {
    final response = await _apiClient.post(
      '/master/cashier-counter/cashier-counter-data',
      {
        'kode_cabang': branchCode,
        'is_active': 1,
      },
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => CashierCounter.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<MasterShiftOption>> getShiftDropdown({
    required String branchCode,
  }) async {
    final response = await _apiClient.post(
      '/master/shift/shift-dropdown',
      {'kode_cabang': branchCode},
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => MasterShiftOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> openShift({
    required String branchCode,
    required String counterCode,
    required double openingCash,
    String? sesi,
  }) async {
    final response = await _apiClient.post('/kasir/shift-open', {
      'kode_cabang': branchCode,
      'kode_cashier_counter': counterCode,
      'opening_cash': openingCash,
      if (sesi != null && sesi.isNotEmpty) 'sesi': sesi,
    });
    final data = response['data'];
    if (data is Map) {
      return data['kode_cashier_shift']?.toString() ?? '';
    }
    return '';
  }

  Future<CashierShiftDetail> getShiftDetail(String shiftCode) async {
    final response = await _apiClient.post('/kasir/shift-detail', {
      'kode_cashier_shift': shiftCode,
    });
    final data = response['data'];
    if (data is Map) {
      return CashierShiftDetail.fromJson(Map<String, dynamic>.from(data));
    }
    throw const FormatException('Data detail shift kasir tidak valid.');
  }

  Future<Map<String, dynamic>> closeShift({
    required String shiftCode,
    required double closingCash,
    String? catatanHandover,
  }) async {
    final response = await _apiClient.post('/kasir/shift-close', {
      'kode_cashier_shift': shiftCode,
      'closing_cash': closingCash,
      'catatan_handover': catatanHandover ?? '',
    });
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }
}

