import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Settings of Savings Goals (FR-36-05, FR-36-07).
abstract final class GoalSettings {
  /// Round-up step in rupees (10, 50 or 100).
  static const roundUpStep = SettingKey<int>('roundup_step', 10);

  /// Goal the round-ups are shown against; 0 for none.
  static const roundUpGoal = SettingKey<int>('roundup_goal', 0);

  /// Encoded salary plan `s:i:p`; empty for the standard 20:20:60.
  static const salaryPlan = SettingKey<String>('salary_plan', '');
}
