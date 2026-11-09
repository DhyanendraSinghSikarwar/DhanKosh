/// What is safe to spend today (FR-17-48, ADR-0012). Pure; paise.
class SafeToSpendResult {
  /// Creates a result.
  const SafeToSpendResult({
    required this.perDayMinor,
    required this.spendableMinor,
    required this.billsMinor,
    required this.daysLeft,
    this.budgetLeftMinor,
  });

  /// Safe amount per day, rounded down.
  final int perDayMinor;

  /// Balance minus bills, capped by the budget left, never below zero.
  final int spendableMinor;

  /// Unpaid bills, EMIs and card dues before the month ends.
  final int billsMinor;

  /// Days left this month, today included.
  final int daysLeft;

  /// Budget left this month when budgets exist (may be negative).
  final int? budgetLeftMinor;
}

/// The rule behind the Home "Safe to spend" section.
abstract final class SafeToSpend {
  /// Null when no liquid balance is known.
  static SafeToSpendResult? compute({
    required int? liquidMinor,
    required int billsMinor,
    required int daysLeft,
    int? budgetLeftMinor,
  }) {
    if (liquidMinor == null) return null;
    final days = daysLeft < 1 ? 1 : daysLeft;
    var spendable = liquidMinor - billsMinor;
    final cap = budgetLeftMinor;
    if (cap != null && cap < spendable) spendable = cap;
    if (spendable < 0) spendable = 0;
    return SafeToSpendResult(
      perDayMinor: spendable ~/ days,
      spendableMinor: spendable,
      billsMinor: billsMinor,
      daysLeft: days,
      budgetLeftMinor: cap,
    );
  }
}
