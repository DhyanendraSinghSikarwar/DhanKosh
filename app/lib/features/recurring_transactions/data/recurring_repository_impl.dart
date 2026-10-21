import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring_repository.dart';
import 'package:parser_core/parser_core.dart';

/// [RecurringRepository] over the `recurring` table.
class RecurringRepositoryImpl implements RecurringRepository {
  /// Creates the repository; [now] is epoch ms.
  RecurringRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  static RecurringItem _map(RecurringRow r) => RecurringItem(
        id: r.id,
        name: r.name,
        amountMinor: r.amountMinor,
        income: r.income,
        frequency: r.frequency == 'YEARLY'
            ? RecurringFrequency.yearly
            : RecurringFrequency.monthly,
        dayOfMonth: r.dayOfMonth,
        month: r.month,
        category: enumFromDb(Category.values, r.category, Category.other),
        accountId: r.accountId,
        createdAt: r.createdAt,
      );

  RecurringItemsCompanion _companion(RecurringDraft d, {int? createdAt}) =>
      RecurringItemsCompanion(
        name: Value(d.name.trim()),
        amountMinor: Value(d.amountMinor),
        income: Value(d.income),
        frequency: Value(enumToDb(d.frequency)),
        dayOfMonth: Value(d.dayOfMonth),
        month: Value(
          d.frequency == RecurringFrequency.yearly ? d.month : null,
        ),
        category: Value(enumToDb(d.category)),
        accountId: Value(d.accountId),
        createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
      );

  SimpleSelectStatement<$RecurringItemsTable, RecurringRow> get _q =>
      _db.select(_db.recurringItems)
        ..orderBy([
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]);

  @override
  Stream<List<RecurringItem>> watchAll() =>
      _q.watch().map((r) => r.map(_map).toList());

  @override
  Future<List<RecurringItem>> all() async =>
      (await _q.get()).map(_map).toList();

  void _check(RecurringDraft d) {
    final e = d.validate();
    if (e != null) throw ArgumentError(e);
  }

  @override
  Future<int> add(RecurringDraft draft) async {
    _check(draft);
    final id = await _db
        .into(_db.recurringItems)
        .insert(_companion(draft, createdAt: _now()));
    return id;
  }

  @override
  Future<void> update(int id, RecurringDraft draft) async {
    _check(draft);
    await (_db.update(_db.recurringItems)..where((t) => t.id.equals(id)))
        .write(_companion(draft));
  }

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.recurringItems)..where((t) => t.id.equals(id))).go();

  @override
  Future<int> countForAccount(int accountId) async {
    final c = _db.recurringItems.id.count();
    final r = await (_db.selectOnly(_db.recurringItems)
          ..addColumns([c])
          ..where(_db.recurringItems.accountId.equals(accountId)))
        .getSingle();
    final n = r.read(c);
    return n ?? 0;
  }
}
