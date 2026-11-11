import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_notifier.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

class DashboardState {
  const DashboardState({
    required this.summary,
    this.monitoring,
  });

  final DashboardSummary summary;
  final RoomMonitoringMatrix? monitoring;
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    final session = ref.watch(sessionProvider);
    final branchCode = session?.activeKodeCabang ?? '';
    return _fetchAll(branchCode);
  }

  Future<DashboardState> _fetchAll(String branchCode) async {
    final repo = ref.read(dashboardRepositoryProvider);
    final results = await Future.wait([
      repo.fetchSummary(branchCode: branchCode),
      repo.fetchMonitoring(branchCode: branchCode, days: 7).catchError(
            (_) => const RoomMonitoringMatrix(dates: [], rooms: []),
          ),
    ]);
    return DashboardState(
      summary: results[0] as DashboardSummary,
      monitoring: results[1] as RoomMonitoringMatrix,
    );
  }

  Future<void> refreshDashboard() async {
    final session = ref.read(sessionProvider);
    final branchCode = session?.activeKodeCabang ?? '';
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchAll(branchCode));
  }

  Future<void> refresh() => refreshDashboard();
}

