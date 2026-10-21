import 'package:parser_core/src/util/strings.dart';

/// An amount in minor units (paise) and its currency. Decimal text is parsed
/// exactly; no `double` is ever involved (FR-06-07).
class Money {
  /// Creates an amount.
  const Money(this.minor, this.currency);

  /// Minor units.
  final int minor;

  /// ISO code, upper case.
  final String currency;

  // Rs 10,000 crore, a sanity ceiling.
  static final _maxMinor = BigInt.from(1000000000000);
  static final _decimal = RegExp(r'^[+-]?(?:\d+\.?\d*|\.\d+)$');

  /// "1,23,456.5" -> 12345650. Null for anything that is not a sane positive
  /// amount. Rounds half up past two decimals.
  static Money? parse(String number, [String currency = 'INR']) {
    var cleaned = number.replaceAll(',', '');
    while (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isEmpty || !_decimal.hasMatch(cleaned)) return null;
    var negative = false;
    if (cleaned.startsWith('-') || cleaned.startsWith('+')) {
      negative = cleaned.startsWith('-');
      cleaned = cleaned.substring(1);
    }
    final dot = cleaned.indexOf('.');
    final whole = dot < 0 ? cleaned : cleaned.substring(0, dot);
    var frac = dot < 0 ? '' : cleaned.substring(dot + 1);
    final roundUp = frac.length > 2 && frac.codeUnitAt(2) >= 0x35;
    frac = frac.length >= 2 ? frac.substring(0, 2) : frac.padRight(2, '0');
    var minor = BigInt.parse('${whole.isEmpty ? '0' : whole}$frac');
    if (roundUp) minor += BigInt.one;
    if (negative) minor = -minor;
    if (minor <= BigInt.zero || minor > _maxMinor) return null;
    return Money(minor.toInt(), currency.toUpperCase());
  }

  /// Like [parse] but keeps a leading minus, and reads a zero as 0.
  static int? parseSigned(String number) {
    final negative = number.startsWith('-');
    final m = parse(negative ? number.substring(1) : number);
    if (m == null) {
      return trimChars(number, '-0.,').isEmpty ? 0 : null;
    }
    return negative ? -m.minor : m.minor;
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';
}
