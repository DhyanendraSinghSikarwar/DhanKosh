import 'package:hisaab/features/portfolio/domain/holding.dart';

/// Figures of an existing holding after [snapshot] is merged (FR-16-09).
class HoldingUpdate {
  /// Creates an update.
  const HoldingUpdate({
    required this.identifier,
    required this.figuresChanged,
    this.valueMinor,
    this.investedMinor,
    this.units,
    this.asOf,
    this.note,
    this.previousValueMinor,
    this.previousAsOf,
    this.source,
  });

  final String identifier;

  /// False for an older snapshot: only the identifier may improve.
  final bool figuresChanged;
  final int? valueMinor;
  final int? investedMinor;
  final double? units;
  final int? asOf;
  final String? note;
  final int? previousValueMinor;
  final int? previousAsOf;
  final HoldingSource? source;
}

/// Pure merge rule of `HoldingRepository.record` (memory 16 section 3.11,
/// steps 4 to 6). [id] is the identifier chosen by `preferredId`.
HoldingUpdate mergeSnapshot(
  Holding existing,
  HoldingSnapshot s,
  HoldingSource source, {
  required String id,
}) {
  final exAsOf = existing.asOf ?? 0;
  if (exAsOf > s.asOf) {
    return HoldingUpdate(identifier: id, figuresChanged: false);
  }
  final newer = exAsOf < s.asOf;
  final moved =
      s.valueMinor != null && s.valueMinor != existing.valueMinor && newer;
  final contribution = newer ? s.contributionMinor : null;
  final invested = s.investedMinor ??
      (contribution == null
          ? existing.investedMinor
          : (existing.investedMinor ?? 0) + contribution);
  return HoldingUpdate(
    identifier: id,
    figuresChanged: true,
    valueMinor: s.valueMinor ?? existing.valueMinor,
    investedMinor: invested,
    units: s.units ?? existing.units,
    asOf: s.asOf,
    source: source,
    note: existing.source == HoldingSource.manual
        ? existing.note
        : (s.platform ?? existing.note),
    previousValueMinor: moved ? existing.valueMinor : existing.previousValueMinor,
    previousAsOf: moved ? existing.asOf : existing.previousAsOf,
  );
}
