import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_math.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Pure sums behind every Analysis card (port of Kotlin `AnalyticsMath`,
/// `Planning.insights`). Paise, integer division throughout (FR-18-*).
///
/// Decisions recorded in memory 18 Implementation Notes: budget alert
/// fallback is 90 (memory 10 canonical, not the Kotlin 80); the forecast
/// keeps Kotlin parity for open questions 5 and 6.
abstract final class AnalyticsMath {
  /// Scheduled spends excluded from the discretionary daily rate (FR-18-14).
  static const fixedCategories = {
    Category.rent,
    Category.bills,
    Category.emiLoan,
    Category.insurance,
    Category.subscriptions,
    Category.taxes,
    Category.education,
  };

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  /// "Sep 2026".
  static String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  /// "d MMM".
  static String shortDay(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static AnalyticsData build({
    required AnalyticsSlice slice,
    required PlanSnapshot plan,
    required List<Budget> budgets,
    required int alertPercent,
    required DateTime today,
    Duration offset = istOffset,
  }) {
    if (!slice.loaded) return const AnalyticsData();
    final s = slice;
    final budget = budgets.fold(0, (a, b) => a + b.monthlyLimitMinor);
    final spent = LedgerMath.spent(s.txs);
    final income = LedgerMath.income(s.txs);
    final end = s.to.isBefore(today) ? s.to : today;
    final rawDays = daysBetween(s.from, end) + 1;
    final days = rawDays < 1 ? 1 : rawDays;
    final monthly = LedgerMath.monthly(s.year, s.months, offset: offset);

    var salary = 0;
    var refunds = 0;
    var other = 0;
    for (final t in s.txs.where(LedgerMath.isIncome)) {
      final v = LedgerMath.rupees(t);
      if (t.category == Category.salary) {
        salary += v;
      } else if (t.category == Category.refund ||
          (t.merchant ?? '').toLowerCase().contains('interest')) {
        refunds += v;
      } else {
        other += v;
      }
    }

    final nowList = LedgerMath.byCategory(s.txs);
    final now = {for (final e in nowList) e.$1: e.$2};
    final before = {
      for (final e in LedgerMath.byCategory(s.previous)) e.$1: e.$2,
    };
    final changes = stableSorted<CategoryChange>(
      [
        for (final c in {...now.keys, ...before.keys})
          _change(c, now[c] ?? 0, before[c] ?? 0),
      ],
      (a, b) => (b.now - b.before).abs().compareTo((a.now - a.before).abs()),
    );

    final String prevLabel;
    final pf = s.previousFrom;
    final pt = s.previousTo;
    if (s.kind == AnalyticsPeriodKind.month ||
        s.kind == AnalyticsPeriodKind.lastMonth) {
      prevLabel = pf == null ? '' : monthLabel(pf);
    } else {
      prevLabel =
          (pf == null || pt == null) ? '' : '${shortDay(pf)} – ${shortDay(pt)}';
    }

    final current = s.kind == AnalyticsPeriodKind.month &&
        s.month != null &&
        s.month!.year == today.year &&
        s.month!.month == today.month;
    final rate = current ? discretionaryRate(s.year, today, offset: offset) : 0;

    return AnalyticsData(
      spent: spent,
      income: income,
      invested: LedgerMath.invested(s.txs),
      perDay: spent ~/ days,
      categories: nowList,
      groups: LedgerMath.byGroup(s.txs),
      monthly: monthly,
      salary: salary,
      otherIncome: other,
      refunds: refunds,
      savingsRates: savingsRates(monthly),
      changes: changes,
      previousSpent: LedgerMath.spent(s.previous),
      previousLabel: prevLabel,
      isCurrentMonth: current,
      budget: budget,
      budgets: budgetSummary(s, now, budgets, alertPercent, today),
      forecast:
          current ? forecast(s.txs, plan, rate, today, offset: offset) : null,
      cash: current ? cash(s, plan, rate, today) : null,
      loaded: true,
    );
  }

  /// FR-18-16 percent: new +100, stopped -100, else clamp -999..999.
  static CategoryChange _change(Category c, int a, int b) {
    final int pct;
    if (b == 0) {
      pct = 100;
    } else if (a == 0) {
      pct = -100;
    } else {
      pct = ((a - b) * 100 ~/ b).clamp(-999, 999);
    }
    return CategoryChange(category: c, now: a, before: b, percent: pct);
  }

  /// `(income - spent) * 100 / income` clamped -100..100, for months with
  /// income, oldest first (FR-18-11; investments not deducted).
  static List<(DateTime, double)> savingsRates(List<MonthFlow> monthly) => [
        for (final m in monthly)
          if (m.income > 0)
            (
              m.month,
              ((m.income - m.spent) * 100 / m.income)
                  .clamp(-100, 100)
                  .toDouble(),
            ),
      ];

  /// Savings-rate card: needs >= 2 months (FR-18-11); rounds half up.
  static SavingsRateSummary? savingsSummary(List<(DateTime, double)> rates) {
    if (rates.length < 2) return null;
    int round(double x) => (x + 0.5).floor();
    final avg = rates.fold(0.0, (a, e) => a + e.$2) / rates.length;
    return SavingsRateSummary(
      latestMonth: rates.last.$1,
      latestPercent: round(rates.last.$2),
      averagePercent: round(avg),
      months: rates.length,
    );
  }

  /// Sankey inputs and outputs (FR-18-09, FR-18-10).
  static CashFlowSankey sankey(AnalyticsData d) {
    final saved = d.income - d.spent - d.invested;
    return CashFlowSankey(
      inputs: [
        SankeyNode('Salary', d.salary),
        SankeyNode('Other income', d.otherIncome),
        SankeyNode('Refunds & interest', d.refunds),
      ],
      outputs: [
        SankeyNode('Essentials', d.groups[SpendGroup.essentials] ?? 0),
        SankeyNode('Lifestyle', d.groups[SpendGroup.lifestyle] ?? 0),
        SankeyNode('Other', d.groups[SpendGroup.other] ?? 0),
        SankeyNode('Invested', d.invested),
        SankeyNode('Saved', saved < 0 ? 0 : saved),
      ],
      saved: saved,
    );
  }

  /// Budgets against the period's spend; limits scale with the calendar
  /// months spanned; pace only for the current single month (FR-18-08).
  static BudgetSummary budgetSummary(
    AnalyticsSlice s,
    Map<Category, int> spentByCategory,
    List<Budget> list,
    int alertPercent,
    DateTime today,
  ) {
    final m = monthsBetween(s.from, s.to) + 1;
    final months = m < 1 ? 1 : m;
    final lines = BudgetMath.sortedUse(
      [
        for (final b in list)
          if (b.monthlyLimitMinor > 0) b
      ],
      spentByCategory,
      months: months,
    );
    final single = months == 1 &&
        s.from.year == today.year &&
        s.from.month == today.month &&
        !s.to.isBefore(today);
    return BudgetSummary(
      lines: lines,
      months: months,
      alertPercent: BudgetMath.normaliseAlertPercent(alertPercent),
      pace: BudgetMath.paceTick(
        singleCurrentMonth: single,
        dayOfMonth: today.day,
        lengthOfMonth: daysInMonth(today.year, today.month),
      ),
    );
  }

  /// Average day's discretionary spend: the three prior months (with any
  /// such spend) blended with this month's pace (FR-18-14).
  static int discretionaryRate(
    List<LedgerTx> year,
    DateTime today, {
    Duration offset = istOffset,
  }) {
    final byMonth = <int, int>{};
    for (final t in year) {
      if (!LedgerMath.isSpend(t) || fixedCategories.contains(t.category)) {
        continue;
      }
      final d = dayOf(t.timestamp, offset: offset);
      final k = d.year * 12 + d.month;
      byMonth[k] = (byMonth[k] ?? 0) + LedgerMath.rupees(t);
    }
    final cur = today.year * 12 + today.month;
    final prior = [
      for (var i = 1; i <= 3; i++)
        if (byMonth.containsKey(cur - i)) cur - i,
    ];
    int? priorRate;
    if (prior.isNotEmpty) {
      var sum = 0;
      var len = 0;
      for (final k in prior) {
        sum += byMonth[k]!;
        len += daysInMonth((k - 1) ~/ 12, (k - 1) % 12 + 1);
      }
      priorRate = sum ~/ len;
    }
    final curRate = (byMonth[cur] ?? 0) ~/ today.day;
    if (priorRate == null) return curRate;
    if (today.day < 7) return priorRate;
    return (priorRate + curRate) ~/ 2;
  }

  /// Month-end forecast (FR-18-13); only for the current month.
  static Forecast forecast(
    List<LedgerTx> txs,
    PlanSnapshot plan,
    int rate,
    DateTime today, {
    Duration offset = istOffset,
  }) {
    final month = DateTime.utc(today.year, today.month);
    final d0 = today.day;
    final actual =
        LedgerMath.cumulative(txs, month, offset: offset).take(d0).toList();
    final base = actual.isEmpty ? 0 : actual.last;
    final bills = plan.upcoming
        .where(
          (u) =>
              u.kind != UpcomingKind.income &&
              u.due.year == today.year &&
              u.due.month == today.month &&
              !u.due.isBefore(today),
        )
        .toList();
    final remaining = daysInMonth(today.year, today.month) - d0;
    int billsBy(int i) => i == 0
        ? 0
        : bills
            .where((b) => b.due.day <= d0 + i)
            .fold(0, (a, b) => a + b.amountMinor);
    final expected = [
      for (var i = 0; i <= remaining; i++) base + billsBy(i) + rate * i,
    ];
    final low = [
      for (var i = 0; i <= remaining; i++)
        base + billsBy(i) + rate * i * 8 ~/ 10,
    ];
    final high = [
      for (var i = 0; i <= remaining; i++)
        base + billsBy(i) + rate * i * 12 ~/ 10,
    ];
    return Forecast(
      month: month,
      actual: actual,
      expected: expected,
      low: low,
      high: high,
      billsLeft: billsBy(remaining),
      dailyRate: rate,
    );
  }

  /// Cash balance for the next 30 days (FR-18-15); null without a liquid
  /// account that has a known balance.
  static CashProjection? cash(
    AnalyticsSlice s,
    PlanSnapshot plan,
    int rate,
    DateTime today,
  ) {
    final liquid =
        s.accounts.where((a) => a.isLiquid && a.balanceMinor != null).toList();
    if (liquid.isEmpty) return null;
    final start = liquid.fold(0, (a, e) => a + e.balanceMinor!);
    final end = today.add(const Duration(days: 30));
    final byId = {for (final a in s.accounts) a.id: a};
    final events = List<int>.filled(31, 0);
    var bills = 0;
    var incomes = 0;
    void add(DateTime d, int amount) {
      if (d.isBefore(today) || d.isAfter(end)) return;
      final raw = daysBetween(today, d);
      final i = raw < 1 ? 1 : raw;
      events[i] += amount;
      if (amount < 0) {
        bills++;
      } else {
        incomes++;
      }
    }

    for (final r in plan.recurring) {
      final acc = r.accountId == null ? null : byId[r.accountId];
      // Card charges reach the bank only when the card bill is paid.
      if (!r.income && acc != null && acc.isCard && !acc.isDebitCard) continue;
      var d = r.nextDue;
      while (!d.isAfter(end)) {
        add(d, r.income ? r.amountMinor : -r.amountMinor);
        if (r.yearly) break;
        d = addMonths(d, 1);
      }
    }
    for (final u
        in plan.upcoming.where((u) => u.kind == UpcomingKind.insurance)) {
      add(u.due, -u.amountMinor);
    }
    var bal = start;
    final series = <int>[];
    for (var i = 0; i <= 30; i++) {
      if (i > 0) bal += events[i] - rate;
      series.add(bal);
    }
    var low = 0;
    for (var i = 1; i < series.length; i++) {
      if (series[i] < series[low]) low = i;
    }
    return CashProjection(
      series: series,
      start: start,
      lowest: series[low],
      lowestOn: today.add(Duration(days: low)),
      bills: bills,
      incomes: incomes,
      dailyRate: rate,
    );
  }

  /// `₹1,23,456`: Indian grouping, no paise (insight text).
  static String rupeeText(int minor) {
    final s = (minor ~/ 100).toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    for (var i = rest.length; i > 0; i -= 2) {
      parts.insert(0, rest.substring(i - 2 < 0 ? 0 : i - 2, i));
    }
    return '₹${parts.join(',')},$last3';
  }

  /// Up to [max] plain-language insights in order: pace, drift, regular
  /// payments, biggest expense, weekend share (FR-18-17). Counts all DEBIT
  /// rows in INR by raw `amountMinor` (memory 18 Open Question 4 parity).
  static List<Insight> insights(
    List<LedgerTx> txs,
    List<PlannedPayment> recurring,
    DateTime today, {
    int max = 5,
    Duration offset = istOffset,
  }) {
    final out = <Insight>[];
    final spend = txs
        .where(
          (t) =>
              t.type == TransactionType.debit &&
              !t.needsReview &&
              t.currency == 'INR',
        )
        .toList();
    List<LedgerTx> inMonth(int year, int month, [int upToDay = 31]) => [
          for (final t in spend)
            if (() {
              final d = dayOf(t.timestamp, offset: offset);
              return d.year == year && d.month == month && d.day <= upToDay;
            }())
              t,
        ];
    int sum(Iterable<LedgerTx> l) => l.fold(0, (a, t) => a + t.amountMinor);
    final prevM = addMonths(DateTime.utc(today.year, today.month), -1);

    final nowSoFar = sum(inMonth(today.year, today.month, today.day));
    final lastSoFar = sum(inMonth(prevM.year, prevM.month, today.day));
    if (lastSoFar > 0 && nowSoFar > 0) {
      final pct = (nowSoFar - lastSoFar) * 100 ~/ lastSoFar;
      if (pct.abs() >= 10) {
        out.add(
          Insight(
            title: pct > 0
                ? 'Spending is $pct% ahead of last month'
                : 'Spending is ${-pct}% below last month',
            detail: "By day ${today.day} you've spent ${rupeeText(nowSoFar)}, "
                'against ${rupeeText(lastSoFar)} by this day last month.',
            tone: pct > 0 ? Tone.warn : Tone.good,
          ),
        );
      }
    }

    final prev3 = [
      for (var i = 1; i <= 3; i++)
        addMonths(DateTime.utc(today.year, today.month), -i),
    ];
    final cur = inMonth(today.year, today.month);
    Category? driftCat;
    var driftNow = 0;
    var driftAvg = 0;
    for (final c in Category.values) {
      var tot = 0;
      for (final m in prev3) {
        tot += sum(inMonth(m.year, m.month).where((t) => t.category == c));
      }
      final avg = tot ~/ 3;
      final nowC = sum(cur.where((t) => t.category == c));
      if (avg <= 0) continue;
      if (driftCat == null || nowC - avg > driftNow - driftAvg) {
        driftCat = c;
        driftNow = nowC;
        driftAvg = avg;
      }
    }
    if (driftCat != null && driftNow - driftAvg >= 50000) {
      out.add(
        Insight(
          title: '${driftCat.label} is above your usual',
          detail: '${rupeeText(driftNow)} so far this month against a '
              '3-month average of ${rupeeText(driftAvg)}.',
          tone: Tone.warn,
        ),
      );
    }

    final regular = recurring.where((r) => !r.income).toList();
    if (regular.isNotEmpty) {
      final subs = regular
          .where(
            (r) =>
                r.category == Category.subscriptions ||
                r.category == Category.entertainment ||
                r.category == Category.bills,
          )
          .toList();
      final total = regular.fold(0, (a, r) => a + r.amountMinor);
      final subTotal = subs.fold(0, (a, r) => a + r.amountMinor);
      out.add(
        Insight(
          title: '${regular.length} regular payments, '
              '${rupeeText(total)} a month',
          detail: subs.isNotEmpty
              ? 'Including ${subs.length} subscription'
                  '${subs.length > 1 ? 's' : ''} and bills worth '
                  '${rupeeText(subTotal)}.'
              : 'Rent, EMIs, SIPs and premiums that come every month.',
          tone: Tone.info,
        ),
      );
    }

    if (cur.isNotEmpty) {
      var big = cur.first;
      for (final t in cur) {
        if (t.amountMinor > big.amountMinor) big = t;
      }
      final d = dayOf(big.timestamp, offset: offset);
      out.add(
        Insight(
          title: 'Biggest expense: ${rupeeText(big.amountMinor)}',
          detail: '${big.merchant ?? big.category.label} on ${d.day} '
              '${_months[today.month - 1]}.',
          tone: Tone.info,
        ),
      );
    }

    final total = sum(cur);
    if (total > 0) {
      final weekend = sum(
        cur.where((t) {
          final wd = dayOf(t.timestamp, offset: offset).weekday;
          return wd == DateTime.saturday || wd == DateTime.sunday;
        }),
      );
      final pct = weekend * 100 ~/ total;
      if (pct >= 45) {
        out.add(
          Insight(
            title: '$pct% of spending is on weekends',
            detail:
                'Weekends are 2 days in 7, but most of the money goes then.',
            tone: Tone.info,
          ),
        );
      }
    }
    return out.take(max).toList();
  }
}
