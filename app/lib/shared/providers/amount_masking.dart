import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// The hide-amounts setting (FR-17-19); masked until loaded.
final hideAmountsProvider = StreamProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(SettingKeys.hideAmounts),
);

/// Formats [minor] paise, masked as `₹••••` when [masked].
String formatAmount(int minor, {required bool masked, bool paise = true}) =>
    formatMoney(Money(minor), masked: masked, showPaise: paise);
