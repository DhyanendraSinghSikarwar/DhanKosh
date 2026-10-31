import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/portfolio/data/net_worth_history_source_impl.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_estimate.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_estimator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'net_worth_estimate_providers.g.dart';

/// Estimator of the 36-month history (FR-16-05).
@Riverpod(keepAlive: true)
NetWorthEstimator netWorthEstimator(Ref ref) => NetWorthEstimator(
      source: NetWorthHistorySourceImpl(ref.watch(appDatabaseProvider)),
      holdings: ref.watch(holdingRepositoryProvider),
      history: ref.watch(netWorthRepositoryProvider),
    );

/// Month-end points, estimated ones flagged; refresh with `ref.invalidate`.
@riverpod
Future<List<EstimatedPoint>> netWorthEstimate(Ref ref) {
  final now = ref.watch(netWorthProvider).value;
  return ref.watch(netWorthEstimatorProvider).estimate(
        liabilitiesNowMinor: now?.liabilitiesMinor ?? 0,
      );
}
