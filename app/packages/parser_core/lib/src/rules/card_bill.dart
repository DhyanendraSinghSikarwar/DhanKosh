import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// Recognises a credit-card bill payment made from a bank account, wallet or
/// UPI app: money that settles the card, not a spend. Such a payment is stored
/// as a transfer (shown in Transactions as "Credit card bill", never counted
/// as spend or income). Only the bank/app side is judged here; a card's own
/// "payment received" credit is a transfer by `TypeClassifier` (FR-06-10).
abstract final class CardBill {
  /// Label of the note and merchant a recognised bill payment carries.
  static const label = 'Credit card bill';

  static const _banks =
      r'(?:axis|hdfc|icici|sbi|kotak|idfc|yes|rbl|indusind|amex|citi|hsbc|au|bob|pnb|federal|standard\s+chartered|sc)';

  /// Wording of a bank SMS, a payment-app notification or a net-banking email.
  static final _text = Guarded(
    r'\b(?:credit\s*card|cc)\s*(?:bill|bil|dues?|payment|pymt|pmt|repayment|outstanding)\b|'
            r'\bcard\s+(?:bill|dues?)\s+(?:payment|paid|pymt)\b|'
            r'\btowards\s+(?:your\s+)?(?:[A-Za-z&.]+\s+){0,3}credit\s*card\b|'
            r'\bto\s+(?!your\b)(?:[A-Za-z&.]+\s+){0,3}credit\s*card\s+(?:no\.?\s*)?(?:x+|\*+)\d{4}\b|'
            r'\b' +
        _banks +
        r'\s*(?:bank\s+)?(?:credit\s+)?card\s+(?:bill|payment|pymt|dues?)\b|'
            r'\bbank\s+(?:ltd|limited)\.?\s+(?:credit\s+)?cards?\b|'
            r'\b(?:axis|hdfc|icici|sbi|kotak|idfc|yes|rbl|indusind|amex|au)(?:cc|creditcard)\b|'
            r'\b(?:billdesk|bbps|bil)\W{0,3}(?:cc|credit\s*card)\b|'
            r'\bcred\s*club\b|\bcred\.club\b|\bdreamplug\b',
    ['credit', 'cc', 'card', 'cred', 'dreamplug'],
  );

  /// A payee that is a card issuer's card account, by name. "Axis Gold",
  /// "Credit Bazaar" or "CRED cashback store" are not.
  static final RegExp _name = rx(
    r'^(?:[a-z&.]+\s+){0,4}credit\s*cards?(?:\s+(?:bill|payment|payments|dues?|no\.?|x+\d*|\*+\d*|\d{4}))*$|'
            r'^(?:[a-z&.]+\s+){0,2}(?:cc|card)\s+(?:bill|payment|payments|dues?)(?:\s+\d{4})?$|'
            '^(?:' +
        _banks +
        r')\s*(?:cc|creditcard)$|^(?:sbi\s+cards?(?:\s+(?:and\s+payment\s+services|payment|payments))?|sbi\s*card)$|'
            r'^cred(?:\s+club)?$|^dreamplug(?:\s+technologies)?$|^(?:card\s*payment|cardpayment|cc\s*payment)$|'
            r'^[a-z&.]+(?:\s+[a-z&.]+){0,2}\s+bank\s+(?:ltd|limited)\.?\s+(?:credit\s+)?cards?$',
  );

  static final RegExp _issuer = rxFull(_banks);

  static const _vpaTokens = {
    'creditcard', 'cardpayment', 'cardpay', 'ccpay', 'ccbill', 'cardbill',
    'ccpayment', 'axiscc', 'hdfccc', 'icicicc', 'sbicc', 'kotakcc', 'idfccc',
    'yescc', 'rblcc', 'indusindcc', 'amexcc', 'aucc', 'sbicard', 'credclub', //
  };

  static final RegExp _paidToCard = rx(
    r'\b(?:paid|sent|payment)\b.{0,40}?\bto\s+(?!your\b)(?:[A-Za-z&.]+\s+){0,3}credit\s*cards?\b',
  );
  static final _nameNoise = RegExp('[^a-z0-9&.* ]+');
  static final _spaces = RegExp(r'\s+');

  /// A payment app's notification that says the money went to a credit card
  /// ("Paid ₹6,774 to Axis Bank Credit Card").
  static bool paidToCard(String text) => _paidToCard.hasMatch(text);

  /// True when the message text reads as a card bill being paid from a bank
  /// account or app.
  static bool inText(String text, [String? lower]) =>
      _text.containsMatchIn(text, lower ?? text.toLowerCase());

  /// True when the payee is a credit card or its issuer's payment collector:
  /// by display name or UPI id.
  static bool isPayee(String? name, String? upiId) {
    final n = name
        ?.toLowerCase()
        .replaceAll(_nameNoise, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    if (n != null && n.isNotEmpty && _name.hasMatch(n)) return true;
    if (upiId == null) return false;
    final lowerId = upiId.toLowerCase();
    final at = lowerId.indexOf('@');
    final local = at < 0 ? lowerId : lowerId.substring(0, at);
    if (local.isEmpty) return false;
    final tokens =
        local.split(RegExp('[._+-]')).where((t) => t.isNotEmpty).map((t) {
      var e = t.length;
      while (e > 0 && isDigit(t[e - 1])) {
        e--;
      }
      return t.substring(0, e);
    }).toList();
    if (tokens.any(_vpaTokens.contains)) return true;
    // A bare "cc" is a card only beside an issuer ("cc.axis"); "cc.sharma" is
    // a person.
    if (tokens.contains('cc') && tokens.any(_issuer.hasMatch)) return true;
    return tokens.length >= 2 && tokens[0] == 'cred' && tokens[1] == 'club';
  }

  /// A bill payment: the text says so, or the payee is a card. A payee match is
  /// ignored on a card's own debit ([onCard]): a card cannot pay its own bill,
  /// so "Credit Card Cafe" there is a merchant.
  static bool isBill(
    String? text,
    String? name,
    String? upiId, {
    bool onCard = false,
  }) =>
      (text != null && inText(text)) || (!onCard && isPayee(name, upiId));

  /// [tx] as a bill payment when it is a debit that pays a credit card.
  /// Anything else is returned as it is. Idempotent.
  static ParsedTransaction mark(ParsedTransaction tx, String? rawText) {
    if (tx.type != TransactionType.debit) return tx;
    if (!isBill(
      rawText,
      tx.merchant,
      tx.upiId,
      onCard: tx.accountKind == AccountKind.card,
    )) {
      return tx;
    }
    return tx.copyWith(
      type: TransactionType.transfer,
      category: Category.transfer,
      merchant: tx.merchant ?? label,
    );
  }
}
