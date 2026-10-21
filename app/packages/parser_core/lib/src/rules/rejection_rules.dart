import 'package:parser_core/src/text/rx.dart';

/// Decides whether a normalized message is not a completed transaction: an OTP,
/// promotion, failed or declined attempt, reminder or bill, future debit,
/// mandate setup, or money request (FR-06-06).
abstract final class RejectionRules {
  /// Past-tense money movement. Its presence rescues messages that merely
  /// mention OTPs or dues.
  static final RegExp _pastMovement = rx(
    r'\b(?:debited|credited|spent|withdrawn|deposited|received|sent|paid|deducted|transferred|refunded|reversed|charged|'
    r'(?:has\s+been|was)\s+used)\b',
  );

  static final _otpWord = Guarded(
    r'\b(?:otp|one[\s-]time[\s-]password|verification\s+code|security\s+code|passcode)\b',
    ['otp', 'password', 'verification', 'security', 'passcode'],
  );
  static final RegExp _otpCode = rx(
    r'(?:otp|code|password)\s*(?:is|:|-)?\s*\d{4,8}\b|\b\d{4,8}\s+is\s+(?:your\s+|the\s+)?(?:otp|one[\s-]time|code|verification)|'
    r'\b(?:otp|code)\s+for\b|\buse\s+(?:otp\s+)?\d{4,8}\b|'
    // "Your OTP to complete the purchase of INR 1,100.00 at ZOMATO ... is 482910"
    r'\b(?:otp|code)\b.{0,100}?\bis\s*:?\s*\d{4,8}\b',
  );

  static final _failed = Guarded(
    r'\b(?:failed|failure|declined|unsuccessful|not\s+successful|could\s+not\s+be\s+(?:processed|completed)|'
    r'(?:has\s+been|was|is)\s+rejected|insufficient\s+(?:funds|balance|bal)|incorrect\s+pin|invalid\s+pin|'
    r'returned\s+unpaid|dishonou?red|bounced)\b',
    [
      'fail', 'declin', 'unsuccess', 'success', 'could', 'reject',
      'insufficient', 'pin', 'returned', 'dishono', 'bounce', //
    ],
  );
  static final RegExp _reversal =
      rx(r'\b(?:reversed|refunded|reversal|refund)\b');
  static final RegExp _credited = rx(r'\bcredited\b');

  static final _future = Guarded(
    r'\bwill\s+be\s+(?:auto[\s-]?)?(?:debited|deducted|charged|credited|processed|presented|paid|transferred)\b|'
    r'\b(?:is\s+scheduled|scheduled\s+(?:for|on)|upcoming)\b',
    ['will', 'scheduled', 'upcoming'],
  );
  static final _due = Guarded(
    r'\b(?:is\s+due|due\s+(?:on|by|date)|payment\s+due|(?:amount|amt)\s+due|min(?:imum)?\.?\s+(?:amount|amt)|overdue|'
    r'bill\s+(?:is\s+)?generated|statement\s+(?:is\s+)?(?:generated|ready)|statement\s+for|pay\s+now|'
    r'payment\s+reminder|gentle\s+reminder|reminder)\b',
    ['due', 'min', 'bill', 'statement', 'pay', 'reminder'],
  );
  static final RegExp _settled = rx(
    r'\b(?:debited|credited|spent|withdrawn|deposited|received)\b',
  );

  static final _mandateSetup = Guarded(
    r'\b(?:e-?mandate|mandate|auto[\s-]?pay|standing\s+instruction|e-?nach)\b.{0,80}?'
    r'\b(?:registered|created|set\s*up|setup|activated|approved|revoked|cancelled|canceled|modified|paused)\b|'
    r'\b(?:set\s*up|created|registered|activated)\s+(?:an?\s+|your\s+)?(?:e-?mandate|mandate|auto[\s-]?pay)\b',
    ['mandate', 'auto', 'standing', 'nach'],
  );
  static final _collect = Guarded(
    r'\b(?:has\s+requested|requested\s+(?:money|INR|payment)|collect\s+request|payment\s+request)\b',
    ['request'],
  );

  static final _promo = Guarded(
    r'\b(?:pre[\s-]?approved|apply\s+now|you\s+are\s+eligible|eligible\s+for|avail\s+(?:now|the\s+offer)|get\s+up\s*to|'
    r'limited[\s-]period|exclusive\s+offer|special\s+offer|click\s+here|congratulations)\b',
    [
      'approved', 'apply', 'eligible', 'avail', 'get up', 'limited', 'offer',
      'click', 'congratulations', //
    ],
  );

  /// "Your available balance in account ending XX5152 is Rs. 1,155.70 as on
  /// 17-OCT-25"
  static final _balanceOnly = Guarded(
    r'\b(?:available|avl\.?|avbl\.?|account|a/c|closing|ledger)\s+bal(?:ance)?\b.{0,60}?\b(?:is|:)\s*(?:rs\.?|inr|₹)',
    ['bal'],
  );

  /// "If you have deposited a cheque, the amount will reflect after clearance."
  static final RegExp _ifClause = rx(r'\bif\s+you[^.]*');

  static final RegExp _activity =
      rx(r'\b(?:using|used|purchase|transaction|txn|payment)\b');

  /// Whether [text] is not a completed transaction.
  static bool shouldReject(String text, [String? lower]) =>
      reasonFor(text, lower) != null;

  /// The rule that rejects [text], or null when it may be a transaction.
  /// One of `otp`, `failed`, `future`, `mandate`, `collect`, `promo`,
  /// `reminder`, `balance`.
  static String? reasonFor(String text, [String? lowerText]) {
    final lower = lowerText ?? text.toLowerCase();
    if (_otpWord.containsMatchIn(text, lower) &&
        (_otpCode.hasMatch(text) || !_pastMovement.hasMatch(text))) {
      return 'otp';
    }
    if (_failed.containsMatchIn(text, lower) &&
        !(_reversal.hasMatch(text) && _credited.hasMatch(text))) {
      return 'failed';
    }
    if (_future.containsMatchIn(text, lower)) return 'future';
    if (_mandateSetup.containsMatchIn(text, lower)) return 'mandate';
    if (_collect.containsMatchIn(text, lower)) return 'collect';
    if (_promo.containsMatchIn(text, lower)) return 'promo';
    if (_due.containsMatchIn(text, lower) && !_settled.hasMatch(text)) {
      return 'reminder';
    }
    if (_balanceOnly.containsMatchIn(text, lower)) {
      final rest = text.replaceAll(_ifClause, '');
      if (!_pastMovement.hasMatch(rest) && !_activity.hasMatch(rest)) {
        return 'balance';
      }
    }
    return null;
  }
}
