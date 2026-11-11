import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../features/auth/presentation/branch_switcher_sheet.dart';
import '../../features/auth/presentation/session_notifier.dart';
import '../../features/cashier_shift/presentation/active_shift_notifier.dart';
import '../../features/cashier_shift/presentation/cashier_shift_sheet.dart';
import '../constants/app_routes.dart';

class FrontOfficeHeaderBar extends ConsumerWidget {
  const FrontOfficeHeaderBar({
    this.title,
    this.subtitle,
    this.trailingActions,
    this.compact = false,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<Widget>? trailingActions;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final shiftAsync = ref.watch(activeShiftProvider);
    final activeShift = shiftAsync.value;
    final canSwitch = session?.canSwitchBranch ?? false;
    final branchLabel = session?.branchBadgeLabel ?? 'Memuat Cabang...';

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        compact ? 8 : 12,
        14,
        compact ? 8 : 12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.domain_rounded,
                  color: AppTheme.primary,
                  size: compact ? 18 : 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? (session?.fullname ?? 'Front Office Desk'),
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle ??
                          '${session?.roleDisplayLabel ?? 'Staf'} · ${session?.userCode ?? ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ...?trailingActions,
              IconButton(
                tooltip: 'Profil & Sesi Kasir',
                visualDensity: VisualDensity.compact,
                onPressed: () => context.push(AppRoutes.profile),
                icon: CircleAvatar(
                  radius: compact ? 14 : 16,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    (session?.fullname.isNotEmpty == true
                            ? session!.fullname[0]
                            : 'U')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Row(
            children: [
              // Active Branch Badge (Read-Only for branch staff, Switchable for regional/HQ)
              Expanded(
                child: InkWell(
                  onTap: canSwitch
                      ? () => BranchSwitcherSheet.show(context)
                      : null,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          canSwitch
                              ? Icons.swap_horiz_rounded
                              : Icons.lock_outline_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            branchLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (canSwitch)
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: AppTheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Cashier Shift Status Badge / Trigger
              InkWell(
                onTap: () => CashierShiftSheet.show(context),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: activeShift != null
                        ? AppTheme.walkInGreenBg
                        : AppTheme.checkoutOrangeBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: (activeShift != null
                              ? AppTheme.walkInGreen
                              : AppTheme.checkoutOrange)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        activeShift != null
                            ? Icons.point_of_sale_rounded
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: activeShift != null
                            ? AppTheme.walkInGreen
                            : AppTheme.checkoutOrange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        activeShift != null
                            ? 'Shift: ${activeShift.namaShift.toUpperCase()}'
                            : 'Buka Shift',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: activeShift != null
                              ? AppTheme.walkInGreen
                              : AppTheme.checkoutOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
