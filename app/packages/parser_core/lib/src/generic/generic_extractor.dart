import 'package:parser_core/src/extract/account_extractor.dart';
import 'package:parser_core/src/extract/amount_extractor.dart';
import 'package:parser_core/src/extract/balance_extractor.dart';
import 'package:parser_core/src/extract/channel_detector.dart';
import 'package:parser_core/src/extract/generic_phrases.dart';
import 'package:parser_core/src/extract/merchant_extractor.dart';
import 'package:parser_core/src/extract/reference_extractor.dart';
import 'package:parser_core/src/extract/type_classifier.dart';
import 'package:parser_core/src/merchant/merchant_normalizer.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/rules/rejection_rules.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/text/text_normalizer.dart';

/// A transaction read out of text no bank parser claims, with how sure the
/// reader is (FR-38-02). It is only ever offered to the user; nothing here is
/// saved without a confirmation.
class GenericSuggestion {
  /// Creates a suggestion.
  const GenericSuggestion({
    required this.amountMinor,
    required this.currency,
    required this.type,
    required this.channel,
    required this.category,
    required this.confidence,
    this.merchant,
    this.upiId,
    this.last4,
    this.accountKind = AccountKind.account,
    this.balanceMinor,
    this.limitMinor,
    this.reference,
    this.directionGuessed = false,
  });

  /// True when the text named no direction and a payment was assumed, as for
  /// a payment app's notification that carries only an amount (FR-38-06).
  final bool directionGuessed;

  /// Amount in minor units (paise).
  final int amountMinor;

  /// ISO currency code.
  final String currency;

  /// Debit, credit or investment.
  final TransactionType type;

  /// Payment rail.
  final Channel channel;

  /// Guessed category.
  final Category category;

  /// 50 to 100, see [GenericExtractor].
  final int confidence;

  /// Display merchant, if the text named one.
  final String? merchant;

  /// UPI id, if the text carried one.
  final String? upiId;

  /// Last digits of the account or card.
  final String? last4;

  /// Account or card.
  final AccountKind accountKind;

  /// Stated balance, in the amount's currency.
  final int? balanceMinor;

  /// Stated available limit.
  final int? limitMinor;

  /// Reference number (UTR, RRN).
  final String? reference;

  /// Whether the "Looks like" line is shown for an unlearned sender.
  bool get showsSuggestion => confidence >= GenericExtractor.suggestAt;
}

/// Reads a likely transaction from text that no parser handles, purely to
/// suggest it (FR-38-02, FR-38-03).
///
/// Confidence is additive and explainable: 50 for a currency-tagged amount
/// with a direction, +20 for the last digits of an account, +20 for a named
/// payee, +10 for a stated balance or limit, +5 for a reference number. A
/// suggestion is shown at [suggestAt] (60) or more, or at any score when the
/// sender is one the user has taught the app.
abstract final class GenericExtractor {
  /// Base score: an amount and a direction.
  static const baseConfidence = 50;

  /// The score at which the suggestion line is shown for an unknown sender.
  static const suggestAt = 60;

  static final RegExp _phone = RegExp(r'^\+?\d{10,}$');
  static final RegExp _dltPromoOrGovt = RegExp(r'-[PG]$', caseSensitive: false);
  static final RegExp _hasAmount =
      rx(r'(?:\bINR|\bRs\.?|₹|\bUSD|\bEUR|\bGBP|\bAED)\s*\d');

  // Messages that carry an amount but are not money moving.
  static final RegExp _notMoney = rx(
    r'\b(?:convert\s+(?:\w+\s+){0,3}(?:into\s+)?emi|smart\s*emi|asba|e-?voucher|have\s+received\s+payment|'
    r'ignore\s+if\s+(?:already\s+)?paid|in\s+arrears|due\s+on)\b',
  );

  /// Whether [sender] is a person's phone number, which is never a bank.
  static bool isPhoneSender(String sender) =>
      _phone.hasMatch(sender.replaceAll(RegExp(r'[\s-]'), ''));

  /// Whether messages from [sender] can be bank alerts at all: not empty, not
  /// a phone number, not a promotional or government header (`-P`, `-G`).
  static bool isCandidateSender(String sender) {
    final s = sender.trim();
    return s.isNotEmpty && !isPhoneSender(s) && !_dltPromoOrGovt.hasMatch(s);
  }

  /// Whether a message from [sender] with this [body] is worth a look when
  /// scanning the inbox for missed messages: a possible bank sender, and an
  /// amount next to a currency.
  static bool isCandidate(String sender, String body) =>
      isCandidateSender(sender) && _hasAmount.hasMatch(body);

  /// The suggestion for [body] from [sender], or null when it is not a
  /// completed money movement.
  static GenericSuggestion? read(String sender, String body) =>
      _read(sender, body, guessDirection: false);

  /// Like [read], for a payment app's notification: with an amount but no
  /// direction word it assumes a payment and says so ([directionGuessed]),
  /// so the user can correct it before it is saved (FR-38-06).
  static GenericSuggestion? readLoose(String sender, String body) =>
      _read(sender, body, guessDirection: true);

  static GenericSuggestion? _read(
    String sender,
    String body, {
    required bool guessDirection,
  }) {
    if (isPhoneSender(sender)) return null;
    final text = TextNormalizer.normalize(body);
    if (text.length < 12) return null;
    final lower = text.toLowerCase();
    if (RejectionRules.reasonFor(text, lower) != null) return null;
    if (_notMoney.hasMatch(text)) return null;

    final money = AmountExtractor.extract(text);
    if (money == null || money.minor <= 0) return null;

    final type = TypeClassifier.classify(text, lower: lower);
    var guessed = false;
    final TransactionType eff;
    if (type == TransactionType.debit ||
        type == TransactionType.credit ||
        type == TransactionType.investment) {
      eff = type!;
    } else if (type == null && guessDirection) {
      eff = TransactionType.debit;
      guessed = true;
    } else {
      return null;
    }

    final channel = ChannelDetector.detect(text, lower);
    final account = AccountExtractor.extract(text, eff);
    final raw = MerchantExtractor.extract(text, eff, lower);
    final merchant = MerchantNormalizer.normalize(raw, eff, channel, text);
    final name =
        merchant.name == null || GenericPhrases.isGeneric(merchant.name)
            ? null
            : GenericPhrases.clean(merchant.name);
    final upiId = raw.vpa?.toLowerCase();
    final balance =
        money.currency == 'INR' ? BalanceExtractor.balance(text, lower) : null;
    final limit =
        money.currency == 'INR' ? BalanceExtractor.limit(text, lower) : null;
    final reference =
        ReferenceExtractor.normalize(ReferenceExtractor.extract(text, lower));

    var score = guessed ? baseConfidence - 10 : baseConfidence;
    if (account != null) score += 20;
    if (name != null || upiId != null) score += 20;
    if (balance != null || limit != null) score += 10;
    if (reference != null) score += 5;
    if (score > 100) score = 100;

    return GenericSuggestion(
      amountMinor: money.minor,
      currency: money.currency,
      type: eff,
      channel: channel,
      category: merchant.category,
      confidence: score,
      merchant: name,
      upiId: upiId,
      last4: account?.last4,
      accountKind: account?.kind ?? AccountKind.account,
      balanceMinor: balance,
      limitMinor: limit,
      reference: reference,
      directionGuessed: guessed,
    );
  }
}
