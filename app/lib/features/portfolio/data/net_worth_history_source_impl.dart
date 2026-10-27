import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_estimate.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_history_source.dart';

/// [NetWorthHistorySource] over accounts and the ledger (read only).
class NetWorthHistorySourceImpl implements NetWorthHistorySource {
  /// Creates the source.
  const NetWorthHistorySourceImpl(this._db);

  final AppDatabase _db;

  // Signed effect of a row on a balance (memory 13 section 3.5).
  static const _effect = '''
CASE t.type
  WHEN 'CREDIT' THEN t.inr_minor
  WHEN 'DEBIT' THEN -t.inr_minor
  WHEN 'INVESTMENT' THEN -t.inr_minor
  WHEN 'TRANSFER' THEN CASE
    WHEN t.account_kind = 'CARD' THEN t.inr_minor
    WHEN EXISTS (SELECT 1 FROM transaction_sources s WHERE s.transaction_id = t.id
                 AND s.source_message_id LIKE 'xfer-out:%') THEN -t.inr_minor
    WHEN EXISTS (SELECT 1 FROM transaction_sources s WHERE s.transaction_id = t.id
                 AND s.source_message_id LIKE 'xfer-in:%') THEN t.inr_minor
    WHEN t.note LIKE 'Credit card bill%' THEN -t.inr_minor
    ELSE 0 END
  ELSE 0 END''';

  @override
  Future<List<AccountFlow>> accountFlows({required int sinceMs}) async {
    final all = await _db.select(_db.accounts).get();
    int root(AccountRow a) {
      var id = a.mergedIntoId ?? a.id;
      final linked = all.where((x) => x.id == a.linkedAccountId).firstOrNull;
      if (linked != null) id = linked.mergedIntoId ?? linked.id;
      return id;
    }

    final rows = await _db.customSelect(
      'SELECT t.account_id AS a, t.timestamp AS ts, $_effect AS e '
      'FROM transactions t WHERE t.needs_review = 0 AND t.inr_minor IS NOT NULL '
      'AND t.account_id IS NOT NULL AND t.timestamp > ?',
      variables: [Variable<int>(sinceMs)],
      readsFrom: {_db.transactions, _db.transactionSources},
    ).get();
    final effects = <int, List<(int, int)>>{};
    final groupOf = {for (final a in all) a.id: root(a)};
    for (final r in rows) {
      final g = groupOf[r.read<int>('a')];
      final e = r.read<int>('e');
      if (g == null || e == 0) continue;
      (effects[g] ??= []).add((r.read<int>('ts'), e));
    }
    final out = <AccountFlow>[];
    for (final a in all) {
      final type = enumFromDbOrNull(AccountType.values, a.accountType);
      if (a.hidden ||
          a.mergedIntoId != null ||
          a.linkedAccountId != null ||
          a.kind != 'ACCOUNT' ||
          (type != null && !type.liquid)) {
        continue;
      }
      final fx = effects[a.id] ?? const <(int, int)>[];
      final manual = a.manualBalanceMinor;
      final manualAt = a.manualBalanceAt;
      final reported = a.latestBalanceMinor;
      final reportedAt = a.balanceUpdatedAt;
      int? now;
      if (manual != null &&
          manualAt != null &&
          (reported == null || reportedAt == null || manualAt >= reportedAt)) {
        now = manual;
        for (final (ts, e) in fx) {
          if (ts > manualAt) now = now! + e;
        }
      } else if (reported != null) {
        now = reported;
        for (final (ts, e) in fx) {
          if (reportedAt != null && ts > reportedAt) now = now! + e;
        }
      }
      if (now != null) {
        out.add(
          AccountFlow(
            balanceNowMinor: now,
            effects: [
              for (final (ts, e) in fx)
                FlowEffect((ts + 19800000) ~/ 86400000, e),
            ],
          ),
        );
      }
    }
    return out;
  }
}
