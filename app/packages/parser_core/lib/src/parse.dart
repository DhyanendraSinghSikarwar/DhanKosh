import 'package:parser_core/src/bank/payment_app_parser.dart';
import 'package:parser_core/src/free_text/free_text_parser.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parse_result.dart';
import 'package:parser_core/src/registry/parser_registry.dart';

final ParserRegistry _registry = ParserRegistry.standard();
const FreeTextParser _freeText = FreeTextParser();

/// Parses one message: ``parse(source, sender, body, receivedAt)``
/// (FR-06-05, FR-06-19). Pure and deterministic.
///
/// - [Source.sms] and [Source.email]: [sender] is the SMS header ("VM-HDFCBK")
///   or the email address (`HDFC Bank <alerts@hdfcbank.net>`); the registry
///   picks the bank, lender or payment-app parser.
/// - [Source.app]: [sender] is the payment app's name ("Google Pay"); [body]
///   is the notification text.
/// - Other sources are not read here: screenshots go through
///   `FreeTextParser.draft`, statement text through the statements feature.
///
/// [receivedAt] is epoch milliseconds. Returns [Parsed] with the transaction,
/// [Rejected] with the rule that fired, or [NotATransaction].
ParseResult parse(
  Source source,
  String sender,
  String body,
  int receivedAt, {
  ParserRegistry? registry,
}) {
  switch (source) {
    case Source.sms:
    case Source.email:
      return (registry ?? _registry).parseDetailed(
        body,
        sender,
        receivedAt,
        source,
      );
    case Source.app:
      final read = _freeText.readNotification(sender, [body], receivedAt);
      final tx = read.tx;
      if (tx != null) return Parsed(tx);
      return PaymentAppParser.notificationSkip(read.skipReason);
    case Source.screenshot:
      return const NotATransaction('screenshot text is read as a draft');
    case Source.manual:
      return const NotATransaction('manual entries are not parsed');
    case Source.statement:
      return const NotATransaction(
        'statements are read by the statements feature',
      );
  }
}
