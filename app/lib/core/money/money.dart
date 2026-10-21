/// Money in minor units (paise). Never use double for amounts.
class Money implements Comparable<Money> {
  /// Creates an amount of [minor] minor units (paise for INR).
  const Money(this.minor, {this.currency = 'INR'});

  /// Zero rupees.
  static const zero = Money(0);

  /// Amount in minor units (paise).
  final int minor;

  /// ISO 4217 currency code.
  final String currency;

  /// Whether the amount is below zero.
  bool get isNegative => minor < 0;

  /// The absolute value.
  Money abs() => Money(minor.abs(), currency: currency);

  /// Sum; both sides must share a currency.
  Money operator +(Money o) => _same(o, minor + o.minor);

  /// Difference; both sides must share a currency.
  Money operator -(Money o) => _same(o, minor - o.minor);

  /// Negation.
  Money operator -() => Money(-minor, currency: currency);

  Money _same(Money o, int result) {
    if (o.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${o.currency}');
    }
    return Money(result, currency: currency);
  }

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';
}
