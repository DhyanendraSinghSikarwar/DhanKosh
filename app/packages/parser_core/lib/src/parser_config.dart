/// Settings every parser shares.
class ParserConfig {
  /// Creates a config. Defaults are India Standard Time and 45 days.
  const ParserConfig({
    this.utcOffset = const Duration(hours: 5, minutes: 30),
    this.maxBackdateDays = 45,
  });

  /// Offset of the zone the bank writes its dates in. Indian banks write IST,
  /// which has no daylight saving, so a fixed offset is exact.
  final Duration utcOffset;

  /// A date in the text older than this, relative to the message, is treated
  /// as unrelated.
  final int maxBackdateDays;
}
