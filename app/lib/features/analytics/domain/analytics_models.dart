import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Period kinds that matter to Analysis (FR-18-12, memory 18 section 10).
enum AnalyticsPeriodKind { month, lastMonth, custom, other }

/// Ledger slice for the selected Book and Period (memory 20 `LedgerSlice`
/// reduced to what Analysis needs). Days are UTC-midnight dates; [months]
/// are first-of-month days, the 12 ending with the period's last month.
class AnalyticsSlice {
  const AnalyticsSlice({
    required this.txs,
    required this.previous,
    required this.year,
    required this.months,
    required this.from,
    required this.to,
    required this.kind,
    this.month,
    this.previousFrom,
    this.previousTo,
    this.accounts = const [],
    this.loaded = true,
  });

  final List<LedgerTx> txs;
  final List<LedgerTx> previous;

  /// Rows of the 12-month window.
  final List<LedgerTx> year;
  final List<DateTime> months;
  final DateTime from;
  final DateTime to;
  final AnalyticsPeriodKind kind;

  /// The month when [kind] is month or lastMonth.
  final DateTime? month;
  final DateTime? previousFrom;
  final DateTime? previousTo;
  final List<CashAccount> accounts;
  final bool loaded;
}

/// Visible account facts for the cash projection (FR-18-15).
class CashAccount {
  const CashAccount({
    required this.id,
    required this.isLiquid,
    this.balanceMinor,
    this.isCard = false,
    this.isDebitCard = false,
  });

  final int id;
  final bool isLiquid;
  final int? balanceMinor;
  final bool isCard;
  final bool isDebitCard;
}

/// A recurring payment or income (memory 12 `Recurring`, reduced).
class PlannedPayment {
  const PlannedPayment({
    required this.name,
    required this.amountMinor,
    required this.category,
    required this.nextDue,
    this.accountId,
    this.income = false,
    this.yearly = false,
  });

  final String name;
  final int amountMinor;
  final Category category;
  final DateTime nextDue;
  final int? accountId;
  final bool income;
  final bool yearly;
}

enum UpcomingKind { bill, insurance, income }

/// An upcoming item (memory 12 `UpcomingPayment`, reduced).
class UpcomingItem {
  const UpcomingItem({
    required this.kind,
    required this.due,
    required this.amountMinor,
  });

  final UpcomingKind kind;
  final DateTime due;
  final int amountMinor;
}

class PlanSnapshot {
  const PlanSnapshot({this.recurring = const [], this.upcoming = const []});

  final List<PlannedPayment> recurring;
  final List<UpcomingItem> upcoming;
}

class Insight {
  const Insight(
      {required this.title, required this.detail, required this.tone});

  final String title;
  final String detail;
  final Tone tone;
}

/// Category change versus the previous period (FR-18-16).
class CategoryChange {
  const CategoryChange({
    required this.category,
    required this.now,
    required this.before,
    required this.percent,
  });

  final Category category;
  final int now;
  final int before;

  /// +100 new, -100 stopped, else `(now-before)*100/before` in -999..999.
  final int percent;

  /// Bar fraction of the diverging row: percent capped at +-50 (FR-16).
  int get barPercent => percent.clamp(-50, 50);
}

enum ForecastVerdictKind { noBudget, within, over }

class ForecastVerdict {
  const ForecastVerdict(this.kind, this.budget, this.overBy);

  final ForecastVerdictKind kind;
  final int budget;
  final int overBy;
}

class Forecast {
  const Forecast({
    required this.month,
    required this.actual,
    required this.expected,
    required this.low,
    required this.high,
    required this.billsLeft,
    required this.dailyRate,
  });

  final DateTime month;
  final List<int> actual;
  final List<int> expected;
  final List<int> low;
  final List<int> high;
  final int billsLeft;
  final int dailyRate;

  int get likely => expected.last;
  int get lowEnd => low.last;
  int get highEnd => high.last;

  /// Verdict against the sum of monthly budgets (FR-18-13).
  ForecastVerdict verdict(int budget) {
    if (budget <= 0) return ForecastVerdict(ForecastVerdictKind.noBudget, 0, 0);
    if (likely <= budget) {
      return ForecastVerdict(ForecastVerdictKind.within, budget, 0);
    }
    return ForecastVerdict(ForecastVerdictKind.over, budget, likely - budget);
  }
}

class CashProjection {
  const CashProjection({
    required this.series,
    required this.start,
    required this.lowest,
    required this.lowestOn,
    required this.bills,
    required this.incomes,
    required this.dailyRate,
  });

  /// 31 values, index 0 = today.
  final List<int> series;
  final int start;
  final int lowest;
  final DateTime lowestOn;
  final int bills;
  final int incomes;
  final int dailyRate;

  int get end => series.last;
  bool get shortfall => lowest < 0;
}

class SankeyNode {
  const SankeyNode(this.label, this.value);

  final String label;
  final int value;
}

/// Sankey inputs for "Where your income went" (FR-18-09).
class CashFlowSankey {
  const CashFlowSankey({
    required this.inputs,
    required this.outputs,
    required this.saved,
  });

  final List<SankeyNode> inputs;
  final List<SankeyNode> outputs;

  /// `income - spent - invested`; negative is a shortfall.
  final int saved;

  bool get isShortfall => saved < 0;
  int get leftOver => saved >= 0 ? saved : -saved;
}

/// Savings-rate card values (FR-18-11).
class SavingsRateSummary {
  const SavingsRateSummary({
    required this.latestMonth,
    required this.latestPercent,
    required this.averagePercent,
    required this.months,
  });

  final DateTime latestMonth;
  final int latestPercent;
  final int averagePercent;
  final int months;
}

class AnalyticsData {
  const AnalyticsData({
    this.spent = 0,
    this.income = 0,
    this.invested = 0,
    this.perDay = 0,
    this.categories = const [],
    this.groups = const {},
    this.monthly = const [],
    this.salary = 0,
    this.otherIncome = 0,
    this.refunds = 0,
    this.savingsRates = const [],
    this.changes = const [],
    this.previousSpent = 0,
    this.previousLabel = '',
    this.isCurrentMonth = false,
    this.budget = 0,
    this.budgets,
    this.forecast,
    this.cash,
    this.loaded = false,
  });

  final int spent;
  final int income;
  final int invested;
  final int perDay;
  final List<(Category, int)> categories;
  final Map<SpendGroup, int> groups;
  final List<MonthFlow> monthly;
  final int salary;
  final int otherIncome;
  final int refunds;

  /// Months with income, oldest first; percent -100..100.
  final List<(DateTime, double)> savingsRates;
  final List<CategoryChange> changes;
  final int previousSpent;
  final String previousLabel;
  final bool isCurrentMonth;

  /// Sum of monthly budget limits.
  final int budget;
  final BudgetSummary? budgets;
  final Forecast? forecast;
  final CashProjection? cash;
  final bool loaded;

  /// `income - spent`: positive is "Saved", negative "Overspent" (KPI row).
  int get savedOrOver => income - spent;

  /// This period against the previous one (Compare KPI "Change").
  int get change => spent - previousSpent;
}
