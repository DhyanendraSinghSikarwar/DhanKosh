import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_admin_repository.dart';
import 'package:parser_core/parser_core.dart';

/// [AccountAdminRepository] over the `accounts` table.
class AccountAdminRepositoryImpl implements AccountAdminRepository {
  /// Creates the repository.
  AccountAdminRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  Account _map(AccountRow r) => Account(
        id: r.id,
        bankName: r.bankName,
        last4: r.last4,
        kind: enumFromDb(AccountKind.values, r.kind, AccountKind.account),
        createdAt: r.createdAt,
        nickname: r.nickname,
        colorArgb: r.colorArgb,
        latestBalanceMinor: r.latestBalanceMinor,
        availableLimitMinor: r.availableLimitMinor,
        balanceUpdatedAt: r.balanceUpdatedAt,
        manualBalanceMinor: r.manualBalanceMinor,
        manualBalanceAt: r.manualBalanceAt,
        accountType: enumFromDbOrNull(AccountType.values, r.accountType),
        cardNetwork: enumFromDbOrNull(CardNetwork.values, r.cardNetwork),
        linkedAccountId: r.linkedAccountId,
        hidden: r.hidden,
        usage: enumFromDb(AccountUsage.values, r.usage, AccountUsage.personal),
        mergedIntoId: r.mergedIntoId,
      );

  Future<void> _patch(int id, AccountsCompanion c) =>
      (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(c);

  @override
  Future<List<Account>> all() async =>
      (await _db.select(_db.accounts).get()).map(_map).toList();

  @override
  Future<void> setColor(int id, int? argb) =>
      _patch(id, AccountsCompanion(colorArgb: Value(argb)));

  @override
  Future<void> setNetwork(int id, CardNetwork? network) => _patch(
        id,
        AccountsCompanion(
          cardNetwork: Value(network == null ? null : enumToDb(network)),
        ),
      );

  @override
  Future<void> setLinkedAccount(int id, int? accountId) {
    if (accountId == id) throw ArgumentError('Cannot link to itself');
    return _patch(id, AccountsCompanion(linkedAccountId: Value(accountId)));
  }

  @override
  Future<void> setUsage(int id, AccountUsage usage) =>
      _patch(id, AccountsCompanion(usage: Value(enumToDb(usage))));

  @override
  Future<void> setForexMarkupBps(int id, int? bps) {
    if (bps != null && (bps < 0 || bps > 2000)) {
      throw ArgumentError('Markup must be 0..20%');
    }
    return _patch(id, AccountsCompanion(forexMarkupBps: Value(bps)));
  }

  @override
  Future<int?> forexMarkupBps(int id) async =>
      (await (_db.select(_db.accounts)..where((t) => t.id.equals(id)))
              .getSingleOrNull())
          ?.forexMarkupBps;

  @override
  Future<void> merge(int sourceId, int targetId) {
    if (sourceId == targetId) throw ArgumentError('Cannot merge into itself');
    return _db.transaction(() async {
      // Anything shown with the source follows it.
      await (_db.update(_db.accounts)
            ..where((t) => t.mergedIntoId.equals(sourceId)))
          .write(AccountsCompanion(mergedIntoId: Value(targetId)));
      await _patch(sourceId, AccountsCompanion(mergedIntoId: Value(targetId)));
    });
  }

  @override
  Future<void> unmerge(int id) =>
      _patch(id, const AccountsCompanion(mergedIntoId: Value(null)));

  @override
  Future<List<Account>> mergedChildren(int id) async =>
      (await (_db.select(_db.accounts)..where((t) => t.mergedIntoId.equals(id)))
              .get())
          .map(_map)
          .toList();

  // FR-13-12: never deletes or moves rows; only creates accounts.
  @override
  Future<List<OrphanRow>> restoreMissing() => _db.transaction(() async {
        final rows = await _db.customSelect(
          'SELECT id, bank_name, account_last4, account_kind FROM transactions '
          'WHERE account_id IS NULL AND account_last4 IS NOT NULL '
          "AND account_last4 != ''",
          readsFrom: {_db.transactions},
        ).get();
        final out = <OrphanRow>[];
        final cache = <String, int>{};
        for (final r in rows) {
          final bank = r.read<String>('bank_name');
          final last4 = r.read<String>('account_last4');
          final kind = r.read<String>('account_kind');
          final k = '$bank|$last4';
          var id = cache[k];
          if (id == null) {
            final found = await (_db.select(_db.accounts)
                  ..where(
                    (t) => t.bankName.equals(bank) & t.last4.equals(last4),
                  ))
                .getSingleOrNull();
            id = found?.id ??
                await _db.into(_db.accounts).insert(
                      AccountsCompanion.insert(
                        bankName: bank,
                        last4: last4,
                        kind: kind,
                        createdAt: _now(),
                      ),
                    );
            cache[k] = id;
          }
          out.add(OrphanRow(r.read<int>('id'), id));
        }
        return out;
      });
}
