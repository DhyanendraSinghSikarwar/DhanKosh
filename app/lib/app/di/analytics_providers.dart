import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/analytics/domain/analytics_math.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/analytics_view.dart';
import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/tax_centre/domain/tax_deductions.dart';
import 'package:hisaab/features/tax_centre/domain/tax_income.dart';
import 'package:hisaab/features/tax_centre/domain/tax_plan.dart';
import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_providers.g.dart';

// Analytics (F-18) and Tax Centre (F-19) UI wiring.

/// Selected Analysis period (FR-18-12).
@riverpod
class AnalyticsPeriodChoice extends _$AnalyticsPeriodChoice {
  @override
  AnalyticsPeriod build() => AnalyticsPeriod.thisMonth;

  /// Selects [p].
  // ignore: use_setters_to_change_properties
  void select(AnalyticsPeriod p) => state = p;
}

DateTime _todayIst() => dayOf(DateTime.now().millisecondsSinceEpoch);

/// Analysis data for the chosen period (FR-18-01..17).
@riverpod
Stream<AnalyticsView> analyticsView(Ref ref) async* {
  final period = ref.watch(analyticsPeriodChoiceProvider);
  final budgets = ref.watch(budgetsProvider).value ?? const [];
  final today = _todayIst();
  final cur = DateTime.utc(today.year, today.month);
  final month = period == AnalyticsPeriod.thisMonth ? cur : addMonths(cur, -1);
  final months = [for (var i = 11; i >= 0; i--) addMonths(month, -i)];
  final prev = addMonths(month, -1);
  final to = DateTime.utc(month.year, month.month + 1, 0);
  final winEnd = epochMsOf(addMonths(month, 1));
  final winStart = epochMsOf(months.first);
  final repo = ref.watch(transactionRepositoryProvider);
  await for (final all
      in repo.watch(LedgerFilter(fromMs: winStart, toMs: winEnd))) {
    List<LedgerTx> within(DateTime a, DateTime b) => all.where((t) {
          final d = dayOf(t.timestamp);
          return !d.isBefore(a) && !d.isAfter(b);
        }).toList();
    final txs = within(month, to);
    final slice = AnalyticsSlice(
      txs: txs,
      previous: within(prev, DateTime.utc(prev.year, prev.month + 1, 0)),
      year: all,
      months: months,
      from: month,
      to: to,
      kind: period == AnalyticsPeriod.thisMonth
          ? AnalyticsPeriodKind.month
          : AnalyticsPeriodKind.lastMonth,
      month: month,
      previousFrom: prev,
      previousTo: DateTime.utc(prev.year, prev.month + 1, 0),
    );
    final data = AnalyticsMath.build(
      slice: slice,
      plan: const PlanSnapshot(),
      budgets: budgets,
      alertPercent: 90,
      today: today,
    );
    yield AnalyticsView(
      data: data,
      txs: txs,
      insights: AnalyticsMath.insights(txs, const [], today),
      heat: LedgerMath.heat(txs),
      merchants: LedgerMath.topMerchants(txs),
    );
  }
}

/// Selected Tax Centre period (FR-19-01).
@riverpod
class TaxPeriodChoice extends _$TaxPeriodChoice {
  @override
  TaxPeriod build() => TaxPeriod.thisFy;

  /// Selects [p].
  // ignore: use_setters_to_change_properties
  void select(TaxPeriod p) => state = p;
}

/// In-memory what-if values; never stored (FR-19-07).
@riverpod
class TaxWhatIfState extends _$TaxWhatIfState {
  @override
  TaxWhatIf build() => const TaxWhatIf();

  /// Replaces the what-if values.
  // ignore: use_setters_to_change_properties
  void set(TaxWhatIf w) => state = w;
}

/// Detected income and deductions of the chosen period (FR-19-02, 05, 06).
@riverpod
Stream<TaxBaseline> taxBaseline(Ref ref) async* {
  final period = ref.watch(taxPeriodChoiceProvider);
  final today = _todayIst();
  final b = FinancialYear.bounds(period, today);
  final fromMs = epochMsOf(b.from);
  final toMs = epochMsOf(b.to.add(const Duration(days: 1)));
  final repo = ref.watch(transactionRepositoryProvider);
  await for (final all in repo.watch(LedgerFilter(toMs: toMs))) {
    yield TaxBaseline(
      period: period,
      fyStartYear: b.fyStartYear,
      est: TaxIncome.estimate(all, b.from, b.to, today),
      deductions: TaxDeductionDetector.detect(all, fromMs, toMs),
    );
  }
}
