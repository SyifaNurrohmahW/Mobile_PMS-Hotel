import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

enum StatusBadgeVariant {
  readyGreen,
  occupiedBlue,
  arrivalsTeal,
  inHouseIndigo,
  warningOrange,
  dangerRed,
  neutralSlate,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.variant,
    this.icon,
    this.small = false,
    super.key,
  });

  final String label;
  final StatusBadgeVariant variant;
  final IconData? icon;
  final bool small;

  factory StatusBadge.fromRoomStatus(
    String status, {
    String? customLabel,
    bool small = false,
  }) {
    final normalized = status.toLowerCase();
    return switch (normalized) {
      'ready' || 'clean' || 'vacant' => StatusBadge(
          label: customLabel ?? 'Siap Huni',
          variant: StatusBadgeVariant.readyGreen,
          icon: Icons.check_circle_outline,
          small: small,
        ),
      'occupied' || 'inhouse' || 'checked_in' => StatusBadge(
          label: customLabel ?? 'Terisi',
          variant: StatusBadgeVariant.occupiedBlue,
          icon: Icons.hotel_outlined,
          small: small,
        ),
      'dirty' => StatusBadge(
          label: customLabel ?? 'Kotor / Cleaning',
          variant: StatusBadgeVariant.dangerRed,
          icon: Icons.cleaning_services_outlined,
          small: small,
        ),
      'in_progress' || 'assigned' => StatusBadge(
          label: customLabel ?? 'Dibersihkan',
          variant: StatusBadgeVariant.warningOrange,
          icon: Icons.autorenew,
          small: small,
        ),
      'inspection' => StatusBadge(
          label: customLabel ?? 'Perlu Inspeksi',
          variant: StatusBadgeVariant.warningOrange,
          icon: Icons.fact_check_outlined,
          small: small,
        ),
      'maintenance' || 'out_of_service' || 'blocked' => StatusBadge(
          label: customLabel ?? 'Perawatan',
          variant: StatusBadgeVariant.neutralSlate,
          icon: Icons.build_outlined,
          small: small,
        ),
      _ => StatusBadge(
          label: customLabel ?? status,
          variant: StatusBadgeVariant.neutralSlate,
          small: small,
        ),
    };
  }

  factory StatusBadge.fromBillingStatus(
    bool isSettled, {
    String? customLabel,
    bool small = false,
  }) {
    if (isSettled) {
      return StatusBadge(
        label: customLabel ?? 'LUNAS',
        variant: StatusBadgeVariant.readyGreen,
        icon: Icons.verified_outlined,
        small: small,
      );
    }
    return StatusBadge(
      label: customLabel ?? 'ADA TAGIHAN',
      variant: StatusBadgeVariant.dangerRed,
      icon: Icons.warning_amber_rounded,
      small: small,
    );
  }

  factory StatusBadge.fromStatus(
    String status, {
    String? customLabel,
    bool small = true,
  }) {
    final normalized = status.trim().toLowerCase();
    return switch (normalized) {
      'settled' || 'paid' || 'lunas' => StatusBadge.fromBillingStatus(
          true,
          customLabel: customLabel ?? 'LUNAS',
          small: small,
        ),
      'outstanding' || 'unpaid' || 'belum_lunas' =>
        StatusBadge.fromBillingStatus(
          false,
          customLabel: customLabel ?? 'ADA TAGIHAN',
          small: small,
        ),
      'reserved' || 'confirmed' || 'booked' => StatusBadge(
          label: customLabel ?? normalized.toUpperCase(),
          variant: StatusBadgeVariant.arrivalsTeal,
          icon: Icons.event_available_outlined,
          small: small,
        ),
      'not_requested' => StatusBadge(
          label: customLabel ?? 'Belum Dicek HK',
          variant: StatusBadgeVariant.neutralSlate,
          icon: Icons.fact_check_outlined,
          small: small,
        ),
      'clear' || 'completed' => StatusBadge(
          label: customLabel ?? 'Inspeksi Aman',
          variant: StatusBadgeVariant.readyGreen,
          icon: Icons.verified_outlined,
          small: small,
        ),
      'with_charges' => StatusBadge(
          label: customLabel ?? 'Ada Charge HK',
          variant: StatusBadgeVariant.dangerRed,
          icon: Icons.report_problem_outlined,
          small: small,
        ),
      'pending' => StatusBadge(
          label: customLabel ?? 'Tugas Diminta',
          variant: StatusBadgeVariant.warningOrange,
          icon: Icons.schedule_rounded,
          small: small,
        ),
      _ => StatusBadge.fromRoomStatus(
          status,
          customLabel: customLabel,
          small: small,
        ),
    };
  }

  (Color fg, Color bg) get _colors => switch (variant) {
        StatusBadgeVariant.readyGreen => (
            AppTheme.walkInGreen,
            AppTheme.walkInGreenBg
          ),
        StatusBadgeVariant.occupiedBlue => (
            AppTheme.bookingBlue,
            AppTheme.bookingBlueBg
          ),
        StatusBadgeVariant.arrivalsTeal => (
            AppTheme.arrivalsTeal,
            AppTheme.arrivalsTealBg
          ),
        StatusBadgeVariant.inHouseIndigo => (
            AppTheme.inHouseIndigo,
            AppTheme.inHouseIndigoBg
          ),
        StatusBadgeVariant.warningOrange => (
            AppTheme.checkoutOrange,
            AppTheme.checkoutOrangeBg
          ),
        StatusBadgeVariant.dangerRed => (
            AppTheme.dangerRed,
            AppTheme.dangerRedBg
          ),
        StatusBadgeVariant.neutralSlate => (
            AppTheme.neutralSlate,
            AppTheme.neutralSlateBg
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7.5 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 11.5 : 14, color: fg),
            const SizedBox(width: 3.5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: small ? 10 : 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
