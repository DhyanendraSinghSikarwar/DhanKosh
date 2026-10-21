import 'package:hisaab/features/portfolio/domain/asset_class.dart';

/// A stored holding (FR-16-09). Units are not money, so they are a double;
/// every amount is in paise.
class Holding {
  /// Creates a holding.
  const Holding({
    required this.id,
    required this.kind,
    required this.name,
    required this.identifier,
    required this.source,
    required this.updatedAt,
    this.units,
    this.valueMinor,
    this.investedMinor,
    this.asOf,
    this.note,
    this.previousValueMinor,
    this.previousAsOf,
  });

  final int id;
  final HoldingKind kind;
  final String name;
  final String identifier;
  final HoldingSource source;

  /// Epoch ms.
  final int updatedAt;
  final double? units;
  final int? valueMinor;
  final int? investedMinor;

  /// Epoch ms of the figures (noon IST for statements).
  final int? asOf;
  final String? note;
  final int? previousValueMinor;
  final int? previousAsOf;

  /// Asset class of [kind].
  AssetClass get assetClass => assetClassOf(kind);

  /// Manual rows are never touched by matching.
  bool get isManual => source == HoldingSource.manual || identifier.startsWith('manual:');

  /// Value minus invested, only when a cost is known (FR-16-02).
  int? get gainMinor {
    final i = investedMinor;
    final v = valueMinor;
    return (i != null && i > 0 && v != null) ? v - i : null;
  }

  /// Gain over invested, in percent.
  double? get returnPct {
    final g = gainMinor;
    final i = investedMinor;
    return g == null || i == null ? null : g / i * 100;
  }
}

/// One incoming figure for [HoldingRepository.record] (a parsed holding).
class HoldingSnapshot {
  /// Creates a snapshot.
  const HoldingSnapshot({
    required this.kind,
    required this.name,
    required this.identifier,
    required this.asOf,
    this.units,
    this.valueMinor,
    this.investedMinor,
    this.contributionMinor,
    this.platform,
  });

  final HoldingKind kind;
  final String name;
  final String identifier;

  /// Epoch ms.
  final int asOf;
  final double? units;
  final int? valueMinor;
  final int? investedMinor;

  /// Month's contribution (EPFO SMS): added to invested when newer.
  final int? contributionMinor;

  /// Becomes the holding note.
  final String? platform;
}
