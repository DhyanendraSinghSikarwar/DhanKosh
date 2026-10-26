import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';

/// [SipRepository] over the `sips` table.
class SipRepositoryImpl implements SipRepository {
  /// Creates the repository; [now] is epoch ms.
  SipRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  static SipItem _map(SipRow r) => SipItem(
        id: r.id,
        name: r.name,
        amountMinor: r.amountMinor,
        frequency:
            enumFromDb(SipFrequency.values, r.frequency, SipFrequency.monthly),
        dayOfMonth: r.dayOfMonth,
        weekday: r.weekday,
        startDay: r.startDay,
        createdAt: r.createdAt,
      );

  SipsCompanion _companion(SipDraft d) => SipsCompanion(
        name: Value(d.name.trim()),
        amountMinor: Value(d.amountMinor),
        frequency: Value(enumToDb(d.frequency)),
        dayOfMonth:
            Value(d.frequency == SipFrequency.monthly ? d.dayOfMonth : null),
        weekday: Value(d.frequency == SipFrequency.weekly ? d.weekday : null),
        startDay: Value(d.startDay),
      );

  void _check(SipDraft d) {
    final e = d.validate();
    if (e != null) throw ArgumentError(e);
  }

  @override
  Stream<List<SipItem>> watchAll() =>
      (_db.select(_db.sips)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch()
          .map((r) => r.map(_map).toList());

  @override
  Future<int> add(SipDraft draft) async {
    _check(draft);
    final id = await _db.into(_db.sips).insert(
          _companion(draft).copyWith(createdAt: Value(_now())),
        );
    return id;
  }

  @override
  Future<void> update(int id, SipDraft draft) async {
    _check(draft);
    await (_db.update(_db.sips)..where((t) => t.id.equals(id)))
        .write(_companion(draft));
  }

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.sips)..where((t) => t.id.equals(id))).go();
}
