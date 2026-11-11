import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/status_badge.dart';
import '../../reservation/walkin_booking/presentation/wizard_intent_provider.dart';
import '../domain/dashboard_models.dart';

class RoomDetailSheet extends ConsumerWidget {
  const RoomDetailSheet({required this.room, super.key});

  final RoomRackItem room;

  static Future<void> show(BuildContext context, RoomRackItem room) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RoomDetailSheet(room: room),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stay = room.activeStay;
    final isReady = room.displayStatus == 'ready';
    final isOccupied = room.displayStatus == 'occupied' || stay != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _headerBgColor(room.displayStatus),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    room.nomorKamar,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _headerFgColor(room.displayStatus),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kamar ${room.nomorKamar} · ${room.namaTipe}',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${room.lantai} · Kode ${room.kodeKamar}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.fromRoomStatus(
                  room.displayStatus,
                  customLabel: room.statusLabel,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    label: 'Status Hunian (Occupancy)',
                    value: room.occupancyStatus.toUpperCase(),
                  ),
                  const SizedBox(height: 6),
                  _DetailRow(
                    label: 'Status Kebersihan (Housekeeping)',
                    value: room.housekeepingStatus.toUpperCase(),
                  ),
                  if (stay != null) ...[
                    const Divider(height: 20),
                    const Text(
                      'Informasi Tamu Menginap (Active Stay)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.bookingBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Nama Tamu', value: stay.guestName),
                    const SizedBox(height: 4),
                    _DetailRow(label: 'No. Telepon', value: stay.phone),
                    const SizedBox(height: 4),
                    _DetailRow(
                      label: 'Kode Reservasi',
                      value: stay.kodeReservasi,
                    ),
                    if (stay.kodeFolio != null) ...[
                      const SizedBox(height: 4),
                      _DetailRow(label: 'Kode Folio', value: stay.kodeFolio!),
                    ],
                    const SizedBox(height: 4),
                    _DetailRow(
                      label: 'Periode Menginap',
                      value: '${stay.checkInDate} s/d ${stay.checkOutDate}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (isReady)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(wizardIntentProvider.notifier).setIntent(
                              WizardLaunchIntent(
                                isWalkIn: false,
                                preselectedRoomTypeCode: room.kodeTipeKamar,
                                preselectedRoomCode: room.kodeKamar,
                                preselectedRoomNumber: room.nomorKamar,
                              ),
                            );
                        Navigator.pop(context);
                        context.go(AppRoutes.reservation);
                      },
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('Booking Kamar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(wizardIntentProvider.notifier).setIntent(
                              WizardLaunchIntent(
                                isWalkIn: true,
                                preselectedRoomTypeCode: room.kodeTipeKamar,
                                preselectedRoomCode: room.kodeKamar,
                                preselectedRoomNumber: room.nomorKamar,
                              ),
                            );
                        Navigator.pop(context);
                        context.go(AppRoutes.reservation);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.walkInGreen,
                      ),
                      icon: const Icon(Icons.directions_walk_rounded, size: 18),
                      label: const Text('Proses Walk-In'),
                    ),
                  ),
                ],
              )
            else if (isOccupied)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go(AppRoutes.inhouse);
                      },
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Lihat Folio / In-House'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go(AppRoutes.checkout);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.checkoutOrange,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Proses Checkout'),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
          ],
        ),
      ),
    );
  }

  Color _headerFgColor(String status) => switch (status) {
        'ready' => AppTheme.walkInGreen,
        'occupied' => AppTheme.bookingBlue,
        'dirty' => AppTheme.dangerRed,
        _ => AppTheme.neutralSlate,
      };

  Color _headerBgColor(String status) => switch (status) {
        'ready' => AppTheme.walkInGreenBg,
        'occupied' => AppTheme.bookingBlueBg,
        'dirty' => AppTheme.dangerRedBg,
        _ => AppTheme.neutralSlateBg,
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

