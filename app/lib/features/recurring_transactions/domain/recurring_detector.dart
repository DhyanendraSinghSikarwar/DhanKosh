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

  /// FR-12-04: user items replace detected ones with the same lower-cased
  /// name; sorted by next due.
  static List<Recurring> withManual(
    List<Recurring> detected,
    List<RecurringItem> manual,
    DateTime today,
  ) {
    final mine = [
      for (final m in manual)
        Recurring(
          name: m.name,
          amountMinor: m.amountMinor,
          dayOfMonth: m.dayOfMonth,
          category: m.category,
          accountId: m.accountId,
          nextDue: nextDueOf(m, today),
          occurrences: 0,
          manualId: m.id,
          income: m.income,
          yearly: m.frequency == RecurringFrequency.yearly,
        ),
    ];
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
