import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';

/// [StatementLockedNotifier] over the alerts poster (FR-05-11, FR-21-12).
/// Never shows figures; a failed post is ignored.
class AlertStatementLockedNotifier implements StatementLockedNotifier {
  /// Creates the notifier.
  const AlertStatementLockedNotifier(this._poster);

  final AlertPoster _poster;

  @override
  Future<void> notify(int id, {String? bank}) async {
    try {
      if (!await _poster.areEnabled()) return;
      await _poster.post(
        AlertRules.statementLockedAlert(statementId: id, bank: bank),
      );
    } on Object {
      // Notifications are best effort.
    }
  }
}
