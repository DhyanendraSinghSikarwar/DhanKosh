/// What a holding is (parity with the Kotlin `HoldingKind`).
enum HoldingKind {
  epf('EPF'),
  mutualFund('Mutual fund'),
  stock('Stock'),
  etf('ETF'),
  nps('NPS'),
  ppf('PPF'),
  bond('Bond'),
  gold('Gold'),
  fd('Fixed deposit'),
  other('Other');

  const HoldingKind(this.label);

  /// Display name.
  final String label;
}

/// A holding's value at one moment, read from an SMS (EPFO), an email or a
/// statement (CAS, broker sheet). [identifier] is stable across statements (an
/// ISIN, `EPF:<member>`, `NPS:<last4>`), so a newer snapshot replaces an older
/// one.
///
/// Money is paise. [units] is a fund or share quantity, the only place a
/// `double` is used (FR-05-14).
class HoldingSnapshot {
  /// Creates a snapshot.
  const HoldingSnapshot({
    required this.kind,
    required this.name,
    required this.identifier,
    required this.units,
    required this.valueMinor,
    required this.investedMinor,
    required this.asOf,
    this.contributionMinor,
    this.platform,
  });

  /// Kind of holding.
  final HoldingKind kind;

  /// Display name.
  final String name;

  /// Stable key: ISIN, `EPF:<member>`, `NPS:<last4>[:T2]`, `MF:<scheme>`,
  /// `STOCK:<name>`, `US:<ticker>` or `AGG:INDMONEY:<class>`.
  final String identifier;

  /// Units or shares held.
  final double? units;

  /// Current value, paise.
  final int? valueMinor;

  /// Amount invested, paise.
  final int? investedMinor;

  /// When the figures were true, epoch ms.
  final int asOf;

  /// A contribution the message reports on top of the value (EPFO: "Contribution
  /// of Rs. 12,345 ... received"); adds to the amount invested when
  /// [investedMinor] is not stated.
  final int? contributionMinor;

  /// The app or broker the figures came from (Groww, Zerodha ...).
  final String? platform;

  /// A copy with [units], [valueMinor] and [investedMinor] replaced; the
  /// arguments are the new values, null included.
  HoldingSnapshot withFigures({
    required double? units,
    required int? valueMinor,
    required int? investedMinor,
  }) =>
      HoldingSnapshot(
        kind: kind,
        name: name,
        identifier: identifier,
        units: units,
        valueMinor: valueMinor,
        investedMinor: investedMinor,
        asOf: asOf,
        contributionMinor: contributionMinor,
        platform: platform,
      );

  /// A copy with [platform] set (null clears it).
  HoldingSnapshot withPlatform(String? platform) => HoldingSnapshot(
        kind: kind,
        name: name,
        identifier: identifier,
        units: units,
        valueMinor: valueMinor,
        investedMinor: investedMinor,
        asOf: asOf,
        contributionMinor: contributionMinor,
        platform: platform,
      );

  @override
  bool operator ==(Object other) =>
      other is HoldingSnapshot &&
      other.kind == kind &&
      other.name == name &&
      other.identifier == identifier &&
      other.units == units &&
      other.valueMinor == valueMinor &&
      other.investedMinor == investedMinor &&
      other.asOf == asOf &&
      other.contributionMinor == contributionMinor &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(
        kind,
        name,
        identifier,
        units,
        valueMinor,
        investedMinor,
        asOf,
        contributionMinor,
        platform,
      );

  @override
  String toString() =>
      'HoldingSnapshot($kind $identifier $name units=$units value=$valueMinor '
      'invested=$investedMinor)';
}
