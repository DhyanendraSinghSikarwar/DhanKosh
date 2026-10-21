import 'package:hisaab/core/money/money.dart';

const _symbols = {
  'INR': '₹',
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'AED': 'AED ',
  'SGD': r'S$',
};

/// Groups [digits] the Indian way: last three, then pairs (12,34,567).
String groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final buf = StringBuffer();
  final first = head.length.isOdd ? 1 : 2;
  buf.write(head.substring(0, first));
  for (var i = first; i < head.length; i += 2) {
    buf
      ..write(',')
      ..write(head.substring(i, i + 2));
  }
  return '$buf,$tail';
}

/// Formats [m] with en-IN grouping, e.g. `₹1,23,456.78`, using integers only.
///
/// [masked] returns `₹••••` (the "hide amounts" setting).
String formatMoney(
  Money m, {
  bool showPaise = true,
  bool masked = false,
}) {
  final symbol = _symbols[m.currency] ?? '${m.currency} ';
  if (masked) return '$symbol••••';
  final abs = m.minor.abs();
  final whole = groupIndian((abs ~/ 100).toString());
  final paise = (abs % 100).toString().padLeft(2, '0');
  final sign = m.isNegative ? '-' : '';
  return showPaise ? '$sign$symbol$whole.$paise' : '$sign$symbol$whole';
}

final _amountPattern = RegExp(r'^-?\d+(\.\d{1,2})?$');

/// Parses user input like `1,23,456.78` or `₹ 500` into [Money], or null.
///
/// Never goes through `double`.
Money? parseMoney(String input, {String currency = 'INR'}) {
  var s = input.trim().replaceAll(',', '').replaceAll(RegExp(r'[₹\s]'), '');
  if (s.startsWith('+')) s = s.substring(1);
  if (!_amountPattern.hasMatch(s)) return null;
  final negative = s.startsWith('-');
  if (negative) s = s.substring(1);
  final parts = s.split('.');
  final whole = int.parse(parts[0]);
  final frac = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
  final minor = whole * 100 + frac;
  return Money(negative ? -minor : minor, currency: currency);
}
