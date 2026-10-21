import 'package:parser_core/src/bank/base_bank_parser.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/registry/sender_keys.dart';
import 'package:parser_core/src/text/rx.dart';

/// Last resort for a bank sender with no dedicated parser. Accepts only senders
/// that look like banks or card issuers, so a stray courier or shopping SMS
/// that mentions an amount is never counted. Decides on the sender alone; the
/// body is not needed (FR-06-03).
class GenericBankParser extends BaseBankParser {
  /// Creates the parser.
  GenericBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'Bank';

  @override
  Set<String> get smsHeaders => const {};

  @override
  Set<String> get emailDomains => const {};

  @override
  bool canHandle(String sender, String body) {
    final candidates = SenderKeys.candidates(sender);
    if (candidates.isEmpty) return false;
    final key = candidates.last;
    if (key.contains('.') || key.contains('@')) {
      return _bankishDomain.hasMatch(key);
    }
    return _cardIssuers.contains(key.toUpperCase()) ||
        _bankishHeader.hasMatch(key);
  }

  @override
  String bankNameFor(String sender) {
    final candidates = SenderKeys.candidates(sender);
    if (candidates.isEmpty) return bankName;
    final key = candidates.last;
    if (key.contains('.')) {
      final head = key.substring(0, key.indexOf('.'));
      return head.isEmpty ? head : head[0].toUpperCase() + head.substring(1);
    }
    return key;
  }

  static final RegExp _bankishHeader =
      rx(r'(?:BK|BNK|BANK|BNKK|CRD)$|BANK|CARD');

  /// Card issuers and banks whose SMS headers do not look like "...BNK" or
  /// "...CRD".
  static const _cardIssuers = {
    'AMEXIN', 'AMEXCC', 'INDUSB', 'INDUSL', 'HSBCIN', 'HSBCCC', 'SCBNKS',
    'STANCB', 'ONECRD', 'BOBFIN', 'BOIIND', 'SIBSMS', 'PAYTMB', 'SLCEIT',
    'UNIONB', 'RBLCRD', 'DBSIND', 'CITIIN', 'IDBIIN', 'FEDSMS', //
  };
  static final RegExp _bankishDomain = rx('bank');
}
