import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parse_result.dart';

/// Reads one bank's, lender's or payment app's messages.
abstract class BankParser {
  /// Display name of the bank, e.g. "HDFC Bank".
  String get bankName;

  /// Keys the registry maps to this parser in O(1): six-character SMS headers
  /// ("HDFCBK") and email domains ("hdfcbank.net").
  Set<String> get senderKeys;

  /// Whether this parser takes [sender] (and [body]).
  bool canHandle(String sender, String body);

  /// The outcome of parsing, with the reason when it is not a transaction.
  ParseResult parseDetailed(
    String body,
    String sender,
    int timestamp,
    Source source,
  );

  /// The transaction, or null when the message is not a completed transaction
  /// (OTP, promo, failed, reminder...).
  ParsedTransaction? parse(
    String body,
    String sender,
    int timestamp,
    Source source,
  ) =>
      parseDetailed(body, sender, timestamp, source).transaction;
}
