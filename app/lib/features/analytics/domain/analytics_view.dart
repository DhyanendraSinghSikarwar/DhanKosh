import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/insight_extras.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';

/// Periods the Analysis tab can show (FR-18-12).
enum AnalyticsPeriod { thisMonth, lastMonth, custom }

/// Account/card scope of Analysis (FR-18-27); empty means every account.
class AnalyticsScope {
  /// Creates a scope.
  const AnalyticsScope({this.accountIds = const {}});

  /// Selected account and card ids.
  final Set<int> accountIds;

  /// Whether [accountId] is in scope.
  bool allows(int? accountId) =>
      accountIds.isEmpty ||
      (accountId != null && accountIds.contains(accountId));
}

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
    this.year = const [],
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

  /// Rows of the 12-month window (for cross-filtered bars, FR-18-20).
  final List<LedgerTx> year;
}
