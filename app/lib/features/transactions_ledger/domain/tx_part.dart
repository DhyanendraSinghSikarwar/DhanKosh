import 'package:parser_core/parser_core.dart';

/// One part of a payment split by category (FR-41-01). Paise.
class TxPart {
  /// Creates a part.
  const TxPart(this.category, this.amountMinor);

  final Category category;
  final int amountMinor;

  /// Null when [parts] may split [totalMinor]: at least two parts, each above
  /// zero, no category twice, adding up to exactly the total (FR-41-02).
  static String? validate(int totalMinor, List<TxPart> parts) {
    if (parts.length < 2) return 'Split into at least two parts';
    if (parts.any((p) => p.amountMinor <= 0)) {
      return 'Each part needs an amount';
    }
    if (parts.map((p) => p.category).toSet().length != parts.length) {
      return 'Use each category once';
    }
    final sum = parts.fold<int>(0, (a, p) => a + p.amountMinor);
    if (sum != totalMinor) return 'Parts must add up to the total';
    return null;
  }
}
