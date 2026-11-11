import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/front_office_header_bar.dart';
import '../../cashier_shift/presentation/active_shift_notifier.dart';
import '../../reservation/walkin_booking/presentation/wizard_intent_provider.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_notifier.dart';
import 'room_rack_grid.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(dashboardProvider.notifier).refreshDashboard(),
      ref.read(activeShiftProvider.notifier).refreshShift(),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const FrontOfficeHeaderBar(),
            Expanded(
              child: dashboardAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppErrorState(
                  message: error.toString(),
                  onRetry: () => _onRefresh(ref),
                ),
                data: (state) {
                  final summary = state.summary;
                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(ref),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _KpiGridSection(
                          kpiToday: summary.kpiToday,
                          kpiPeriod: summary.kpiPeriod,
                        ),
                        const SizedBox(height: 14),
                        _QuickActionRow(
                          onWalkInTap: () {
                            ref.read(wizardIntentProvider.notifier).setIntent(
                                  const WizardLaunchIntent(isWalkIn: true),
                                );
                            context.go(AppRoutes.reservation);
                          },
                          onBookingTap: () {
                            ref.read(wizardIntentProvider.notifier).setIntent(
                                  const WizardLaunchIntent(isWalkIn: false),
                                );
                            context.go(AppRoutes.reservation);
                          },
                          onArrivalsTap: () => context.go(AppRoutes.arrivals),
                        ),
                        const SizedBox(height: 18),
                        RoomRackGrid(
                          rooms: summary.roomRack,
                          monitoring: state.monitoring,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGridSection extends StatelessWidget {
  const _KpiGridSection({
    required this.kpiToday,
    required this.kpiPeriod,
  });

  final KpiToday kpiToday;
  final KpiPeriod kpiPeriod;

  @override
  Widget build(BuildContext context) {
    final occRate = kpiPeriod.occupancyRatePeriod.toStringAsFixed(1);
    final tiles = [
      _KpiTile(
        label: 'Total Kamar',
        value: '${kpiPeriod.totalRooms}',
        subtitle: 'Unit Fisik',
        color: AppTheme.primary,
        bgColor: AppTheme.primaryLight,
        icon: Icons.meeting_room_outlined,
      ),
      _KpiTile(
        label: 'Terisi (In-House)',
        value: '${kpiToday.occupiedRooms}',
        subtitle: 'Okupansi $occRate%',
        color: AppTheme.bookingBlue,
        bgColor: AppTheme.bookingBlueBg,
        icon: Icons.hotel_outlined,
      ),
      _KpiTile(
        label: 'Siap Huni',
        value: '${kpiToday.readyRooms}',
        subtitle: 'Clean & Vacant',
        color: AppTheme.walkInGreen,
        bgColor: AppTheme.walkInGreenBg,
        icon: Icons.check_circle_outline,
      ),
      _KpiTile(
        label: 'Pembersihan',
        value: '${kpiToday.dirtyRooms}',
        subtitle: 'Dirty / Cleaning',
        color: AppTheme.dangerRed,
        bgColor: AppTheme.dangerRedBg,
        icon: Icons.cleaning_services_outlined,
      ),
      _KpiTile(
        label: 'Arrivals',
        value: '${kpiToday.arrivalsToday}',
        subtitle: 'Jadwal Hari Ini',
        color: AppTheme.arrivalsTeal,
        bgColor: AppTheme.arrivalsTealBg,
        icon: Icons.login_rounded,
      ),
      _KpiTile(
        label: 'Departures',
        value: '${kpiToday.departuresToday}',
        subtitle: 'Checkout Hari Ini',
        color: AppTheme.checkoutOrange,
        bgColor: AppTheme.checkoutOrangeBg,
        icon: Icons.logout_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 680
            ? 6
            : (constraints.maxWidth < 330 ? 2 : 3);
        return GridView.builder(
          itemCount: tiles.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 86,
          ),
          itemBuilder: (_, index) => tiles[index],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onWalkInTap,
    required this.onBookingTap,
    required this.onArrivalsTap,
  });

  final VoidCallback onWalkInTap;
  final VoidCallback onBookingTap;
  final VoidCallback onArrivalsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onWalkInTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.walkInGreen,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.directions_walk_rounded, size: 15),
            label: const Flexible(
              child: Text(
                '+ Walk-In',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FilledButton.icon(
            onPressed: onBookingTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.bookingBlue,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
            label: const Flexible(
              child: Text(
                '+ Booking',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FilledButton.icon(
            onPressed: onArrivalsTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.arrivalsTeal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.login_rounded, size: 15),
            label: const Flexible(
              child: Text(
                'Kedatangan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
