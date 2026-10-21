import 'package:parser_core/src/bank/deposits.dart';
import 'package:parser_core/src/bank/loan_status.dart';
import 'package:parser_core/src/extract/account_extractor.dart';
import 'package:parser_core/src/extract/amount_extractor.dart';
import 'package:parser_core/src/extract/balance_extractor.dart';
import 'package:parser_core/src/extract/channel_detector.dart';
import 'package:parser_core/src/extract/date_time_extractor.dart';
import 'package:parser_core/src/extract/merchant_extractor.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/extract/reference_extractor.dart';
import 'package:parser_core/src/extract/type_classifier.dart';
import 'package:parser_core/src/hash/transaction_hasher.dart';
import 'package:parser_core/src/merchant/merchant_normalizer.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parse_result.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/registry/bank_parser.dart';
import 'package:parser_core/src/registry/sender_keys.dart';
import 'package:parser_core/src/rules/card_bill.dart';
import 'package:parser_core/src/rules/rejection_rules.dart';
import 'package:parser_core/src/template/template.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/text/text_normalizer.dart';
import 'package:parser_core/src/util/civil.dart';

/// The shared pipeline: normalize -> reject non-transactions -> bank templates
/// -> generic extractors (FR-06-05). A bank parser declares its sender keys and
/// the templates for the messages the generic extractors get wrong. Everything
/// else is inherited.
abstract class BaseBankParser extends BankParser {
  /// Creates a parser using [config].
  BaseBankParser([this.config = const ParserConfig()]);

  /// Zone and back-date settings.
  final ParserConfig config;

  /// Six-character SMS headers this bank writes from.
  Set<String> get smsHeaders;

  /// Email domains this bank writes from.
  Set<String> get emailDomains;

  /// Templates for this bank's SMS.
  List<Template> get smsTemplates => const [];

  /// Templates for this bank's emails.
  List<Template> get emailTemplates => const [];

  @override
  late final Set<String> senderKeys = {
    ...smsHeaders.map((h) => h.toUpperCase()),
    ...emailDomains.map((d) => d.toLowerCase()),
  };

  // Emails often reuse the SMS wording, so email parsing tries the email
  // templates first, then the SMS ones.
  late final List<Template> _emailThenSms = [
    ...emailTemplates,
    ...smsTemplates,
  ];

  /// The email domains to put in the Gmail `from:` query.
  Set<String> get emailSenders => emailDomains;

  @override
  bool canHandle(String sender, String body) =>
      SenderKeys.candidates(sender).any(senderKeys.contains);

  /// The name to show for [sender]'s messages.
  String bankNameFor(String sender) => bankName;

  /// An FD, RD or PPF account this bank's message describes (booking,
  /// renewal, maturity, balance), or null.
  LoanStatus? depositStatus(
    String body,
    String sender,
    int timestamp, [
    Source source = Source.sms,
  ]) {
    if (!DepositParser.mentionsDeposit(body)) return null;
    // An email's footer (offers, "book an FD now") is not about the user's
    // deposit.
    final text = source == Source.email
        ? TextNormalizer.trimEmail(TextNormalizer.normalize(body))
        : body;
    return DepositParser.status(text, bankNameFor(sender), timestamp);
  }

