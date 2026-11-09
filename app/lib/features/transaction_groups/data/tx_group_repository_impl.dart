import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/transaction_groups/domain/tx_group.dart';

/// [TxGroupRepository] over `tx_groups` and `tx_group_members` (FR-39-01).
class TxGroupRepositoryImpl implements TxGroupRepository {
  /// Creates the repository; [now] is epoch ms.
  TxGroupRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  @override
  Stream<List<TxGroup>> watchAll() => _db
      .customSelect(
        'SELECT g.id AS id, g.name AS name, '
        'COUNT(t.id) AS n, '
        "COALESCE(SUM(CASE WHEN t.type = 'DEBIT' AND t.category <> 'TRANSFER' "
        'AND t.needs_review = 0 AND t.excluded = 0 '
        'THEN COALESCE(t.inr_minor, 0) END), 0) AS spent, '
        "COALESCE(SUM(CASE WHEN t.type = 'CREDIT' AND t.category <> 'TRANSFER' "
        'AND t.needs_review = 0 AND t.excluded = 0 '
        'THEN COALESCE(t.inr_minor, 0) END), 0) AS income '
        'FROM tx_groups g '
        'LEFT JOIN tx_group_members m ON m.group_id = g.id '
        'LEFT JOIN transactions t ON t.id = m.transaction_id '
        'GROUP BY g.id ORDER BY g.created_at DESC, g.id DESC',
        readsFrom: {_db.txGroups, _db.txGroupMembers, _db.transactions},
      )
      .watch()
      .map(
        (rows) => [
          for (final r in rows)
            TxGroup(
              id: r.read<int>('id'),
              name: r.read<String>('name'),
              count: r.read<int>('n'),
              spentMinor: r.read<int>('spent'),
              incomeMinor: r.read<int>('income'),
            ),
        ],
      );

  @override
  Future<int> create(String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Name required');
    return _db.into(_db.txGroups).insert(
          TxGroupsCompanion.insert(name: n, createdAt: _now()),
        );
  }

  @override
  Future<void> rename(int id, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await (_db.update(_db.txGroups)..where((t) => t.id.equals(id)))
        .write(TxGroupsCompanion(name: Value(n)));
  }

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.txGroups)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> add(int groupId, List<int> txIds) async {
    for (final id in txIds) {
      await _db.into(_db.txGroupMembers).insert(
            TxGroupMembersCompanion.insert(groupId: groupId, transactionId: id),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  @override
  Future<void> remove(int groupId, int txId) => (_db.delete(_db.txGroupMembers)
        ..where(
          (t) => t.groupId.equals(groupId) & t.transactionId.equals(txId),
        ))
      .go();

  @override
  Future<Set<int>> groupIdsOf(int txId) async => {
        for (final r in await (_db.select(_db.txGroupMembers)
              ..where((t) => t.transactionId.equals(txId)))
            .get())
          r.groupId,
      };

  @override
  Future<void> setGroupsOf(int txId, Set<int> groupIds) async {
    await _db.transaction(() async {
      await (_db.delete(_db.txGroupMembers)
            ..where((t) => t.transactionId.equals(txId)))
          .go();
      for (final g in groupIds) {
        await add(g, [txId]);
      }
    });
  }
}
