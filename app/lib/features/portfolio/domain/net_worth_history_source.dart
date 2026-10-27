import 'package:hisaab/features/portfolio/domain/net_worth_estimate.dart';

/// Account balances and dated effects for the history estimate (A6).
abstract interface class NetWorthHistorySource {
  /// One flow per liquid, visible account group (merged children and linked
  /// debit cards roll into their target), effects since [sinceMs].
  Future<List<AccountFlow>> accountFlows({required int sinceMs});
}
