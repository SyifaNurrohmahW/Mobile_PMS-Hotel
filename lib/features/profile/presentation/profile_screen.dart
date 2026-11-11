import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/branch_switcher_sheet.dart';
import '../../auth/presentation/session_notifier.dart';
import '../../cashier_shift/presentation/active_shift_notifier.dart';
import '../../cashier_shift/presentation/cashier_shift_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(sessionProvider.notifier).refreshProfile();
      await ref.read(activeShiftProvider.notifier).refreshShift();
    } catch (_) {
      // Ignore silent refresh error
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final shiftAsync = ref.watch(activeShiftProvider);
    final activeShift = shiftAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun & Sesi Operasional'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refresh,
            tooltip: 'Segarkan profil & shift',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryLight,
                      child: Text(
                        (session?.fullname.isNotEmpty == true
                                ? session!.fullname[0]
                                : 'F')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session?.fullname ?? 'Staf Front Office',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${session?.username ?? '-'} · ${session?.userCode ?? '-'}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          StatusBadge(
                            label: session?.roleDisplayLabel ?? 'Front Office',
                            variant: StatusBadgeVariant.occupiedBlue,
                            small: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Scope Cabang Hotel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        StatusBadge(
                          label: session?.canSwitchBranch == true
                              ? 'Multi-Cabang'
                              : 'Cabang Terkunci',
                          variant: session?.canSwitchBranch == true
                              ? StatusBadgeVariant.arrivalsTeal
                              : StatusBadgeVariant.neutralSlate,
                          small: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoTile(
                      icon: Icons.apartment_rounded,
                      label: 'Cabang Aktif Saat Ini',
                      value: session?.branchBadgeLabel ?? '-',
                    ),
                    const SizedBox(height: 8),
                    _InfoTile(
                      icon: Icons.home_work_outlined,
                      label: 'Cabang Default',
                      value:
                          '${session?.defaultKodeCabang ?? '-'} - ${session?.defaultBranchName ?? '-'}',
                    ),
                    if (session?.canSwitchBranch == true) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => BranchSwitcherSheet.show(context),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Pindah Cabang Operasional'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sesi Shift Kasir',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        StatusBadge(
                          label: activeShift != null
                              ? 'AKTIF (${activeShift.namaShift.toUpperCase()})'
                              : 'BELUM DIBUKA',
                          variant: activeShift != null
                              ? StatusBadgeVariant.readyGreen
                              : StatusBadgeVariant.warningOrange,
                          small: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeShift == null)
                      const Text(
                        'Anda belum membuka shift kasir pada sesi ini. Buka shift kasir terlebih dahulu sebelum memproses transaksi pembayaran atau deposit.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    else ...[
                      _InfoTile(
                        icon: Icons.tag,
                        label: 'Kode Shift & Loket',
                        value:
                            '${activeShift.kodeCashierShift} · ${activeShift.namaCounter}',
                      ),
                      const SizedBox(height: 8),
                      _InfoTile(
                        icon: Icons.payments_outlined,
                        label: 'Estimasi Kas Sistem di Laci',
                        value: AppFormatters.formatRupiah(
                          activeShift.systemCash,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _InfoTile(
                        icon: Icons.access_time_outlined,
                        label: 'Waktu Buka Shift',
                        value: AppFormatters.formatDateTimeId(
                          activeShift.openedAt,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => CashierShiftSheet.show(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: activeShift != null
                              ? AppTheme.primary
                              : AppTheme.walkInGreen,
                        ),
                        icon: Icon(
                          activeShift != null
                              ? Icons.receipt_long_outlined
                              : Icons.lock_open_rounded,
                        ),
                        label: Text(
                          activeShift != null
                              ? 'Lihat Detail / Tutup Shift Kasir'
                              : 'Buka Shift Kasir Sekarang',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Keluar dari Sesi?'),
                      content: const Text(
                        'Anda akan keluar dari akun Front Office pada perangkat ini.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.dangerRed,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(sessionProvider.notifier).logout();
                    if (context.mounted) {
                      context.go(AppRoutes.login);
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dangerRed,
                  side: const BorderSide(color: AppTheme.dangerRed),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout Akun'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
