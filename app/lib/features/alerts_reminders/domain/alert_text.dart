/// Number and id helpers for alert text (FR-21-20). Pure Dart.
abstract final class AlertText {
  static const _symbols = {
    'INR': '₹',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'AED ',
    'SGD': r'S$',
  };

  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December', //
  ];

  /// "October 2026".
  static String monthYear(int year, int month) =>
      '${monthNames[month - 1]} $year';

  static String _group(String digits) {
    if (digits.length <= 3) return digits;
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    final parts = <String>[];
    for (var i = head.length; i > 0; i -= 2) {
      parts.insert(0, head.substring(i - 2 < 0 ? 0 : i - 2, i));
    }
    return '${parts.join(',')},$tail';
  }

  /// `Money.format`: en-IN grouping; paise only when non-zero and
  /// [showPaise]; the whole part is truncated when [showPaise] is false.
  static String money(
    int minor, {
    bool showPaise = false,
    String currency = 'INR',
  }) {
    final symbol = _symbols[currency] ?? '$currency ';
    final abs = minor.abs();
    final whole = _group((abs ~/ 100).toString());
    final paise = abs % 100;
    final sign = minor < 0 ? '-' : '';
    if (showPaise && paise != 0) {
      return '$sign$symbol$whole.${paise.toString().padLeft(2, '0')}';
    }
    return '$sign$symbol$whole';
  }

  /// Stable notification id for [key]: FNV-1a 32-bit mapped into
  /// 1,000,000..2,000,999,999 (above the fixed id bases; memory 21 Open
  /// Question 4: Dart `hashCode` is not stable across runs).
  static int stableId(String key) {
    var h = 0x811c9dc5;
    for (final u in key.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xffffffff;
    }
    return 1000000 + h % 2000000000;
  }
}
