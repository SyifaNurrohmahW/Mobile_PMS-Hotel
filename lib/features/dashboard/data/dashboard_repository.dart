import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ApiClient(ref.watch(apiClientProvider)));
});

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSummary> fetchSummary({required String branchCode}) async {
    final response = await _apiClient.post(
      '/reservasi/dashboard/summary',
      {'kode_cabang': branchCode},
    );
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    return DashboardSummary.fromJson(data);
  }

  Future<RoomMonitoringMatrix> fetchMonitoring({
    required String branchCode,
    int days = 7,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/dashboard/monitoring',
      {
        'kode_cabang': branchCode,
        'days': days,
      },
    );
    final data = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    return RoomMonitoringMatrix.fromJson(data);
  }
}

