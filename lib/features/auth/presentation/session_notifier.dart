import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/user_session.dart';

final sessionProvider = NotifierProvider<SessionNotifier, UserSession?>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<UserSession?> {
  @override
  UserSession? build() {
    return null;
  }

  Future<UserSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final session = await ref.read(authRepositoryProvider).login(
          username: username,
          password: password,
          rememberMe: rememberMe,
        );
    state = session;
    return session;
  }

  Future<bool> restoreSession() async {
    final repo = ref.read(authRepositoryProvider);
    final cached = await repo.readCachedSession();
    if (cached != null) {
      state = cached;
    }
    try {
      final fresh = await repo.restoreSession();
      if (fresh != null) {
        state = fresh;
        return true;
      }
    } catch (_) {}

    // Fallback default session untuk mode Pelanggan (Customer Self-Service)
    final customerDefault = state ??
        const UserSession(
          userId: 1,
          userCode: 'USR000000',
          username: 'customer',
          fullname: 'Pelanggan Tamu Hotel',
          role: 'customer',
          activeBranchId: 1,
          activeKodeCabang: 'CAB0001',
          activeBranchName: 'Grand Marstech Hotel',
          defaultKodeCabang: 'CAB0001',
          defaultBranchName: 'Grand Marstech Hotel',
          canSwitchBranch: true,
          allowedBranches: [],
        );
    state = customerDefault;
    return true;
  }

  void setCustomerActiveBranch({
    required String kodeCabang,
    required String namaHotel,
    int branchId = 1,
  }) {
    final current = state ??
        UserSession(
          userId: 1,
          userCode: 'USR000000',
          username: 'customer',
          fullname: 'Pelanggan Tamu Hotel',
          role: 'customer',
          activeBranchId: branchId,
          activeKodeCabang: kodeCabang,
          activeBranchName: namaHotel,
          defaultKodeCabang: kodeCabang,
          defaultBranchName: namaHotel,
          canSwitchBranch: true,
          allowedBranches: const [],
        );
    state = current.copyWith(
      activeBranchId: branchId,
      activeKodeCabang: kodeCabang,
      activeBranchName: namaHotel,
    );
  }

  Future<UserSession> refreshProfile() async {
    final fresh = await ref.read(authRepositoryProvider).fetchMe();
    state = fresh;
    return fresh;
  }

  Future<UserSession> switchBranch(String targetKodeCabang) async {
    final current = state;
    if (current == null) {
      throw StateError('Sesi pengguna tidak aktif.');
    }
    final updated = await ref.read(authRepositoryProvider).switchBranch(
          targetKodeCabang: targetKodeCabang,
          currentSession: current,
        );
    state = updated;
    return updated;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = null;
  }
}

