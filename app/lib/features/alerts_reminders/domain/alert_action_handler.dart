import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/domain/card_reminder_state_store.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart';

/// Runs a tapped notification button (FR-21-03, FR-21-10): card "Mark paid",
/// card "Remind tomorrow" and a new-transaction category button. `more` is
/// handled by the Change category screen, which then sends `category`.
class AlertActionHandler {
  /// Creates the handler. [nowMs] is epoch ms.
  AlertActionHandler({
    required CardReminderStateStore cardState,
    required CardPaidStore paid,
    required TransactionRepository txs,
    required AlertPoster poster,
    int Function()? nowMs,
  })  : _state = cardState,
        _paid = paid,
        _txs = txs,
        _poster = poster,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final CardReminderStateStore _state;
  final CardPaidStore _paid;
  final TransactionRepository _txs;
  final AlertPoster _poster;
  final int Function() _nowMs;

  /// Applies the action in [query] (the `/alert-action` query parameters).
  /// True when something changed; unknown or malformed input is ignored.
  Future<bool> handle(Map<String, String> query) async {
    final today = epochDayOf(
      DateTime.fromMillisecondsSinceEpoch(_nowMs() + 19800000, isUtc: true),
    );
    switch (query['a']) {
      case 'paid':
      case 'snooze':
        final card = int.tryParse(query['cardId'] ?? '');
        final due = int.tryParse(query['dueEpochDay'] ?? '');
        if (card == null || due == null) return false;
        if (query['a'] == 'paid') {
          await _state.markPaid(card, due, todayEpochDay: today);
          await _paid.markPaid(card, due);
        } else {
          await _state.snooze(card, due, today + 1, todayEpochDay: today);
        }
        await _poster.cancel(AlertRules.cardBillIdBase + card * 3);
        return true;
      case 'category':
        final id = int.tryParse(query['txId'] ?? '');
        final cat = Category.values
            .where((c) => c.name == query['category'])
            .firstOrNull;
        if (id == null || cat == null) return false;
        await _txs.setCategory([id], cat);
        final saved = AlertRules.categorySavedAlert(txId: id, category: cat);
        await _poster.post(saved);
        return true;
      case 'more':
        // Opens the Change category sheet; nothing to run here.
        return false;
    }
    return false;
  }
}
