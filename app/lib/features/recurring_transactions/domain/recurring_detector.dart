import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Monthly-repeat detection and next-due maths (memory 12 section 10, Kotlin
/// `Planning.recurring`). Pure; `today` is an IST date as UTC
/// midnight.
abstract final class RecurringDetector {
  /// Lookback window.
  static const windowDays = 130;

  /// A last payment older than this ends the series.
  static const recencyDays = 45;

  /// Max spread of the day of month.
  static const maxDaySpread = 6;

  static String? _key(LedgerTx t) {
    final k = (t.merchant ?? t.upiId)?.trim().toLowerCase();
    return k != null && k.length >= 2 ? k : null;
  }

  static DateTime _date(LedgerTx t) => Ist.dateOf(t.timestamp);

  static DateTime _nextMonthDay(DateTime last, int day) {
    final y = last.month == 12 ? last.year + 1 : last.year;
    final m = last.month == 12 ? 1 : last.month + 1;
    final len = Ist.lengthOfMonth(y, m);
    return DateTime.utc(y, m, day < len ? day : len);
  }

  /// FR-12-01, FR-12-02: detected recurring payments sorted by next due.
  static List<Recurring> detect(List<LedgerTx> txs, DateTime today) {
    final from = today.subtract(const Duration(days: windowDays));
    final groups = <String, List<LedgerTx>>{};
    for (final t in txs) {
      if (t.type != TransactionType.debit &&
          t.type != TransactionType.investment) {
        continue;
      }
      if (t.needsReview || t.currency != 'INR') continue;
      if (_date(t).isBefore(from)) continue;
      final k = _key(t);
      if (k != null) (groups[k] ??= []).add(t);
    }
    final out = <Recurring>[];
    for (final g in groups.values) {
      final amounts = g.map((t) => t.amountMinor).toList()..sort();
      final median = amounts[g.length ~/ 2];
      final similar = g
          .where((t) => (t.amountMinor - median).abs() <= median ~/ 5)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (similar.isEmpty) continue;
      final months = {
        for (final t in similar) _date(t).year * 12 + _date(t).month,
      };
      if (months.length < 2) continue;
      final days = similar.map((t) => _date(t).day).toList();
      final sortedDays = [...days]..sort();
      if (sortedDays.last - sortedDays.first > maxDaySpread) continue;
      final last = similar.last;
      final lastDate = _date(last);
      if (lastDate
          .isBefore(today.subtract(const Duration(days: recencyDays)))) {
        continue;
      }
      final day = sortedDays[days.length ~/ 2];
      out.add(
        Recurring(
          name: last.merchant ?? last.upiId ?? 'Payment',
          amountMinor: last.amountMinor,
          dayOfMonth: day,
          category: last.category,
          accountId: last.accountId,
          lastPaid: lastDate,
          nextDue: _nextMonthDay(lastDate, day),
          occurrences: similar.length,
        ),
      );
    }
    return out..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  }

  /// Next due date of a user item on or after [today] (FR-12-05), day
  /// clamped to the month length.
  static DateTime nextDueOf(RecurringItem m, DateTime today) {
    DateTime inMonth(int y, int mo) {
      final yy = y + (mo - 1) ~/ 12;
      final mm = (mo - 1) % 12 + 1;
      final len = Ist.lengthOfMonth(yy, mm);
      return DateTime.utc(yy, mm, m.dayOfMonth < len ? m.dayOfMonth : len);
    }

    if (m.frequency == RecurringFrequency.yearly) {
      final month = (m.month ?? today.month).clamp(1, 12);
      final thisYear = inMonth(today.year, month);
      return thisYear.isBefore(today)
          ? inMonth(today.year + 1, month)
          : thisYear;
    }
    final here = inMonth(today.year, today.month);
    return here.isBefore(today) ? inMonth(today.year, today.month + 1) : here;
  }

  /// How far before the due date a payment still counts for it (FR-12-23).
  static const paidWindowDays = 15;

  /// The date of a payment in [txs] that settles [m] for [due], or null.
  /// It must fall in the [paidWindowDays] before [due] up to [today], go the
  /// right way (out for a bill, in for income), and match by name (the
  /// payee holds the item's name, or the reverse) or by amount (within 2 per
  /// cent) with the same category and account.
  static DateTime? paymentFor(
    RecurringItem m,
    DateTime due,
    DateTime today,
    List<LedgerTx> txs,
  ) {
    final from = due.subtract(const Duration(days: paidWindowDays));
    final name = m.name.trim().toLowerCase();
    DateTime? best;
    for (final t in txs) {
      if (t.needsReview || t.excluded || t.duplicateOfId != null) continue;
      final out = t.type == TransactionType.debit ||
          t.type == TransactionType.investment;
      if (m.income ? t.type != TransactionType.credit : !out) continue;
      final d = _date(t);
      if (d.isBefore(from) || d.isAfter(today)) continue;
      final payee = (t.merchant ?? t.upiId ?? '').trim().toLowerCase();
      final byName = name.length >= 3 &&
          payee.length >= 3 &&
          (payee.contains(name) || name.contains(payee));
      final byAmount = t.category == m.category &&
          (m.accountId == null || t.accountId == m.accountId) &&
          (t.amountMinor - m.amountMinor).abs() * 50 <= m.amountMinor;
      if ((byName || byAmount) && (best == null || d.isAfter(best))) best = d;
    }
    return best;
  }

  /// The due date after [due]: next month, or next year for a yearly item.
  static DateTime advance(RecurringItem m, DateTime due) {
    if (m.frequency == RecurringFrequency.yearly) {
      final len = Ist.lengthOfMonth(due.year + 1, due.month);
      return DateTime.utc(
        due.year + 1,
        due.month,
        m.dayOfMonth < len ? m.dayOfMonth : len,
      );
    }
    return _nextMonthDay(due, m.dayOfMonth);
  }

  /// FR-12-04: user items replace detected ones with the same lower-cased
  /// name; sorted by next due.
  static List<Recurring> withManual(
    List<Recurring> detected,
    List<RecurringItem> manual,
    DateTime today, {
    List<LedgerTx> txs = const [],
  }) {
    final mine = <Recurring>[];
    for (final m in manual) {
      var due = nextDueOf(m, today);
      // Already paid for this due date: show the next one (FR-12-23).
      final paid = paymentFor(m, due, today, txs);
      if (paid != null) due = advance(m, due);
      mine.add(
        Recurring(
          name: m.name,
          amountMinor: m.amountMinor,
          dayOfMonth: m.dayOfMonth,
          category: m.category,
          accountId: m.accountId,
          nextDue: due,
          lastPaid: paid,
          occurrences: 0,
          manualId: m.id,
          income: m.income,
          yearly: m.frequency == RecurringFrequency.yearly,
          autoPost: m.autoPost,
        ),
      );
    }
    final names = {for (final r in mine) r.name.toLowerCase()};
    return [
      ...mine,
      ...detected.where((r) => !names.contains(r.name.toLowerCase())),
    ]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  }

  /// Calendar placement (FR-12-10): monthly items every month, yearly only
  /// in their due month; day clamped.
  static bool occursOn(Recurring r, DateTime date) {
    if (r.yearly && r.nextDue.month != date.month) return false;
    final len = Ist.lengthOfMonth(date.year, date.month);
    return date.day == (r.dayOfMonth < len ? r.dayOfMonth : len);
  }
}
