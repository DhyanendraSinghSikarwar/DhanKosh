import 'dart:async';

import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/compute_net_worth.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_repository.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// [NetWorthRepository] over `net_worth_points` (FR-16-05).
class NetWorthRepositoryImpl implements NetWorthRepository {
  /// Creates the repository.
  NetWorthRepositoryImpl(this._db);

  final AppDatabase _db;

  /// Points kept.
  static const maxPoints = 1100;

  static WorthPoint _map(NetWorthPointRow r) =>
      WorthPoint(r.day, r.assetsMinor, r.liabilitiesMinor);

  SimpleSelectStatement<$NetWorthPointsTable, NetWorthPointRow> _q(
    int? since,
  ) =>
      _db.select(_db.netWorthPoints)
        ..where(
          (t) => since == null
              ? const Constant(true)
              : t.day.isBiggerOrEqualValue(since),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.day)]);

  @override
  Future<bool> recordPoint(int day, int assetsMinor, int liabilitiesMinor) =>
      _db.transaction(() async {
        final today = await (_db.select(_db.netWorthPoints)
              ..where((t) => t.day.equals(day)))
            .getSingleOrNull();
        if (!shouldRecordWorth(
          assetsMinor: assetsMinor,
          liabilitiesMinor: liabilitiesMinor,
          today: today == null ? null : _map(today),
        )) {
          return false;
        }
        await _db.into(_db.netWorthPoints).insertOnConflictUpdate(
              NetWorthPointsCompanion.insert(
                day: Value(day),
                assetsMinor: assetsMinor,
                liabilitiesMinor: liabilitiesMinor,
              ),
            );
        await _db.customUpdate(
          'DELETE FROM net_worth_points WHERE day NOT IN '
          '(SELECT day FROM net_worth_points ORDER BY day DESC LIMIT $maxPoints)',
          updates: {_db.netWorthPoints},
          updateKind: UpdateKind.delete,
        );
        return true;
      });

  @override
  Stream<List<WorthPoint>> watchPoints({int? sinceDay}) =>
      _q(sinceDay).watch().map((r) => r.map(_map).toList());

  @override
  Future<List<WorthPoint>> points({int? sinceDay}) async =>
      (await _q(sinceDay).get()).map(_map).toList();
}

/// [NetWorthPrefsRepository] over settings keys (FR-16-14).
class NetWorthPrefsRepositoryImpl implements NetWorthPrefsRepository {
  /// Creates the repository.
  const NetWorthPrefsRepositoryImpl(this._settings);

  final SettingsRepository _settings;

  static const _classes =
      SettingKey<Set<String>>('nw_excluded_classes', <String>{});
  static const _liabs =
      SettingKey<Set<String>>('nw_excluded_liabilities', <String>{});
  static const _accts =
      SettingKey<Set<String>>('nw_excluded_accounts', <String>{});

  static NetWorthFilter _filter(Set<String> c, Set<String> l, Set<String> a) =>
      NetWorthFilter(
        excludedClasses: {
          for (final v in AssetClass.values)
            if (c.contains(v.name)) v,
        },
        excludedLiabilities: {
          for (final v in LiabilityKind.values)
            if (l.contains(v.name)) v,
        },
        excludedAccountIds: {
          for (final s in a)
            if (int.tryParse(s) != null) int.parse(s),
        },
      );

  @override
  Future<NetWorthFilter> read() async => _filter(
        await _settings.read(_classes),
        await _settings.read(_liabs),
        await _settings.read(_accts),
      );

  @override
  Stream<NetWorthFilter> watch() async* {
    yield await read();
    // Any key change re-reads all three.
    final merged = _merge([
      _settings.watch(_classes),
      _settings.watch(_liabs),
      _settings.watch(_accts),
    ]);
    await for (final _ in merged) {
      yield await read();
    }
  }

  static Stream<void> _merge(List<Stream<Object?>> ss) async* {
    // Simple fan-in: iterate streams concurrently through a queue.
    final c = StreamController<void>();
    final subs = [for (final s in ss) s.skip(1).listen((_) => c.add(null))];
    try {
      yield* c.stream;
    } finally {
      for (final s in subs) {
        await s.cancel();
      }
      await c.close();
    }
  }

  @override
  Future<void> save(NetWorthFilter f) async {
    await _settings
        .write(_classes, {for (final c in f.excludedClasses) c.name});
    await _settings
        .write(_liabs, {for (final l in f.excludedLiabilities) l.name});
    await _settings.write(_accts, {for (final a in f.excludedAccountIds) '$a'});
  }
}
