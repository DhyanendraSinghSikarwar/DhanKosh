import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart';

/// Books the regular payments the user asked to add themselves (FR-12-22,
/// ADR-0013). Each due date is booked once, under the id
/// `recurring:<item id>:<date>`.
class RecurringAutoPost {
  /// Creates the use case.
  const RecurringAutoPost(this._items, this._txs);

  final RecurringRepository _items;
  final TransactionRepository _txs;

  /// A date older than this is not booked.
  static const maxAgeDays = 35;

  static String idOf(int itemId, DateTime due) =>
      'recurring:$itemId:${due.year}-${due.month.toString().padLeft(2, '0')}-'
      '${due.day.toString().padLeft(2, '0')}';

  /// The latest due date of [m] on or before [today], or null when none falls
  /// in the last [maxAgeDays] days or after the item was created.
  static DateTime? dueOn(RecurringItem m, DateTime today) {
    DateTime inMonth(int y, int mo) {
      final yy = y + (mo - 1) ~/ 12;
      final mm = (mo - 1) % 12 + 1;
      final len = Ist.lengthOfMonth(yy, mm);
      return DateTime.utc(yy, mm, m.dayOfMonth < len ? m.dayOfMonth : len);
    }

    final DateTime latest;
    if (m.frequency == RecurringFrequency.yearly) {
      final month = (m.month ?? 1).clamp(1, 12);
      final thisYear = inMonth(today.year, month);
      latest =
          thisYear.isAfter(today) ? inMonth(today.year - 1, month) : thisYear;
    } else {
      final here = inMonth(today.year, today.month);
      latest =
          here.isAfter(today) ? inMonth(today.year, today.month - 1) : here;
    }
    final created = Ist.dateOf(m.createdAt);
    if (latest.isBefore(created)) return null;
    if (today.difference(latest).inDays > maxAgeDays) return null;
    return latest;
  }

  /// Books what is due; returns how many rows were added.
  Future<int> run(DateTime today) async {
    var added = 0;
    for (final m in await _items.all()) {
      if (!m.autoPost) continue;
      final due = dueOn(m, today);
      if (due == null) continue;
      // 09:00 IST on the due day.
      final at = due.millisecondsSinceEpoch - 19800000 + 9 * 3600000;
      final r = await _txs.addManual(
        amountMinor: m.amountMinor,
        type: m.income ? TransactionType.credit : TransactionType.debit,
        timestamp: at,
        accountId: m.accountId,
        merchant: m.name,
        category: m.category,
        sourceMessageId: idOf(m.id, due),
      );
      if (r.outcome == IngestOutcome.inserted) added++;
    }
    return added;
  }
}
