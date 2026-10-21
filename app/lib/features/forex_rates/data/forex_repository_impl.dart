import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/forex_sql.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';
import 'package:hisaab/features/forex_rates/domain/forex_repository.dart';

/// [ForexRepository] over `forex_rates`. `inrMinor` upkeep is done by SQL
/// triggers plus [recompute] (schema-level; this class never uses the
/// ledger write API).
class ForexRepositoryImpl implements ForexRepository {
  /// Creates the repository.
  ForexRepositoryImpl(this._db);

  final AppDatabase _db;

  static ForexRate _map(ForexRateRow r) => ForexRate(
        currency: r.currency,
        day: r.day,
        inrPerUnit: r.inrPerUnit,
      );

  SimpleSelectStatement<$ForexRatesTable, ForexRateRow> get _q =>
      _db.select(_db.forexRates)
        ..orderBy([
          (t) => OrderingTerm.asc(t.currency),
          (t) => OrderingTerm.desc(t.day),
        ]);

  @override
  Stream<List<ForexRate>> watchRates() =>
      _q.watch().map((r) => r.map(_map).toList());

  @override
  Future<List<ForexRate>> rates() async => (await _q.get()).map(_map).toList();

  @override
  Future<ForexRate?> rateFor(String currency, int day) async {
    final r = await (_db.select(_db.forexRates)
          ..where((t) => t.currency.equals(currency.toUpperCase()))
          ..orderBy([
            (t) => OrderingTerm.asc(
                  CustomExpression<int>('ABS(day - $day)'),
                ),
            (t) => OrderingTerm.asc(t.day),
          ])
          ..limit(1))
        .getSingleOrNull();
    return r == null ? null : _map(r);
  }

  @override
  Future<ForexRate?> latest(String currency) async {
    final r = await (_db.select(_db.forexRates)
          ..where((t) => t.currency.equals(currency.toUpperCase()))
          ..orderBy([(t) => OrderingTerm.desc(t.day)])
          ..limit(1))
        .getSingleOrNull();
    return r == null ? null : _map(r);
  }

  @override
  Future<void> upsert(ForexRate rate) {
    final c = rate.currency.toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(c) || !(rate.inrPerUnit > 0)) {
      throw ArgumentError('Invalid rate');
    }
    return _db.transaction(() async {
      await _db.into(_db.forexRates).insertOnConflictUpdate(
            ForexRatesCompanion.insert(
              currency: c,
              day: rate.day,
              inrPerUnit: rate.inrPerUnit,
            ),
          );
      await recompute();
    });
  }

  @override
  Future<void> delete(String currency, int day) => _db.transaction(() async {
        await (_db.delete(_db.forexRates)
              ..where(
                (t) =>
                    t.currency.equals(currency.toUpperCase()) &
                    t.day.equals(day),
              ))
            .go();
        await recompute();
      });

  @override
  Future<void> recompute() => _db.transaction(
        () => _db.customUpdate(
          ForexSql.recompute,
          updates: {_db.transactions},
          updateKind: UpdateKind.update,
        ),
      );

  @override
  Stream<List<CurrencyCount>> watchForeign() => _db
      .customSelect(
        'SELECT currency, COUNT(*) AS n, '
        'SUM(CASE WHEN inr_minor IS NULL THEN 1 ELSE 0 END) AS unpriced '
        "FROM transactions WHERE currency != 'INR' "
        'GROUP BY currency ORDER BY n DESC, currency',
        readsFrom: {_db.transactions},
      )
      .watch()
      .map(
        (rows) => [
          for (final r in rows)
            CurrencyCount(
              currency: r.read<String>('currency'),
              count: r.read<int>('n'),
              unpriced: r.read<int>('unpriced'),
            ),
        ],
      );
}
