import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';

/// Decides money direction and recognises transfers and investments
/// (FR-06-07, FR-06-11).
abstract final class TypeClassifier {
  static final RegExp _debit = rx(
    r'\b(?:debited|debit\s+(?:by|for|of|alert)|spent|withdrawn|withdrawal|paid|sent|purchased?|deducted|charged|'
    r'transferred\s+to|txn\s+of|used\s+(?:for|at|on)|thank\s+you\s+for\s+using|'
    // Card alerts: "Transaction of Rs.899 on Kotak Credit Card".
    r'(?:transaction|trxn|txn)\s+(?:of\s+)?(?:INR|USD|EUR|GBP|AED|SGD)|transaction\s+alert\s+on\s+(?:your\s+)?(?:\w+\s+){0,4}card|made\s+a\s+(?:transaction|purchase|payment))\b',
  );
  static final RegExp _credit = rx(
    r'\b(?:credited|credit\s+(?:by|of|alert|with)|received|deposited|refund(?:ed)?|reversed|reversal)\b',
  );

  /// A credit-card bill payment or a move between the user's own accounts:
  /// neither income nor spend.
  static final _transfer = Guarded(
    r'\bpayment\b.{0,60}?\breceived\b.{0,60}?card\b|\breceived\s+(?:your\s+)?payment\b.{0,70}?card\b|'
    // Card side, other wordings.
    r'\bpayment\b.{0,60}?\b(?:credited|posted|reflected)\b.{0,60}?\bcredit\s+card\b|'
    r'\bcredit\s+card\b.{0,40}?\bpayment\b.{0,40}?\b(?:credited|posted|reflected|received)\b|'
    r'\bthank\s+you\s+for\s+(?:your\s+|the\s+)?payment\b|\bself[\s-]transfer\b|\bown\s+account\b|'
    r'\bbetween\s+your\s+(?:own\s+)?accounts\b|'
    // Bank side of a card bill.
    r'\btowards\s+(?:your\s+)?(?:[A-Za-z]+\s+){0,3}credit\s+card\b|\b(?:credit\s+card|cc)\s+(?:bill\s+)?payment\b|\bcard\s+bill\b',
    ['payment', 'self', 'own account', 'between your', 'towards', 'card bill'],
  );

  /// Money the user sent to someone else's account. Banks write the payee's
  /// side ("credited to Beneficiary A/c XX9876", "credited to ANIL's
  /// account"), which would otherwise read as income.
  static final _outgoing = Guarded(
    r'\bcredited\s+(?:in)?to\s+(?:the\s+)?(?:beneficiary|benef\w*|bene|payee|recipient)\b|'
    r"\bcredited\s+(?:in)?to\s+(?:[A-Za-z.]+\s+){0,3}[A-Za-z.]+['’]s\s+(?:a/c|acct|account|bank)\b|"
    r'\btransfer\s+of\s+INR\s*[\d,.]+\s+to\s+(?:a/c|acct|account|beneficiary)\b|'
    r'\btransfer\b.{0,40}?\bto\s+(?:a/c|acct|account|beneficiary)\b.{0,60}?\bsuccess|'
    r'\b(?:sent|transferred|remitted)\s+to\s+(?:a/c|acct|account|beneficiary|benef\w*|payee)\b',
    ['credited', 'transfer', 'sent', 'remitted'],
  );
  static final _investment = Guarded(
    r'\b(?:mutual\s+fund|MF|SIP|zerodha|groww|upstox|kuvera|iccl|indian\s+clearing|nse\s+clearing|clearing\s+corp|'
    r'cams|kfin(?:tech)?|smallcase|angel\s+one|paytm\s+money|ppf|nps)\b',
    [
      'mutual', 'mf', 'sip', 'zerodha', 'groww', 'upstox', 'kuvera', 'iccl',
      'clearing', 'cams', 'kfin', 'smallcase', 'angel', 'paytm', 'ppf',
      'nps', //
    ],
  );

  // Lets a credit verb that starts at the debit position still be seen whole.
  static const _creditOverlap = 12;

  /// The type of [text]: transfer first, then the [hint], then outgoing
  /// wording, then the earlier of the debit and credit verbs.
  static TransactionType? classify(
    String text, {
    TransactionType? hint,
    String? lower,
  }) {
    final low = lower ?? text.toLowerCase();
    if (_transfer.containsMatchIn(text, low)) return TransactionType.transfer;
    if (hint != null) return hint;
    if (_outgoing.containsMatchIn(text, low)) return TransactionType.debit;
    // The earlier verb wins, so the credit search only needs the text before
    // the first debit verb.
    final debit = findFrom(_debit, text)?.start;
    final creditScope = debit == null
        ? text
        : text.substring(
            0,
            debit + _creditOverlap > text.length
                ? text.length
                : debit + _creditOverlap,
          );
    final credit = findFrom(_credit, creditScope)?.start;
    if (debit == null && credit == null) return null;
    if (credit == null) return TransactionType.debit;
    if (debit == null || credit < debit) return TransactionType.credit;
    return TransactionType.debit;
  }

  /// Whether [text] reads as an investment (SIP, mutual fund, broker).
  static bool looksLikeInvestment(String text, [String? lower]) =>
      _investment.containsMatchIn(text, lower ?? text.toLowerCase());
}
