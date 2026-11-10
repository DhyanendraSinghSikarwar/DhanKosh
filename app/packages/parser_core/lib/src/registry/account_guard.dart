import 'package:parser_core/src/bank/generic_bank_parser.dart';
import 'package:parser_core/src/bank/payment_app_parser.dart';
import 'package:parser_core/src/free_text/free_text_parser.dart';
import 'package:parser_core/src/registry/parser_registry.dart';

/// Decides whether a bank name and digits may become one of the user's
/// accounts (FR-13-24). A sender code, a payment app, a phone number's tail or
/// a payee's bank never does.
abstract final class AccountGuard {
  static final Set<String> _banks = {
    for (final p in ParserRegistry.standard().parsers)
      if (p is! GenericBankParser && p is! PaymentAppParser)
        p.bankName.toLowerCase(),
    for (final n in FreeTextParser.bankNames) n.toLowerCase(),
  };

  /// Whether [bank] is a bank or card issuer the app knows by name.
  static bool isKnownBank(String? bank) =>
      bank != null && _banks.contains(bank.trim().toLowerCase());

  /// Whether an account of [bank] ending [last4] may be created. [ownTails]
  /// are the last four digits of the user's own phone numbers.
  static bool mayCreate(
    String? bank,
    String? last4, {
    Set<String> ownTails = const {},
  }) {
    if (!isKnownBank(bank) || last4 == null) return false;
    if (last4.length < 2 || last4.length > 6) return false;
    if (RegExp(r'^0+$').hasMatch(last4)) return false;
    return !ownTails.contains(last4);
  }
}
