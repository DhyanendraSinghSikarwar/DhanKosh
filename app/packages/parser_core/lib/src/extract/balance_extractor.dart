import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// Available balance of the account, and available limit of a card
/// (FR-06-07).
abstract final class BalanceExtractor {
  static final _balance = Guarded(
    r'(?:\b|(?<=avl)|(?<=avbl))bal(?:ance)?\b[^0-9]{0,40}?\b(?:INR)\s*(-?\d[\d,]*(?:\.\d{1,2})?)',
    ['bal'],
  );
  static final _limit = Guarded(
    r'\b(?:lmt|limit)\b[^0-9]{0,30}?\bINR\s*(\d[\d,]*(?:\.\d{1,2})?)',
    ['lmt', 'limit'],
  );

  /// The balance in [text], paise (may be negative).
  static int? balance(String text, [String? lower]) {
    final m = _balance.find(text, lower ?? text.toLowerCase());
    return m == null ? null : Money.parseSigned(grp(m, 1));
  }

  /// The available card limit in [text], paise.
  static int? limit(String text, [String? lower]) {
    final m = _limit.find(text, lower ?? text.toLowerCase());
    return m == null ? null : Money.parse(grp(m, 1))?.minor;
  }
}