  @override
  ParseResult parseDetailed(
    String body,
    String sender,
    int timestamp,
    Source source,
  ) {
    final normalized = TextNormalizer.normalize(body);
    final text = source == Source.email
        ? TextNormalizer.trimEmail(normalized)
        : normalized;
    if (text.length < _minLength) return const NotATransaction('too short');
    final lower = text.toLowerCase();
    final reason = RejectionRules.reasonFor(text, lower);
    if (reason != null) return Rejected(reason);

    final templates = source == Source.email ? _emailThenSms : smsTemplates;
    TemplateMatch? hit;
    for (final t in templates) {
      hit = t.match(text);
      if (hit != null) break;
    }

    final hitAmount = hit?.amount;
    final money = (hitAmount == null
            ? null
            : Money.parse(hitAmount, hit?.currency ?? 'INR')) ??
        AmountExtractor.extract(text);
    if (money == null) return const NotATransaction('no amount');
    var type = TypeClassifier.classify(text, hint: hit?.type, lower: lower);
    if (type == null) return const NotATransaction('no direction');

    final genericAccount = AccountExtractor.extract(text, type);
    final hitAccount = hit?.account;
    final last4 = hitAccount != null
        ? hitAccount
            .substring(hitAccount.length > 4 ? hitAccount.length - 4 : 0)
        : genericAccount?.last4;
    final kind =
        hit?.accountKind ?? genericAccount?.kind ?? AccountKind.account;
    final reference = ReferenceExtractor.normalize(
      hit?.reference ?? ReferenceExtractor.extract(text, lower),
    );

    // A message with neither an account nor a reference is almost always
    // marketing.
    if (last4 == null && reference == null && hit == null) {
      return const NotATransaction('no account or reference');
    }
    // An FD/RD/PPF advice about the deposit itself is a deposit status (see
    // depositStatus), not money moving on an account.
    if (DepositParser.aboutDepositOnly(text, last4)) {
      return const NotATransaction('deposit advice');
    }

    final channel = ChannelDetector.detect(text, lower);
    final raw = hit?.merchant != null || hit?.vpa != null
        ? RawMerchant(hit?.merchant, hit?.vpa)
        : MerchantExtractor.extract(text, type, lower);

    if (type == TransactionType.debit &&
        (TypeClassifier.looksLikeInvestment(text, lower) ||
            MerchantNormalizer.categoryOf(raw) == Category.investment)) {
      type = TransactionType.investment;
    }
    // A bank debit that pays a credit card's bill settles spends already
    // counted on the card: a transfer, not a spend.
    if (type == TransactionType.debit &&
        CardBill.isBill(text, raw.name, raw.vpa)) {
      type = TransactionType.transfer;
    }
    final merchant = MerchantNormalizer.normalize(raw, type, channel, text);

    final hitBalance = hit?.balance;
    final balance =
        (hitBalance == null ? null : Money.parseSigned(hitBalance)) ??
            BalanceExtractor.balance(text, lower);
    // A credit card's "Avl bal" is its available limit, never a bank balance.
    final int? limit;
    if (kind == AccountKind.card) {
      limit = BalanceExtractor.limit(text, lower) ??
          (balance != null &&
                  _creditCard.hasMatch(text) &&
                  !_debitCard.hasMatch(text)
              ? balance
              : null);
    } else {
      limit = null;
    }
    // A debit card reports its bank account's balance ("Bal Rs.5,73,096"); a
    // credit card reports a limit.
    final isDebitCard = kind == AccountKind.card &&
        (_debitCard.hasMatch(text) ||
            (balance != null && limit == null && !_creditCard.hasMatch(text)));

    final resolved = _resolveTime(
      DateTimeExtractor.extract(text, lower),
      timestamp,
    );
    final date = civilDateOf(resolved.$1, config.utcOffset);

    var confidence = 0.5;
    if (last4 != null) confidence += 0.15;
    if (reference != null) confidence += 0.15;
    if (merchant.name != null) confidence += 0.1;
    if (hit != null) confidence += 0.1;

    return Parsed(
      ParsedTransaction(
        amountMinor: money.minor,
        currency: money.currency,
        type: type,
        bankName: bankNameFor(sender),
        accountLast4: last4,
        accountKind: kind,
        merchant: merchant.name,
        upiId: raw.vpa?.toLowerCase(),
        referenceNumber: reference,
        channel: channel,
        balanceMinor: kind == AccountKind.card && !isDebitCard ? null : balance,
        availableLimitMinor: limit,
        transactionTime: resolved.$1,
        hasExplicitTime: resolved.$2,
        category: merchant.category,
        source: source,
        sender: sender,
        messageTimestamp: timestamp,
        confidence: confidence > 1 ? 1 : confidence,
        transactionHash: TransactionHasher.hash(
          money.minor,
          type,
          last4,
          date,
          reference,
        ),
        isDebitCard: isDebitCard,
      ),
    );
  }

  /// The date in the text wins when it is plausible; the time of day comes from
  /// the text or the message.
  (int, bool) _resolveTime(DateTimeParts parts, int messageTs) {
    final msg = civilOf(messageTs, config.utcOffset);
    final date = parts.date;
    if (date == null) return (messageTs, false);
    final msgDate = msg.date;
    if (date.isAfter(msgDate.plusDays(1)) ||
        date.isBefore(msgDate.minusDays(config.maxBackdateDays))) {
      return (messageTs, false);
    }
    final time = parts.time;
    if (time != null) return (epochOf(date, time, config.utcOffset), true);
    if (date == msgDate) return (messageTs, false);
    return (epochOf(date, msg.time, config.utcOffset), false);
  }

  static const _minLength = 20;
  static final RegExp _debitCard = rx(r'\bdebit\s+card\b|\bBLOCK\s+DC\b');
  static final RegExp _creditCard = rx(r'\bcredit\s+card\b|\bBLOCK\s+CC\b');
}
