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

  /// Adds a mutual fund purchase to its holding (FR-16-19). Returns false when
  /// [claimKey] or the order itself was applied before, or a statement dated
  /// on or after the order already counts it.
  Future<bool> recordMfOrder(MfOrderEntry order, {required String claimKey});

  /// Restores recorded fund purchases from a backup without touching
  /// holdings (they are restored separately). Skips orders already stored and
  /// claims their dedup keys so later mail or SMS does not count them again.
  /// Returns the number inserted.
  Future<int> restoreMfOrders(List<MfOrderEntry> orders);

  /// Adds an NPS contribution to its tier's holding (FR-16-20, FR-16-21).
  /// Returns false when the contribution was applied before or a statement
  /// dated on or after it already counts it.
  Future<bool> recordNpsContribution(NpsContributionEntry c);

  /// Merges duplicates (keeps the statement copy, else the newest) and drops
  /// aggregates covered by itemised rows (FR-16-18). Returns rows removed.
  Future<int> dedupe();

  /// Adds a MANUAL holding with id `manual:<uuid>` (FR-16-08).
  Future<int> addManual({
    required HoldingKind kind,
    required String name,
    required int valueMinor,
    required int at,
    int? investedMinor,
    double? units,
  });

  /// Edits a holding's name, kind, value, invested and units (FR-16-08).
  /// Editing marks the figures as of [at].
  Future<void> edit(
    int id, {
    required HoldingKind kind,
    required String name,
    required int valueMinor,
    required int at,
    int? investedMinor,
    double? units,
  });

  /// Removes a holding.
  Future<void> delete(int id);

  /// Holding by id.
  Future<Holding?> byId(int id);

  /// All holdings, largest value first.
  Future<List<Holding>> list();

  /// Stream of [list].
  Stream<List<Holding>> watch();

  /// Recorded fund purchases, newest first (FR-16-22).
  Stream<List<MfOrderEntry>> watchMfOrders();

  /// Sets holding [id]'s value from a NAV dated [asOf] (epoch ms), keeping
  /// the old figures as previous (FR-16-24). False for manual rows and when
  /// the holding's figures are as new or newer.
  Future<bool> applyNav(int id, {required int valueMinor, required int asOf});
}

/// A mutual fund purchase (SIP instalment or lump sum) from a mail or SMS.
class MfOrderEntry {
  /// Creates an order.
  const MfOrderEntry({
    required this.schemeName,
    required this.identifier,
    required this.at,
    this.platform,
    this.folio,
    this.amountMinor,
    this.units,
    this.nav,
  });

  final String schemeName;

  /// `MF:` + normalised scheme name.
  final String identifier;

  /// Epoch ms of the order.
  final int at;
  final String? platform;
  final String? folio;
  final int? amountMinor;
  final double? units;

  /// Rupees per unit (a price, not an amount).
  final double? nav;
}

/// An NPS contribution credited to a PRAN tier.
class NpsContributionEntry {
  /// Creates a contribution.
  const NpsContributionEntry({
    required this.identifier,
    required this.name,
    required this.amountMinor,
    required this.at,
    required this.key,
  });

  /// `NPS:1234` or `NPS:1234:T2`.
  final String identifier;
  final String name;
  final int amountMinor;

  /// Epoch ms.
  final int at;

  /// Stable key: the same contribution by SMS and mail counts once.
  final String key;
}
