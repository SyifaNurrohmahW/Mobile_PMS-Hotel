import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_notifier.dart';
import '../data/cashier_shift_repository.dart';
import '../domain/cashier_shift_models.dart';

final activeShiftProvider =
    AsyncNotifierProvider<ActiveShiftNotifier, CashierShift?>(
  ActiveShiftNotifier.new,
);

class ActiveShiftNotifier extends AsyncNotifier<CashierShift?> {
  @override
  Future<CashierShift?> build() async {
    final session = ref.watch(sessionProvider);
    if (session == null || session.activeKodeCabang.isEmpty) {
      return null;
    }
    return ref.read(cashierShiftRepositoryProvider).getCurrentShift();
  }

  Future<CashierShift?> refreshShift() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cashierShiftRepositoryProvider).getCurrentShift(),
    );
    return state.value;
  }

  Future<CashierShift?> openShift({
    required String branchCode,
    required String counterCode,
    required double openingCash,
    String? sesi,
  }) async {
    final repo = ref.read(cashierShiftRepositoryProvider);
    await repo.openShift(
      branchCode: branchCode,
      counterCode: counterCode,
      openingCash: openingCash,
      sesi: sesi,
    );
    return refreshShift();
  }

  Future<Map<String, dynamic>> closeShift({
    required String shiftCode,
    required double closingCash,
    String? catatanHandover,
  }) async {
    final repo = ref.read(cashierShiftRepositoryProvider);
    final result = await repo.closeShift(
      shiftCode: shiftCode,
      closingCash: closingCash,
      catatanHandover: catatanHandover,
    );
    await refreshShift();
    return result;
  }
}

