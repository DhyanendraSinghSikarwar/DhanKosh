import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/insight_extras.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

/// Months the Analysis tab can show (FR-18-12; custom range deferred).
enum AnalyticsPeriod { thisMonth, lastMonth }

/// Everything the Analysis tab renders for one period (FR-18-01).
class AnalyticsView {
  /// Creates a view.
  const AnalyticsView({
    required this.data,
    required this.txs,
    required this.insights,
    required this.heat,
    required this.merchants,
    this.incomeSources = const [],
    this.subscriptions = const [],
    this.cards = const [],
  });

  /// Empty, still loading.
  static const empty = AnalyticsView(
    data: AnalyticsData(),
    txs: [],
    insights: [],
    heat: [],
    merchants: [],
  );

  final AnalyticsData data;
  final List<LedgerTx> txs;
  final List<Insight> insights;
  final HeatGrid heat;
  final List<MerchantSpend> merchants;

  /// Credits by source (FR-18-24).
  final List<IncomeSource> incomeSources;

  /// Detected subscriptions (FR-18-25).
  final List<SubscriptionLine> subscriptions;

  /// Credit utilisation per card (FR-18-26).
  final List<CardUtil> cards;
}
