import 'dart:math' as math;

import 'package:hisaab/features/analytics/domain/civil_date.dart';

/// Loan terms as the user entered them (FR-15-05). [startDay] is the date of
/// the first EMI (a day, see `civil_date.dart`).
class LoanTerms {
  const LoanTerms({
    required this.principalMinor,
    required this.rateBps,
    required this.tenureMonths,
    this.startDay,
  });

  final int principalMinor;
  final int rateBps;
  final int tenureMonths;
  final DateTime? startDay;
}

/// One EMI of a schedule (the memory `ScheduleRow`).
class Instalment {
  const Instalment({
    required this.number,
    required this.due,
    required this.emiMinor,
    required this.interestMinor,
    required this.principalMinor,
    required this.balanceAfterMinor,
  });

  final int number;
  final DateTime? due;
  final int emiMinor;
  final int interestMinor;
  final int principalMinor;
  final int balanceAfterMinor;
}

/// Reducing-balance EMI arithmetic with monthly rests, in paise.
///
/// Rounding: the EMI and each month's interest are `round()` of an exact
/// double product (half away from zero, identical to Kotlin `roundToLong`
/// for the non-negative values seen here); zero rate uses `ceil`.
abstract final class Amortization {
  static num _monthlyRate(int rateBps) => rateBps / 10000 / 12;

  /// EMI: P r (1+r)^n / ((1+r)^n - 1); zero rate `ceil(P / n)`.
  static int emi(int principalMinor, int rateBps, int months) {
    if (principalMinor <= 0 || months <= 0) return 0;
    final r = _monthlyRate(rateBps);
    if (r == 0) return (principalMinor / months).ceil();
    final f = math.pow(1 + r, months);
    return (principalMinor * r * f / (f - 1)).round();
  }

  /// Full schedule; [emiMinor] overrides the computed EMI. The final
  /// instalment (n == tenure, or EMI >= balance + interest) clears the rest,
  /// so the balance ends at exactly zero. Capped at tenure + 600 rows.
  static List<Instalment> schedule(LoanTerms terms, {int? emiMinor}) {
    final emi = (emiMinor != null && emiMinor > 0)
        ? emiMinor
        : Amortization.emi(
            terms.principalMinor,
            terms.rateBps,
            terms.tenureMonths,
          );
    if (emi <= 0 || terms.principalMinor <= 0) return const [];
    final r = _monthlyRate(terms.rateBps);
    var balance = terms.principalMinor;
    final out = <Instalment>[];
    var n = 0;
    final cap = math.max(terms.tenureMonths, 1) + 600;
    while (balance > 0 && n < cap) {
      n++;
      final interest = (balance * r).round();
      final last = n == terms.tenureMonths || emi >= balance + interest;
      final pay = last ? balance + interest : emi;
      final principal = pay - interest;
      if (principal <= 0 && !last) break;
      balance -= principal;
      out.add(
        Instalment(
          number: n,
          due: terms.startDay == null ? null : dueOn(terms.startDay!, n),
          emiMinor: pay,
          interestMinor: interest,
          principalMinor: principal,
          balanceAfterMinor: balance < 0 ? 0 : balance,
        ),
      );
    }
    return out;
  }

  /// The [n]th EMI date (1-based): the first EMI's day of month, clamped.
  static DateTime dueOn(DateTime first, int n) {
    final d = addMonths(DateTime.utc(first.year, first.month), n - 1);
    return clampedDay(d.year, d.month, first.day);
  }

  /// EMIs due on or before [today], at most [max].
  static int elapsed(DateTime first, DateTime today, int max) {
    if (today.isBefore(first)) return 0;
    var n = monthsBetween(first, today) + 1;
    if (dueOn(first, n).isAfter(today)) n--;
    return n.clamp(0, max);
  }

  /// EMIs still needed to clear [outstandingMinor]; null when the EMI never
  /// clears it. A final instalment under 1% of an EMI is not another month.
  static int? remainingEmis(int outstandingMinor, int emiMinor, int rateBps) {
    if (outstandingMinor <= 0) return 0;
    if (emiMinor <= 0) return null;
    final r = _monthlyRate(rateBps);
    if (r == 0) return (outstandingMinor / emiMinor).ceil();
    final x = 1 - r * outstandingMinor / emiMinor;
    if (x <= 0) return null;
    return (-math.log(x) / math.log(1 + r) - 0.01).ceil();
  }

  /// Principal / interest totals of the first [paid] instalments (FR-15-04).
  static ({int principalMinor, int interestMinor}) splitPaid(
    List<Instalment> schedule,
    int paid,
  ) {
    var p = 0;
    var i = 0;
    for (final s in schedule.take(paid)) {
      p += s.principalMinor;
      i += s.interestMinor;
    }
    return (principalMinor: p, interestMinor: i);
  }

  /// A payment above 120% of the EMI is a prepayment (FR-15-08).
  static bool isPrepayment(int amountMinor, int? emiMinor) =>
      emiMinor != null && emiMinor > 0 && amountMinor * 100 > emiMinor * 120;
}
