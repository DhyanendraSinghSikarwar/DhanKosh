import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:parser_core/parser_core.dart';

/// Bills list assembly (FR-12-06, FR-12-09). Pure.
abstract final class BillsView {
  /// Adds every open loan EMI to [items]: tagged onto a same-named item, or
  /// added as a synthetic bill. Sorted by next due.
  static List<Recurring> withLoans(List<Recurring> items, List<Loan> loans) {
    final out = [...items];
    for (final l in loans) {
      final due = l.nextDue;
      final emi = l.emiMinor;
      final day = l.emiDay;
      if (l.closed || due == null || emi == null || day == null) continue;
      final i =
          out.indexWhere((r) => r.name.toLowerCase() == l.name.toLowerCase());
      if (i >= 0) {
        final r = out[i];
        out[i] = Recurring(
          name: r.name,
          amountMinor: r.amountMinor,
          dayOfMonth: r.dayOfMonth,
          category: r.category,
          nextDue: r.nextDue,
          occurrences: r.occurrences,
          accountId: r.accountId,
          lastPaid: r.lastPaid,
          manualId: r.manualId,
          income: r.income,
          yearly: r.yearly,
          loanKey: l.key,
        );
      } else {
        out.add(
          Recurring(
            name: l.name,
            amountMinor: emi,
            dayOfMonth: day,
            category: Category.emiLoan,
            nextDue: due,
            occurrences: l.paidCount,
            lastPaid: l.lastPaid,
            loanKey: l.key,
          ),
        );
      }
    }
    return out..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  }

  /// Paid for the current cycle: last paid this month and the next due is
  /// in a later month.
  static bool paid(Recurring r, DateTime today) {
    final p = r.lastPaid;
    if (p == null) return false;
    final sameMonth = p.year == today.year && p.month == today.month;
    final later =
        r.nextDue.year * 12 + r.nextDue.month > today.year * 12 + today.month;
    return sameMonth && later;
  }

  /// Items occurring on [date] (FR-12-10); [on] decides placement.
  static List<Recurring> onDay(
    List<Recurring> items,
    DateTime date,
    bool Function(Recurring, DateTime) on,
  ) =>
      [
        for (final r in items)
          if (on(r, date)) r,
      ];

  /// Sum of monthly-equivalent expenses due within 30 days of [today].
  static int dueIn30(List<Recurring> items, DateTime today) {
    final end = today.add(const Duration(days: 30));
    return items
        .where(
          (r) =>
              !r.income &&
              !r.nextDue.isBefore(today) &&
              !r.nextDue.isAfter(end),
        )
        .fold(0, (s, r) => s + r.amountMinor);
  }

  /// Sum of monthly expenses (yearly items spread over 12, rounded down).
  static int everyMonth(List<Recurring> items) => items
      .where((r) => !r.income)
      .fold(0, (s, r) => s + (r.yearly ? r.amountMinor ~/ 12 : r.amountMinor));
}
