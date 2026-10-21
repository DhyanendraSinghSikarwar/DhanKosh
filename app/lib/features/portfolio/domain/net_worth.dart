import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';

/// Which book net worth is shown for (FR-16-16).
enum Book { all, personal, business }

/// One slice of the breakdown bar (FR-16-06).
class WorthPart {
  /// Creates a part.
  const WorthPart({
    required this.key,
    required this.label,
    required this.amountMinor,
    required this.liability,
    required this.kind,
    this.assetClass,
  });

  final String key;
  final String label;
  final int amountMinor;
  final bool liability;
  final PartKind kind;
  final AssetClass? assetClass;
}

/// Net worth now.
class NetWorth {
  /// Creates a net worth.
  const NetWorth({
    required this.assetsMinor,
    required this.liabilitiesMinor,
    required this.parts,
    required this.cards,
  });

  final int assetsMinor;
  final int liabilitiesMinor;
  final List<WorthPart> parts;

  /// Card headroom, listed but not counted.
  final List<CardLimit> cards;

  /// Assets minus liabilities.
  int get netMinor => assetsMinor - liabilitiesMinor;
}

/// A recorded history point (FR-16-05).
class WorthPoint {
  /// Creates a point.
  const WorthPoint(this.day, this.assetsMinor, this.liabilitiesMinor);

  /// Epoch day.
  final int day;
  final int assetsMinor;
  final int liabilitiesMinor;

  /// Assets minus liabilities.
  int get netMinor => assetsMinor - liabilitiesMinor;
}

/// What the user left out of net worth (FR-16-14).
class NetWorthFilter {
  /// Creates a filter; the default counts everything.
  const NetWorthFilter({
    this.excludedClasses = const {},
    this.excludedLiabilities = const {},
    this.excludedAccountIds = const {},
  });

  final Set<AssetClass> excludedClasses;
  final Set<LiabilityKind> excludedLiabilities;
  final Set<int> excludedAccountIds;

  /// Nothing excluded.
  bool get isDefault =>
      excludedClasses.isEmpty &&
      excludedLiabilities.isEmpty &&
      excludedAccountIds.isEmpty;
}
