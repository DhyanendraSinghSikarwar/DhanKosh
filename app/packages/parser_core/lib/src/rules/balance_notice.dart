import 'package:parser_core/src/extract/account_extractor.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/rules/rejection_rules.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// A "your available balance is ..." message: no payment, only a figure
/// (FR-06-27).
class BalanceNotice {
  /// Creates a notice.
  const BalanceNotice({
    required this.bank,
    required this.last4,
    required this.balanceMinor,
    required this.at,
  });

  /// Bank from the sender header.
  final String bank;

  /// Account digits.
  final String last4;

  /// Stated balance, paise.
  final int balanceMinor;

  /// Message time, epoch ms.
  final int at;
}

/// Reads balance-only messages. Never a transaction.
abstract final class BalanceNoticeParser {
  static final RegExp _figure = rx(
    r'\bbal(?:ance)?\b.{0,70}?\b(?:is|:)\s*(?:rs\.?|inr|₹)\s*(-?\d[\d,]*(?:\.\d{1,2})?)',
  );

  /// The notice in [text] from a bank named [bank], or null.
  static BalanceNotice? parse(String text, String? bank, int at) {
    if (bank == null) return null;
    if (RejectionRules.reasonFor(text) != 'balance') return null;
    final m = _figure.firstMatch(text);
    final balance = m == null ? null : Money.parseSigned(grp(m, 1));
    final ref = AccountExtractor.extract(text);
    if (balance == null || ref == null || ref.kind != AccountKind.account) {
      return null;
    }
    return BalanceNotice(
      bank: bank,
      last4: ref.last4,
      balanceMinor: balance,
      at: at,
    );
  }
}
