import 'dart:async';

import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// [AlertSettingsRepository] over the settings table (FR-21-18).
class AlertSettingsStore implements AlertSettingsRepository {
  /// Creates the store.
  const AlertSettingsStore(this._s);

  final SettingsRepository _s;

  @override
  Future<AlertSettings> read() async => AlertSettings(
        transactionNotifications:
            await _s.read(SettingKeys.transactionNotifications),
        budgetAlertPercent: await _s.read(SettingKeys.budgetAlertPercent),
        cardDueReminders: await _s.read(SettingKeys.cardDueReminders),
        weeklySummary: await _s.read(weeklySummaryKey),
        updateAvailable: await _s.read(updateAlertKey),
      );

  @override
  Stream<AlertSettings> watch() {
    late StreamController<AlertSettings> c;
    final subs = <StreamSubscription<Object?>>[];
    Future<void> emit() async {
      if (!c.isClosed) c.add(await read());
    }

    c = StreamController<AlertSettings>(
      onListen: () {
        unawaited(emit());
        // Any of the three keys changing re-reads all of them.
        for (final s in <Stream<Object?>>[
          _s.watch(SettingKeys.transactionNotifications),
          _s.watch(SettingKeys.budgetAlertPercent),
          _s.watch(SettingKeys.cardDueReminders),
          _s.watch(weeklySummaryKey),
          _s.watch(updateAlertKey),
        ]) {
          subs.add(s.skip(1).listen((_) => unawaited(emit())));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return c.stream;
  }

  @override
  Future<void> setTransactionNotifications({required bool value}) =>
      _s.write(SettingKeys.transactionNotifications, value);

  @override
  Future<void> setBudgetAlertPercent(int percent) =>
      _s.write(SettingKeys.budgetAlertPercent, percent);

  @override
  Future<void> setCardDueReminders({required bool value}) =>
      _s.write(SettingKeys.cardDueReminders, value);

  @override
  Future<void> setWeeklySummary({required bool value}) =>
      _s.write(weeklySummaryKey, value);

  @override
  Future<void> setUpdateAvailable({required bool value}) =>
      _s.write(updateAlertKey, value);
}
