import 'package:flutter_riverpod/flutter_riverpod.dart';

class WizardLaunchIntent {
  const WizardLaunchIntent({
    required this.isWalkIn,
    this.preselectedRoomTypeCode,
    this.preselectedRoomCode,
    this.preselectedRoomNumber,
  });

  final bool isWalkIn;
  final String? preselectedRoomTypeCode;
  final String? preselectedRoomCode;
  final String? preselectedRoomNumber;
}

final wizardIntentProvider =
    NotifierProvider<WizardIntentNotifier, WizardLaunchIntent?>(
  WizardIntentNotifier.new,
);

class WizardIntentNotifier extends Notifier<WizardLaunchIntent?> {
  @override
  WizardLaunchIntent? build() => null;

  void setIntent(WizardLaunchIntent intent) {
    state = intent;
  }

  WizardLaunchIntent? consumeIntent() {
    final current = state;
    state = null;
    return current;
  }
}

