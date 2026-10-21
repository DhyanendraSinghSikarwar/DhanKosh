import 'package:parser_core/src/bank/base_bank_parser.dart';
import 'package:parser_core/src/free_text/free_text_parser.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parse_result.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/text/text_normalizer.dart';

/// Payment-app receipts by email or SMS (PhonePe, Google Pay, Paytm, CRED,
/// MobiKwik, Amazon Pay): "Paid to Ravi Kumar, Transaction ID T2610..., UTR ...,
/// Debited from HDFC Bank XX1234". Read with the notification rules, so failed,
/// pending, offer and reminder mails are skipped and the UPI reference lets
/// dedup merge it with the bank's own alert (FR-06-16).
class PaymentAppParser extends BaseBankParser {
  /// Creates the parser.
  PaymentAppParser([super.config = const ParserConfig()])
      : _reader = FreeTextParser(config);

  final FreeTextParser _reader;

  @override
  String get bankName => 'UPI app';

  @override
  Set<String> get smsHeaders =>
      const {'PHNEPE', 'PHONPE', 'PHONEP', 'CREDCL', 'MOBIKW'};

  @override
  Set<String> get emailDomains => const {
        'phonepe.com',
        'noreply@phonepe.com',
        'googlepay-noreply@google.com',
        'payments-noreply@google.com',
        'noreply-payments@pay.google.com',
        'pay.google.com',
        'paytm.com',
        'paytm.in',
        'cred.club',
        'mobikwik.com',
        'amazonpay.in',
        'freecharge.in',
        'super.money',
      };

  String _appFor(String sender) {
    final s = sender.toLowerCase();
    if (s.contains('phonepe') ||
        s.contains('phnepe') ||
        s.contains('phonpe') ||
        s.contains('phonep')) {
      return 'PhonePe';
    }
    if (s.contains('google')) return 'Google Pay';
    if (s.contains('paytm')) return 'Paytm';
    if (s.contains('cred')) return 'CRED';
    if (s.contains('mobikwik') || s.contains('mobikw')) return 'MobiKwik';
    if (s.contains('amazon')) return 'Amazon Pay';
    if (s.contains('freecharge')) return 'Freecharge';
    if (s.contains('super.money')) return 'super.money';
    return 'UPI app';
  }

  @override
  ParseResult parseDetailed(
    String body,
    String sender,
    int timestamp,
    Source source,
  ) {
    final text = source == Source.email
        ? TextNormalizer.trimEmail(TextNormalizer.normalize(body))
        : body;
    final read = _reader.readNotification(
      _appFor(sender),
      [text],
      timestamp,
      source,
    );
    final tx = read.tx;
    if (tx != null) return Parsed(tx);
    return notificationSkip(read.skipReason);
  }

  /// A skip reason of the notification reader as a [ParseResult].
  static ParseResult notificationSkip(String? reason) {
    final r = reason ?? 'not a payment';
    return _rejections.contains(r) ? Rejected(r) : NotATransaction(r);
  }

  static const _rejections = {
    'otp or security text',
    'failed or pending payment',
    'request, reminder or due notice',
    'offer or promotion',
    'own transfer or card bill',
  };
}
