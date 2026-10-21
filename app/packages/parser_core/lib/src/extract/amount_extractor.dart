import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// Finds the transaction amount: the first currency amount that is not a
/// balance, limit, or due figure (FR-06-07).
abstract final class AmountExtractor {
  static const _number = r'\d[\d,]*(?:\.\d{1,2})?';
  static final RegExp _currencyAmount = rx(
    r'\b(INR|USD|EUR|GBP|AED|SGD|AUD|CAD|JPY|CHF|SAR|QAR)\s*(' + _number + ')',
  );
  static final RegExp _bareAmount = rx(
    r'\b(?:debited|credited)\s+(?:by|for|with)\s+(' + _number + r')\b',
  );
  static final RegExp _nonTxnContext = rx(
    r'(?:bal(?:ance)?|lmt|limit|due|outstanding)\b[^0-9]{0,30}$',
  );
  static const _contextWindow = 45;

  /// The amount in [text], or null.
  static Money? extract(String text) {
    for (final m in _currencyAmount.allMatches(text)) {
      final start = m.start;
      final from = start - _contextWindow < 0 ? 0 : start - _contextWindow;
      final before = text.substring(from, start);
      if (_nonTxnContext.hasMatch(before)) continue;
      final money = Money.parse(grp(m, 2), grp(m, 1));
      if (money != null) return money;
    }
    final bare = findFrom(_bareAmount, text);
    return bare == null ? null : Money.parse(grp(bare, 1));
  }
}
