/// Income, spent and invested for a period, paise (FR-11-05, FR-11-06).
class CashFlow {
  /// Creates a cash flow.
  const CashFlow({
    required this.incomeMinor,
    required this.spentMinor,
    required this.investedMinor,
  });

  final int incomeMinor;
  final int spentMinor;
  final int investedMinor;

  /// `income - spent - invested`.
  int get savedMinor => incomeMinor - spentMinor - investedMinor;

  /// Integer percent `saved * 100 ~/ income`; null when income is 0.
  int? get ratePercent =>
      incomeMinor > 0 ? savedMinor * 100 ~/ incomeMinor : null;
}

/// One calendar month's totals (`yyyy-MM`, IST).
class MonthFlow {
  /// Creates a month flow.
  const MonthFlow({
    required this.yearMonth,
    required this.incomeMinor,
    required this.spentMinor,
    required this.investedMinor,
  });

  final String yearMonth;
  final int incomeMinor;
  final int spentMinor;
  final int investedMinor;

  /// As a [CashFlow].
  CashFlow get flow => CashFlow(
        incomeMinor: incomeMinor,
        spentMinor: spentMinor,
        investedMinor: investedMinor,
      );
}

/// One point of the Analysis savings-rate card (FR-11-09).
class SavingsRatePoint {
  /// Creates a point.
  const SavingsRatePoint(this.yearMonth, this.percent);

  final String yearMonth;

  /// `(income - spent) * 100 / income` clamped -100..100.
  final double percent;
}

/// Pure cash-flow maths.
abstract final class CashFlowMath {
  /// Points for months with income; empty when fewer than 2 (FR-11-09).
  static List<SavingsRatePoint> savingsRateSeries(List<MonthFlow> months) {
    final withIncome = months.where((m) => m.incomeMinor > 0).toList()
      ..sort((a, b) => a.yearMonth.compareTo(b.yearMonth));
    if (withIncome.length < 2) return const [];
    return [
      for (final m in withIncome)
        SavingsRatePoint(
          m.yearMonth,
          ((m.incomeMinor - m.spentMinor) * 100 / m.incomeMinor).clamp(
            -100.0,
            100.0,
          ),
        ),
    ];
  }

  /// n for "Best in n months" when [rate] beats every other income month and
  /// at least 2 others exist (FR-11-07); otherwise null.
  static int? bestInMonths(int rate, List<int> otherRates) {
    if (otherRates.length < 2) return null;
    if (otherRates.any((r) => r >= rate)) return null;
    return otherRates.length + 1;
  }

  /// Estimation months and scaling (FR-11-11): salary continues at the latest
  /// month's pay for the unseen months.
  static int estimateYearMinor({
    required int salarySoFar,
    required int latestSalary,
    required int months,
  }) =>
      salarySoFar + latestSalary * (12 - months.clamp(0, 12));

  /// Other buckets scaled by 12 / months (integer, rounded down).
  static int scaleToYear(int minor, int months) =>
      months <= 0 ? 0 : minor * 12 ~/ months.clamp(1, 12);
}
