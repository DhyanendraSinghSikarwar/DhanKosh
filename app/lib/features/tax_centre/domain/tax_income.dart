import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Income for a period worked out from tracked credits, in paise (FR-19-02).
class TaxIncomeEstimate {
  const TaxIncomeEstimate({
    this.salary = 0,
    this.interest = 0,
    this.savingsInterest = 0,
    this.dividends = 0,
    this.rent = 0,
    this.other = 0,
    this.salarySoFar = 0,
    this.salaryMonths = 0,
    this.monthsOfData = 0,
    this.estimated = false,
  });

  final int salary;
  final int interest;

  /// Interest that is not from a deposit (80TTA / 80TTB).
  final int savingsInterest;
  final int dividends;
  final int rent;
  final int other;
  final int salarySoFar;
  final int salaryMonths;
  final int monthsOfData;

  /// Fewer than 12 months of data: figures are projected to a full year.
  final bool estimated;

  int get otherIncome => interest + dividends + other;
  int get total => salary + interest + dividends + rent + other;
}

/// Port of Kotlin `TaxIncome.estimate` (FR-19-02, FR-19-14).
abstract final class TaxIncome {
  static final _interest = RegExp(
    r'\binterest\b|\bint\.?\s?(pd|paid|cr|credit)\b|\bint\b',
    caseSensitive: false,
  );
  static final _deposit = RegExp(
    r'\bfd\b|fixed deposit|\brd\b|recurring|deposit',
    caseSensitive: false,
  );
  static final _dividend = RegExp(r'dividend|\bdiv\b', caseSensitive: false);
  static final _rent = RegExp(r'\brent\b', caseSensitive: false);
  static final _excluded = RegExp(
    r'reimburs|refund|reversal|cashback',
    caseSensitive: false,
  );

  /// `inrMinor ?? (INR ? amountMinor : 0)`.
  static int paise(LedgerTx t) =>
      t.inrMinor ?? (t.currency == 'INR' ? t.amountMinor : 0);

  /// Merchant, note and UPI id joined by spaces.
  static String text(LedgerTx t) =>
      [t.merchant, t.note, t.upiId].whereType<String>().join(' ');

  /// [txs] are all transactions up to [to]; those outside [from]..[to] are
  /// ignored but the earliest tells how far the data goes back. [today]
  /// bounds an unfinished period.
  static TaxIncomeEstimate estimate(
    List<LedgerTx> txs,
    DateTime from,
    DateTime to,
    DateTime today, {
    Duration offset = istOffset,
  }) {
    DateTime day(LedgerTx t) => dayOf(t.timestamp, offset: offset);
    final live =
        txs.where((t) => !t.needsReview && t.duplicateOfId == null).toList();
    if (live.isEmpty) return const TaxIncomeEstimate();
    var firstDay = day(live.first);
    for (final t in live) {
      final d = day(t);
      if (d.isBefore(firstDay)) firstDay = d;
    }
    final end = to.isBefore(today) ? to : today;
    final start = from.isAfter(firstDay) ? from : firstDay;
    if (start.isAfter(end)) return const TaxIncomeEstimate();

    var months = monthsBetween(start, end) + 1;
    // The month in progress counts only once it is nearly over.
    if (sameDay(end, today) &&
        end.isBefore(to) &&
        today.day < daysInMonth(today.year, today.month) - 2) {
      months -= 1;
    }
    months = months.clamp(0, 12);
    final estimated = months < 12;

    final inPeriod = live.where((t) {
      final d = day(t);
      return !d.isBefore(start) &&
          !d.isAfter(end) &&
          t.type == TransactionType.credit &&
          t.category != Category.transfer;
    }).toList();
    final salaryTx = inPeriod
        .where(
          (t) => t.category == Category.salary && !_excluded.hasMatch(text(t)),
        )
        .toList();
    final byMonth = <int, int>{};
    var salarySoFar = 0;
    for (final t in salaryTx) {
      final d = day(t);
      final k = d.year * 12 + d.month;
      byMonth[k] = (byMonth[k] ?? 0) + paise(t);
      salarySoFar += paise(t);
    }
    var latest = 0;
    if (byMonth.isNotEmpty) {
      final maxKey = byMonth.keys.reduce((a, b) => a > b ? a : b);
      latest = byMonth[maxKey]!;
    }
    final remainingMonths = 12 - months < 0 ? 0 : 12 - months;
    final salary = (estimated && byMonth.isNotEmpty)
        ? salarySoFar + latest * remainingMonths
        : salarySoFar;

    var interest = 0;
    var deposit = 0;
    var dividends = 0;
    var rent = 0;
    var other = 0;
    for (final t in inPeriod.where((t) => t.category == Category.income)) {
      final s = text(t);
      final a = paise(t);
      if (_excluded.hasMatch(s)) continue;
      if (_dividend.hasMatch(s)) {
        dividends += a;
      } else if (_interest.hasMatch(s)) {
        interest += a;
        if (_deposit.hasMatch(s)) deposit += a;
      } else if (_rent.hasMatch(s)) {
        rent += a;
      } else {
        other += a;
      }
    }
    int scale(int v) => (estimated && months > 0) ? v * 12 ~/ months : v;
    return TaxIncomeEstimate(
      salary: salary,
      interest: scale(interest),
      savingsInterest: scale(interest - deposit),
      dividends: scale(dividends),
      rent: scale(rent),
      other: scale(other),
      salarySoFar: salarySoFar,
      salaryMonths: byMonth.length,
      monthsOfData: months,
      estimated: estimated,
    );
  }
}
