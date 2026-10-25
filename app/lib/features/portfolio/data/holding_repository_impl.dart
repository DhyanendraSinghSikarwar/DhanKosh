import 'dart:math';

import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/holding_match.dart';
import 'package:hisaab/features/portfolio/domain/holding_merge.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';

/// [HoldingRepository] over the `holdings` table (FR-16-09, FR-16-18).
class HoldingRepositoryImpl implements HoldingRepository {
  /// Creates the repository. [now] is epoch ms.
  HoldingRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  static Holding _map(HoldingRow r) => Holding(
        id: r.id,
        kind: enumFromDb(HoldingKind.values, r.kind, HoldingKind.other),
        name: r.name,
        identifier: r.identifier,
        source:
            enumFromDb(HoldingSource.values, r.source, HoldingSource.manual),
        updatedAt: r.updatedAt,
        units: r.units,
        valueMinor: r.valueMinor,
        investedMinor: r.investedMinor,
        asOf: r.asOf,
        note: r.note,
        previousValueMinor: r.previousValueMinor,
        previousAsOf: r.previousAsOf,
      );

  static HoldingKey _key(Holding h) => HoldingKey(h.kind, h.identifier, h.name);

  Future<List<Holding>> _all() async =>
      (await _db.select(_db.holdings).get()).map(_map).toList();

  @override
  Future<int> record(
    List<HoldingSnapshot> snapshots,
    HoldingSource source,
  ) async {
    var changed = 0;
    await _db.transaction(() async {
      final touched = <int>{};
      for (final s in snapshots) {
        final all = await _all();
        if (HoldingMatch.isAggregate(s.identifier) &&
            HoldingMatch.aggregatesCovered(all.map(_key))
                .contains(HoldingMatch.aggregateClass(s.identifier))) {
          continue;
        }
        final sKey = HoldingKey(s.kind, s.identifier, s.name);
        var existing =
            all.where((h) => h.identifier == s.identifier).firstOrNull;
        if (existing == null) {
          final cands = all
              .where((h) => !touched.contains(h.id) && !h.isManual)
              .toList()
            ..sort((a, b) => (b.asOf ?? 0).compareTo(a.asOf ?? 0));
          existing =
              cands.where((h) => HoldingMatch.same(_key(h), sKey)).firstOrNull;
        }
        if (existing == null) {
          final id = await _db.into(_db.holdings).insert(
                HoldingsCompanion.insert(
                  kind: enumToDb(s.kind),
                  name: s.name,
                  identifier: HoldingMatch.normalisedId(s.identifier),
                  units: Value(s.units),
                  valueMinor: Value(s.valueMinor),
                  investedMinor: Value(s.investedMinor),
                  asOf: Value(s.asOf),
                  source: enumToDb(source),
                  note: Value(s.platform),
                  updatedAt: _now(),
                ),
              );
          touched.add(id);
          changed++;
          continue;
        }
        var id = HoldingMatch.preferredId(existing.identifier, s.identifier);
        if (id != existing.identifier && all.any((h) => h.identifier == id)) {
          id = existing.identifier;
        }
        final u = mergeSnapshot(existing, s, source, id: id);
        await (_db.update(_db.holdings)
              ..where((t) => t.id.equals(existing!.id)))
            .write(
          HoldingsCompanion(
            identifier: Value(u.identifier),
            valueMinor:
                u.figuresChanged ? Value(u.valueMinor) : const Value.absent(),
            investedMinor: u.figuresChanged
                ? Value(u.investedMinor)
                : const Value.absent(),
            units: u.figuresChanged ? Value(u.units) : const Value.absent(),
            asOf: u.figuresChanged ? Value(u.asOf) : const Value.absent(),
            source: u.figuresChanged
                ? Value(enumToDb(u.source!))
                : const Value.absent(),
            note: u.figuresChanged ? Value(u.note) : const Value.absent(),
            previousValueMinor: u.figuresChanged
                ? Value(u.previousValueMinor)
                : const Value.absent(),
            previousAsOf:
                u.figuresChanged ? Value(u.previousAsOf) : const Value.absent(),
            updatedAt: Value(_now()),
          ),
        );
        touched.add(existing.id);
        changed++;
      }
      await dedupe();
    });
    return changed;
  }

  static const _claimsKey = 'holding_claims';
  static const _claimsCap = 500;

