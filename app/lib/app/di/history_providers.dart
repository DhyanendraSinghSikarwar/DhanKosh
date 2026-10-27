import 'dart:async';

import 'package:hisaab/app/di/email_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/usecases/change_history_days.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'history_providers.g.dart';

/// "History to read" (FR-26-30): saves the window and, when it grows, resets
/// the SMS cursor and every mailbox cursor and starts the catch-up scans.
@Riverpod(keepAlive: true)
ChangeHistoryDays changeHistoryDays(Ref ref) => ChangeHistoryDays(
      ref.watch(settingsRepositoryProvider),
      _Reread(ref),
    );

class _Reread implements HistoryReread {
  _Reread(this._ref);

  final Ref _ref;

  @override
  Future<void> resetPositions() async {
    await _ref.read(settingsRepositoryProvider).remove(SettingKeys.smsCursor);
    await _ref.read(emailSettingsRepositoryProvider).forgetPosition();
  }

  @override
  Future<void> start() async {
    // Fire and forget: the scans report through their own cards and the
    // Activity log. No SMS permission or no mailbox just ends them early.
    unawaited(
      _ref
          .read(scanSmsFactoryProvider)(null)(const SmsScanRequest.full())
          .then((_) {}, onError: (Object _) {}),
    );
    unawaited(_ref.read(emailSyncRunnerProvider).run().then((_) {}));
  }
}
