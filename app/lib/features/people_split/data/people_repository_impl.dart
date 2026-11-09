import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/people_split/domain/people.dart';

/// [PeopleRepository] over `people` and `person_entries` (FR-40-01).
class PeopleRepositoryImpl implements PeopleRepository {
  /// Creates the repository; [now] is epoch ms.
  PeopleRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  static const _sql = 'SELECT p.id AS id, p.name AS name, '
      'COALESCE(SUM(e.amount_minor), 0) AS bal, COUNT(e.id) AS n '
      'FROM people p LEFT JOIN person_entries e ON e.person_id = p.id '
      'GROUP BY p.id ORDER BY LOWER(p.name)';

  Person _row(QueryRow r) => Person(
        id: r.read<int>('id'),
        name: r.read<String>('name'),
        balanceMinor: r.read<int>('bal'),
        entryCount: r.read<int>('n'),
      );

  @override
  Stream<List<Person>> watchAll() => _db
      .customSelect(_sql, readsFrom: {_db.people, _db.personEntries})
      .watch()
      .map((rows) => rows.map(_row).toList());

  @override
  Future<List<Person>> all() async => (await _db
          .customSelect(_sql, readsFrom: {_db.people, _db.personEntries}).get())
      .map(_row)
      .toList();

  @override
  Future<int> addPerson(String name) async {
    var n = name.trim();
    if (n.isEmpty) throw ArgumentError('Name required');
    if (n.length > 40) n = n.substring(0, 40);
    final existing = await (_db.select(_db.people)
          ..where((t) => t.name.lower().equals(n.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = await _db.into(_db.people).insert(
          PeopleCompanion.insert(name: n, createdAt: _now()),
        );
    return id;
  }

  @override
  Future<void> rename(int id, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await (_db.update(_db.people)..where((t) => t.id.equals(id)))
        .write(PeopleCompanion(name: Value(n)));
  }

  @override
  Future<void> deletePerson(int id) =>
      (_db.delete(_db.people)..where((t) => t.id.equals(id))).go();

  @override
  Stream<List<PersonEntry>> watchEntries(int personId) =>
      (_db.select(_db.personEntries)
            ..where((t) => t.personId.equals(personId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                PersonEntry(
                  id: r.id,
                  personId: r.personId,
                  amountMinor: r.amountMinor,
                  note: r.note,
                  transactionId: r.transactionId,
                  createdAt: r.createdAt,
                ),
            ],
          );

  @override
  Future<void> addEntry(
    int personId,
    int amountMinor, {
    String? note,
    int? transactionId,
  }) async {
    if (amountMinor == 0) return;
    await _db.into(_db.personEntries).insert(
          PersonEntriesCompanion.insert(
            personId: personId,
            amountMinor: amountMinor,
            note: Value(note?.trim().isEmpty ?? true ? null : note!.trim()),
            transactionId: Value(transactionId),
            createdAt: _now(),
          ),
        );
  }

  @override
  Future<void> deleteEntry(int id) =>
      (_db.delete(_db.personEntries)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> split({
    required int transactionId,
    required String label,
    required Map<int, int> shares,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.personEntries)
            ..where((t) => t.transactionId.equals(transactionId)))
          .go();
      for (final e in shares.entries) {
        await addEntry(
          e.key,
          e.value,
          note: label,
          transactionId: transactionId,
        );
      }
    });
  }

  @override
  Future<Map<int, int>> sharesOf(int transactionId) async => {
        for (final r in await (_db.select(_db.personEntries)
              ..where((t) => t.transactionId.equals(transactionId)))
            .get())
          r.personId: r.amountMinor,
      };
}