  /// True when none of [keys] was claimed; then claims them all (FR-16-21).
  /// Runs inside the caller's transaction.
  Future<bool> _claim(List<String> keys) async {
    final row = await (_db.select(_db.settings)
          ..where((t) => t.key.equals(_claimsKey)))
        .getSingleOrNull();
    final set =
        row == null || row.value.isEmpty ? <String>[] : row.value.split('\n');
    if (keys.any(set.contains)) return false;
    set.addAll(keys);
    final kept =
        set.length > _claimsCap ? set.sublist(set.length - _claimsCap) : set;
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: _claimsKey, value: kept.join('\n')),
        );
    return true;
  }

  @override
  Future<bool> recordMfOrder(
    MfOrderEntry o, {
    required String claimKey,
  }) =>
      _db.transaction(() async {
        final day = o.at ~/ 86400000;
        final ok = await _claim([
          'mfmsg|$claimKey',
          'mf|${o.identifier}|$day|${o.amountMinor}|${o.units}',
        ]);
        if (!ok) return false;
        final all = await _all();
        final key =
            HoldingKey(HoldingKind.mutualFund, o.identifier, o.schemeName);
        final existing = all
                .where((h) => h.identifier == o.identifier)
                .firstOrNull ??
            all
                .where((h) => !h.isManual && HoldingMatch.same(_key(h), key))
                .firstOrNull;
        final amount = o.amountMinor ?? 0;
        final note = [
          if (o.platform != null) o.platform!,
          if (o.folio != null) 'folio ${o.folio}',
        ].join(' · ');
        if (existing == null) {
          final value = o.units != null && o.nav != null
              ? (o.units! * o.nav! * 100).round()
              : o.amountMinor;
          await _db.into(_db.holdings).insert(
                HoldingsCompanion.insert(
                  kind: enumToDb(HoldingKind.mutualFund),
                  name: o.schemeName,
                  identifier: o.identifier,
                  units: Value(o.units),
                  valueMinor: Value(value),
                  investedMinor: Value(o.amountMinor),
                  asOf: Value(o.at),
                  source: enumToDb(HoldingSource.email),
                  note: Value(note.isEmpty ? null : note),
                  updatedAt: _now(),
                ),
              );
          return true;
        }
        if (existing.source == HoldingSource.statement &&
            (existing.asOf ?? 0) >= o.at) {
          return false;
        }
        final units =
            o.units != null ? (existing.units ?? 0) + o.units! : existing.units;
        final int value;
        if (units != null &&
            o.nav != null &&
            (existing.units != null || existing.valueMinor == null)) {
          value = (units * o.nav! * 100).round();
        } else {
          value = (existing.valueMinor ?? 0) + amount;
        }
        // A statement that gave value but not cost: one purchase is not the
        // total invested, so it stays unknown.
        final invested = existing.investedMinor != null
            ? existing.investedMinor! + amount
            : (existing.valueMinor == null ||
                    existing.source == HoldingSource.email)
                ? o.amountMinor
                : null;
        await (_db.update(_db.holdings)..where((t) => t.id.equals(existing.id)))
            .write(
          HoldingsCompanion(
            units: Value(units),
            valueMinor: Value(value),
            investedMinor: Value(invested),
            asOf: Value(max(existing.asOf ?? 0, o.at)),
            source: Value(
              enumToDb(
                existing.isManual ? existing.source : HoldingSource.email,
              ),
            ),
            updatedAt: Value(_now()),
            previousValueMinor: Value(existing.valueMinor),
            previousAsOf: Value(existing.asOf),
          ),
        );
        return true;
      });

  @override
  Future<bool> recordNpsContribution(NpsContributionEntry c) =>
      _db.transaction(() async {
        if (!await _claim([c.key])) return false;
        final existing = (await _all())
            .where((h) => h.identifier == c.identifier)
            .firstOrNull;
        if (existing == null) {
          await _db.into(_db.holdings).insert(
                HoldingsCompanion.insert(
                  kind: enumToDb(HoldingKind.nps),
                  name: c.name,
                  identifier: c.identifier,
                  valueMinor: Value(c.amountMinor),
                  investedMinor: Value(c.amountMinor),
                  asOf: Value(c.at),
                  source: enumToDb(HoldingSource.sms),
                  updatedAt: _now(),
                ),
              );
          return true;
        }
        if (existing.source == HoldingSource.statement &&
            (existing.asOf ?? 0) >= c.at) {
          return false;
        }
        final newer = c.at > (existing.asOf ?? 0);
        await (_db.update(_db.holdings)..where((t) => t.id.equals(existing.id)))
            .write(
          HoldingsCompanion(
            investedMinor: Value(
              existing.investedMinor != null
                  ? existing.investedMinor! + c.amountMinor
                  : existing.valueMinor == null
                      ? c.amountMinor
                      : null,
            ),
            valueMinor: newer
                ? Value((existing.valueMinor ?? 0) + c.amountMinor)
                : const Value.absent(),
            asOf: newer ? Value(c.at) : const Value.absent(),
            source: newer && !existing.isManual
                ? Value(enumToDb(HoldingSource.sms))
                : const Value.absent(),
            previousValueMinor:
                newer ? Value(existing.valueMinor) : const Value.absent(),
            previousAsOf: newer ? Value(existing.asOf) : const Value.absent(),
            updatedAt: Value(_now()),
          ),
        );
        return true;
      });

  @override
  Future<int> dedupe() => _db.transaction(() async {
        var removed = 0;
        final all = (await _all()).where((h) => !h.isManual).toList();
        for (final g in HoldingMatch.duplicates(all, _key)) {
          final keep = g.reduce((a, b) {
            final as = a.source == HoldingSource.statement;
            final bs = b.source == HoldingSource.statement;
            if (as != bs) return as ? a : b;
            return (a.asOf ?? 0) >= (b.asOf ?? 0) ? a : b;
          });
          final rest = g.where((h) => h.id != keep.id).toList();
          for (final h in rest) {
            await delete(h.id);
            removed++;
          }
          var pref = g.first.identifier;
          for (final h in g.skip(1)) {
            pref = HoldingMatch.preferredId(pref, h.identifier);
          }
          if (pref != keep.identifier) {
            await (_db.update(_db.holdings)..where((t) => t.id.equals(keep.id)))
                .write(HoldingsCompanion(identifier: Value(pref)));
          }
        }
        final rows = await _all();
        final covered = HoldingMatch.aggregatesCovered(rows.map(_key));
        for (final h in rows) {
          if (HoldingMatch.isAggregate(h.identifier) &&
              covered.contains(HoldingMatch.aggregateClass(h.identifier))) {
            await delete(h.id);
            removed++;
          }
        }
        return removed;
      });

  static String _uuid() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  Future<int> addManual({
    required HoldingKind kind,
    required String name,
    required int valueMinor,
    required int at,
    int? investedMinor,
    double? units,
  }) =>
      _db.into(_db.holdings).insert(
            HoldingsCompanion.insert(
              kind: enumToDb(kind),
              name: name,
              identifier: 'manual:${_uuid()}',
              units: Value(units),
              valueMinor: Value(valueMinor),
              investedMinor: Value(investedMinor),
              asOf: Value(at),
              source: enumToDb(HoldingSource.manual),
              updatedAt: _now(),
            ),
          );

  @override
  Future<void> edit(
    int id, {
    required HoldingKind kind,
    required String name,
    required int valueMinor,
    required int at,
    int? investedMinor,
    double? units,
  }) async {
    final old = await byId(id);
    if (old == null) return;
    final moved = old.valueMinor != valueMinor;
    await (_db.update(_db.holdings)..where((t) => t.id.equals(id))).write(
      HoldingsCompanion(
        kind: Value(enumToDb(kind)),
        name: Value(name),
        valueMinor: Value(valueMinor),
        investedMinor: Value(investedMinor),
        units: Value(units),
        asOf: Value(at),
        updatedAt: Value(_now()),
        previousValueMinor:
            moved ? Value(old.valueMinor) : const Value.absent(),
        previousAsOf: moved ? Value(old.asOf) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.holdings)..where((t) => t.id.equals(id))).go();

  @override
  Future<Holding?> byId(int id) async {
    final r = await (_db.select(_db.holdings)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _map(r);
  }

  static int _byValue(Holding a, Holding b) =>
      (b.valueMinor ?? 0).compareTo(a.valueMinor ?? 0);

  @override
  Future<List<Holding>> list() async => (await _all())..sort(_byValue);

  @override
  Stream<List<Holding>> watch() => _db
      .select(_db.holdings)
      .watch()
      .map((rows) => rows.map(_map).toList()..sort(_byValue));
}
