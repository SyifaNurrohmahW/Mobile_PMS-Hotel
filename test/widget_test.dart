import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pms_mobile/core/utils/formatters.dart';
import 'package:pms_mobile/core/widgets/status_badge.dart';
import 'package:pms_mobile/features/auth/domain/user_session.dart';

void main() {
  test('UserSession parses branch scope and role permissions accurately', () {
    final session = UserSession.fromJson({
      'user_code': 'USR001',
      'username': 'fo_sakai',
      'fullname': 'Resepsionis Sakai',
      'role': 'receptionist',
      'active_kode_cabang': 'CAB0001',
      'active_branch_name': 'Sakai Hotel Pusat',
      'can_switch_branch': false,
      'allowed_branches': [
        {'kode_cabang': 'CAB0001', 'nama': 'Sakai Hotel Pusat'},
      ],
    });

    expect(session.userCode, 'USR001');
    expect(session.activeBranchCode, 'CAB0001');
    expect(session.branchBadgeLabel, 'CAB0001 - Sakai Hotel Pusat');
    expect(session.canSwitchBranch, isFalse);
    expect(session.allowedBranches.length, 1);
  });

  test('AppFormatters formats Rupiah and calculates nights properly', () {
    expect(AppFormatters.formatRupiah(450000), contains('450.000'));
    final nights = AppFormatters.calculateNights(
      DateTime(2026, 10, 30),
      DateTime(2026, 11, 2),
    );
    expect(nights, 3);
  });

  testWidgets('StatusBadge renders semantic status label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusBadge.fromStatus('ready'),
        ),
      ),
    );

    expect(find.text('Siap Huni'), findsOneWidget);
  });
}
