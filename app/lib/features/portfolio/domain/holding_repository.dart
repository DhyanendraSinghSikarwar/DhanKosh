import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';

/// Holdings store (FR-16-08, FR-16-09, FR-16-18).
abstract interface class HoldingRepository {
  /// Saves [snapshots] into the holdings they are the same investment as,
  /// else inserts them (FR-16-09). Older snapshots never overwrite figures;
  /// MANUAL rows are never matched; rows written by this batch are never
  /// merged with each other. Runs [dedupe] afterwards. Returns the number of
  /// rows inserted or updated.
  Future<int> record(List<HoldingSnapshot> snapshots, HoldingSource source);

  /// Merges duplicates (keeps the statement copy, else the newest) and drops
  /// aggregates covered by itemised rows (FR-16-18). Returns rows removed.
  Future<int> dedupe();

  /// Adds a MANUAL holding with id `manual:<uuid>` (FR-16-08).
  Future<int> addManual({
    required HoldingKind kind,
    required String name,
    required int valueMinor,
    int? investedMinor,
    double? units,
    required int at,
  });

  /// Edits a holding's name, kind, value, invested and units (FR-16-08).
  /// Editing marks the figures as of [at].
  Future<void> edit(
    int id, {
    required HoldingKind kind,
    required String name,
    required int valueMinor,
    int? investedMinor,
    double? units,
    required int at,
  });

  /// Removes a holding.
  Future<void> delete(int id);

  /// Holding by id.
  Future<Holding?> byId(int id);

  /// All holdings, largest value first.
  Future<List<Holding>> list();

  /// Stream of [list].
  Stream<List<Holding>> watch();
}
