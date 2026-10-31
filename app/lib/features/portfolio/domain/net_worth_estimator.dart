import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_estimate.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_history_source.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_repository.dart';

/// Builds the 36-month estimated history (FR-16-05, A6): recorded points win,
/// the rest is flagged estimated.
class NetWorthEstimator {
  /// Creates the estimator; [now] is epoch ms.
  NetWorthEstimator({
    required NetWorthHistorySource source,
    required HoldingRepository holdings,
    required NetWorthRepository history,
    int Function()? now,
  })  : _source = source,
        _holdings = holdings,
        _history = history,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final NetWorthHistorySource _source;
  final HoldingRepository _holdings;
  final NetWorthRepository _history;
  final int Function() _now;

  /// Month-end points, oldest first. [liabilitiesNowMinor] stands in for
  /// liabilities while nothing is recorded yet.
  Future<List<EstimatedPoint>> estimate({
    int months = 36,
    int liabilitiesNowMinor = 0,
  }) async {
    final now = _now();
    final today = (now + 19800000) ~/ 86400000;
    final since = now - (months + 1) * 31 * 86400000;
    final recorded = await _history.points();
    final held = await _holdings.list();
    return estimateWorthHistory(
      todayDay: today,
      accounts: await _source.accountFlows(sinceMs: since),
      holdings: [
        for (final h in held)
          if ((h.valueMinor ?? 0) > 0)
            HoldingValue((h.updatedAt + 19800000) ~/ 86400000, h.valueMinor!),
      ],
      liabilitiesMinor: recorded.isEmpty
          ? liabilitiesNowMinor
          : recorded.last.liabilitiesMinor,
      recorded: recorded,
      months: months,
    );
  }
}
