import 'package:hisaab/features/activity_log/domain/activity_logger.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';

/// [StatementLockedNotifier] over the alerts poster (FR-05-11, FR-21-12).
/// Never shows figures; a failed post is ignored.
class AlertStatementLockedNotifier implements StatementLockedNotifier {
  /// Creates the notifier.
  const AlertStatementLockedNotifier(this._poster, [this._activity]);

  final AlertPoster _poster;
  final ActivityLogger? _activity;

  @override
  Future<void> notify(int id, {String? bank}) async {
    try {
      if (!await _poster.areEnabled()) return;
      final ok = await _poster.post(
        AlertRules.statementLockedAlert(statementId: id, bank: bank),
      );
      if (ok) {
        await _activity?.record(
          ActivityEntry.alert(at: DateTime.now(), kind: 'statementLocked'),
        );
      }
    } on Object {
      // Notifications are best effort.
    }
  }
}
