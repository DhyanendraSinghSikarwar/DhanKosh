import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';

/// Payment rail by priority: ATM, auto-debit, UPI, IMPS, NEFT, RTGS, card
/// (FR-06-07).
abstract final class ChannelDetector {
  // "Withdrawn Rs.10000 From HDFC Bank Card x2139 At +NALLAGANDLA" is a
  // debit-card cash withdrawal.
  static final _atm = Guarded(
    r'\bATM\b|\bcash\s+withdrawal\b|\bwithdrawn\b',
    ['atm', 'cash', 'withdrawn'],
  );
  static final _upi = Guarded(
    r'\bUPI\b|\bVPA\b|@(?:ok\w+|ybl|ibl|axl|paytm|upi|icici|hdfcbank|sbi|axisbank|apl|ptyes|ptsbi|pthdfc|ptaxis|kotak|idfcbank)\b',
    ['upi', 'vpa', '@'],
  );
  static final _imps = Guarded(r'\bIMPS\b', ['imps']);
  static final _neft = Guarded(r'\bNEFT\b', ['neft']);
  static final _rtgs = Guarded(r'\bRTGS\b', ['rtgs']);
  static final _auto = Guarded(
    r'\b(?:ACH|NACH|ECS|mandate|auto[\s-]?pay|standing\s+instruction)\b',
    ['ach', 'ecs', 'mandate', 'auto', 'standing'],
  );

  /// The channel of [text].
  static Channel detect(String text, [String? lowerText]) {
    final lower = lowerText ?? text.toLowerCase();
    if (_atm.containsMatchIn(text, lower)) return Channel.atm;
    if (_auto.containsMatchIn(text, lower)) return Channel.autoDebit;
    if (_upi.containsMatchIn(text, lower)) return Channel.upi;
    if (_imps.containsMatchIn(text, lower)) return Channel.imps;
    if (_neft.containsMatchIn(text, lower)) return Channel.neft;
    if (_rtgs.containsMatchIn(text, lower)) return Channel.rtgs;
    if (lower.contains('card')) return Channel.card;
    return Channel.other;
  }
}
