/// Target split of income (FR-36-07), whole percents summing to 100.
class SalaryPlan {
  /// Creates a plan.
  const SalaryPlan({
    required this.savingsPct,
    required this.investPct,
    required this.spendPct,
  });

  /// Reads [encode] output; [standard] when malformed or not summing to 100.
  factory SalaryPlan.decode(String? text) {
    final p = (text ?? '').split(':').map(int.tryParse).toList();
    if (p.length != 3 || p.contains(null)) return standard;
    final plan =
        SalaryPlan(savingsPct: p[0]!, investPct: p[1]!, spendPct: p[2]!);
    return plan.valid ? plan : standard;
  }

  /// 20% savings, 20% investments, 60% spending.
  static const standard =
      SalaryPlan(savingsPct: 20, investPct: 20, spendPct: 60);

  final int savingsPct;
  final int investPct;
  final int spendPct;

  /// True when each part is 0..100 and the parts sum to 100.
  bool get valid =>
      savingsPct >= 0 &&
      investPct >= 0 &&
      spendPct >= 0 &&
      savingsPct + investPct + spendPct == 100;

  /// `s:i:p` for the settings table.
  String encode() => '$savingsPct:$investPct:$spendPct';
}

/// What a month actually did, paise (FR-36-08).
class MonthActual {
  /// Creates a month.
  const MonthActual({
    required this.monthStartMs,
    required this.incomeMinor,
    required this.investedMinor,
    required this.spentMinor,
  });

  /// Epoch ms of the first day, IST.
  final int monthStartMs;

  /// Credits that are neither transfers nor refunds.
  final int incomeMinor;

  /// INVESTMENT rows.
  final int investedMinor;

  /// Expenses net of refunds.
  final int spentMinor;

  /// Income left after spending and investing, never below 0.
  int get savedMinor {
    final left = incomeMinor - spentMinor - investedMinor;
    return left > 0 ? left : 0;
  }
}

/// One row of the plan versus actual table (FR-36-08).
class PlanLine {
  /// Creates a line.
  const PlanLine(this.label, this.plannedMinor, this.actualMinor);

  final String label;
  final int plannedMinor;
  final int actualMinor;

  /// Actual minus planned.
  int get deltaMinor => actualMinor - plannedMinor;
}

/// Plan versus actual maths, integer only (memory 36 section 10).
abstract final class SalaryPlanMath {
  /// FR-36-08: Savings, Investments and Spending lines for [m]. Planned is
  /// income times the percent, rounded down.
  static List<PlanLine> lines(SalaryPlan plan, MonthActual m) => [
        PlanLine(
          'Savings',
          m.incomeMinor * plan.savingsPct ~/ 100,
          m.savedMinor,
        ),
        PlanLine(
          'Investments',
          m.incomeMinor * plan.investPct ~/ 100,
          m.investedMinor,
        ),
        PlanLine(
          'Spending',
          m.incomeMinor * plan.spendPct ~/ 100,
          m.spentMinor,
        ),
      ];
}
