import 'package:parser_core/src/model/model.dart';

/// The outcome of parsing one message (FR-06-05).
sealed class ParseResult {
  const ParseResult();

  /// The transaction when parsed, else null.
  ParsedTransaction? get transaction => switch (this) {
        Parsed(:final transaction) => transaction,
        Rejected() || NotATransaction() => null,
      };
}

/// A completed transaction was read.
final class Parsed extends ParseResult {
  /// Wraps [transaction].
  const Parsed(this.transaction);

  @override
  final ParsedTransaction transaction;
}

/// A rejection rule fired: an OTP, promotion, failed attempt, reminder, future
/// debit, mandate setup, money request or balance note. [reason] is the rule
/// name (`otp`, `failed`, `future`, `mandate`, `collect`, `promo`, `reminder`,
/// `balance`) or a short notification skip reason.
final class Rejected extends ParseResult {
  /// Rejected for [reason].
  const Rejected(this.reason);

  /// Why.
  final String reason;
}

/// No rule rejected it, but it is not a transaction either: unknown sender,
/// too short, no amount or direction, no account or reference, or a deposit
/// advice. [reason] is a short generic note, never message text.
final class NotATransaction extends ParseResult {
  /// Not a transaction for [reason].
  const NotATransaction(this.reason);

  /// Why.
  final String reason;
}
