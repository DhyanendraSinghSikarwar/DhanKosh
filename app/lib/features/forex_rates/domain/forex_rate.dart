/// A user rate: rupees for one unit of [currency] on an IST epoch [day]
/// (FR-23-01).
class ForexRate {
  /// Creates a rate.
  const ForexRate({
    required this.currency,
    required this.day,
    required this.inrPerUnit,
  });

  /// Upper-case 3-letter code.
  final String currency;
  final int day;
  final double inrPerUnit;
}

/// Foreign spend count per currency (FR-23-02, FR-23-09).
class CurrencyCount {
  /// Creates a count.
  const CurrencyCount({
    required this.currency,
    required this.count,
    required this.unpriced,
  });

  final String currency;
  final int count;

  /// Rows without `inrMinor`.
  final int unpriced;
}

/// Rate dialog state (FR-23-03).
class RateDraft {
  /// Creates a draft.
  const RateDraft({
    required this.currency,
    required this.day,
    this.rateText = '',
  });

  final String currency;
  final DateTime day;
  final String rateText;

  /// Positive rate or null.
  double? get rate {
    final v = double.tryParse(rateText);
    return v != null && v > 0 ? v : null;
  }

  /// Save enabled for a 3-letter code and a positive rate.
  bool get canSave => currency.length == 3 && rate != null;
}
