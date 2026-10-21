// Core bank parsers: the template sets for the messages the generic
// extractors get wrong (FR-06-08). Templates run on normalized text: one line,
// "INR " for every rupee spelling, line breaks as ". ".

import 'package:parser_core/src/bank/base_bank_parser.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/template/template.dart';

/// HDFC Bank alerts.
class HdfcBankParser extends BaseBankParser {
  /// Creates the parser.
  HdfcBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'HDFC Bank';

  @override
  Set<String> get smsHeaders => const {'HDFCBK', 'HDFCBN', 'HDFCCC'};

  @override
  Set<String> get emailDomains =>
      const {'hdfcbank.net', 'hdfcbank.com', 'hdfcbank.bank.in'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''Sent\s+INR\s*(?<amt>%AMT%)\.?\s+From\s+HDFC\s+Bank\s+A/C\s+[x*]*(?<acct>\d{4})\.?\s+To\s+(?<merchant>.+?)\.?\s+On\s+\d{2}/\d{2}/\d{2}\.?\s+Ref\s+(?<ref>\d{9,14})''',
      type: TransactionType.debit,
    ),
    Template(
      r'''NEFT\s+Cr-[A-Z]{4}0[A-Z0-9]{6}-(?<merchant>[^-]+?)-[^-]*-(?<ref>[A-Z0-9]{12,22})''',
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''Credit\s+Card\s+ending\s+(?<acct>\d{4})\s+for\s+INR\s*(?<amt>%AMT%)\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+has\s+been\s+debited\s+from\s+account\s+[x*]*(?<acct>\d{4})\s+to\s+VPA\s+(?<vpa>\S+)\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
    ),
  ];
}

/// ICICI Bank alerts.
class IciciBankParser extends BaseBankParser {
  /// Creates the parser.
  IciciBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'ICICI Bank';

  @override
  Set<String> get smsHeaders => const {'ICICIB', 'ICICIT', 'ICICIO'};

  @override
  Set<String> get emailDomains =>
      const {'icicibank.com', 'icici.bank.in', 'icicibank.bank.in'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''Acct\s+XX(?<acct>\d{3,4})\s+debited\s+(?:for|with)\s+INR\s*(?<amt>%AMT%)\s+on\s+[\w-]+;\s*(?<merchant>.+?)\s+credited\.\s*(?:UPI|IMPS|RRN)\s*:?\s*(?<ref>\d{9,14})''',
      type: TransactionType.debit,
    ),
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+spent\s+(?:using|on)\s+ICICI\s+Bank\s+Card\s+XX(?<acct>\d{4})\s+on\s+[\w-]+\s+on\s+(?<merchant>.+?)\.(?:\s|$)''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''Credit\s+Card\s+XX(?<acct>\d{4})\s+has\s+been\s+used\s+for\s+a\s+transaction\s+of\s+INR\s*(?<amt>%AMT%)''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}

/// SBI alerts.
class SbiParser extends BaseBankParser {
  /// Creates the parser.
  SbiParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'SBI';

  @override
  Set<String> get smsHeaders => const {
        'SBIINB',
        'SBIUPI',
        'CBSSBI',
        'ATMSBI',
        'SBIPSG',
        'SBICRD',
        'SBIBNK',
      };

  @override
  Set<String> get emailDomains =>
      const {'alerts.sbi.co.in', 'sbi.co.in', 'sbicard.com', 'sbi.bank.in'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''A/C\s+X(?<acct>\d{4})\s+debited\s+by\s+(?<amt>%AMT%)\s+on\s+date\s+\S+\s+trf\s+to\s+(?<merchant>.+?)\s+Refno\s+(?<ref>\d{9,14})''',
      type: TransactionType.debit,
    ),
    Template(
      r'''A/c\s+X(?<acct>\d{4})-credited\s+by\s+INR\s*(?<amt>%AMT%)\s+on\s+\S+\s+transfer\s+from\s+(?<merchant>.+?)\s+Ref\s+No\s+(?<ref>\d{9,14})''',
      type: TransactionType.credit,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''SBI\s+Credit\s+Card\s+ending\s+(?<acct>\d{4})\s+for\s+INR\s*(?<amt>%AMT%)\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}

/// Axis Bank alerts.
class AxisBankParser extends BaseBankParser {
  /// Creates the parser.
  AxisBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'Axis Bank';

  @override
  Set<String> get smsHeaders => const {'AXISBK', 'AXISMR', 'AXISCC'};

  @override
  Set<String> get emailDomains =>
      const {'axisbank.com', 'axis.bank.in', 'axisbank.bank.in'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''Spent\s+INR\s*(?<amt>%AMT%)\.?\s+Axis\s+Bank\s+Card\s+no\.?\s+XX(?<acct>\d{4})\.?\s+[0-9-]+\s+[0-9:]+\s*(?:IST)?\.?\s+(?<merchant>.+?)\.?\s+Avl\s+(?:Credit\s+)?Limit''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
    Template(
      r'''Spent\.?\s+Card\s+no\.\s+XX(?<acct>\d{4})\.\s+INR\s*(?<amt>%AMT%)\.\s+[\d-]+\s+[\d:]+\.\s+(?<merchant>[^.]+?)\.\s+Avl''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+was\s+spent\s+on\s+your\s+Axis\s+Bank\s+Credit\s+Card\s+no\.\s+XX(?<acct>\d{4})\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}

/// Kotak Mahindra Bank alerts.
class KotakBankParser extends BaseBankParser {
  /// Creates the parser.
  KotakBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'Kotak Mahindra Bank';

  @override
  Set<String> get smsHeaders => const {'KOTAKB', 'KOTAKM', 'KMBLTD'};

  @override
  Set<String> get emailDomains =>
      const {'kotak.com', 'kotak.bank.in', 'kotakbank.com'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''Sent\s+INR\s*(?<amt>%AMT%)\s+from\s+Kotak\s+Bank\s+AC\s+X(?<acct>\d{4})\s+to\s+(?<vpa>\S+?)\s+on\s+[\d-]+\.\s*UPI\s+Ref\s*:?\s*(?<ref>\d{9,14})''',
      type: TransactionType.debit,
    ),
    Template(
      r'''Received\s+INR\s*(?<amt>%AMT%)\s+in\s+your\s+Kotak\s+Bank\s+AC\s+X(?<acct>\d{4})\s+from\s+(?<vpa>\S+?)\s+on\s''',
      type: TransactionType.credit,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''Kotak\s+Credit\s+Card\s+xx(?<acct>\d{4})\s+has\s+been\s+used\s+for\s+INR\s*(?<amt>%AMT%)\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}

/// IDFC FIRST Bank alerts.
class IdfcFirstBankParser extends BaseBankParser {
  /// Creates the parser.
  IdfcFirstBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'IDFC FIRST Bank';

  @override
  Set<String> get smsHeaders => const {'IDFCFB', 'IDFCBK'};

  @override
  Set<String> get emailDomains =>
      const {'idfcfirstbank.com', 'idfcfirst.bank.in', 'idfcbank.com'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''debited\s+by\s+INR\s*(?<amt>%AMT%)\s+on\s+\S+\s+for\s+(?:UPI\s+txn|IMPS|NEFT)\s+to\s+(?<merchant>.+?)\.(?:\s|$)''',
      type: TransactionType.debit,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+has\s+been\s+debited\s+from\s+your\s+account\s+XX+(?<acct>\d{4})\s+towards\s+UPI\s+payment\s+to\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
    ),
  ];
}

/// Yes Bank alerts.
class YesBankParser extends BaseBankParser {
  /// Creates the parser.
  YesBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'Yes Bank';

  @override
  Set<String> get smsHeaders => const {'YESBNK', 'YESBKK', 'YESBK'};

  @override
  Set<String> get emailDomains =>
      const {'yesbank.in', 'yes.bank.in', 'yesbank.bank.in'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+debited\s+from\s+YES\s+BANK\s+A/c\s+XX(?<acct>\d{4})\s+on\s+\S+\s+for\s+(?:UPI|IMPS|NEFT)\s+to\s+(?<merchant>.+?)\.(?:\s|$)''',
      type: TransactionType.debit,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''YES\s+BANK\s+Credit\s+Card\s+XX(?<acct>\d{4})\s+has\s+been\s+used\s+for\s+INR\s*(?<amt>%AMT%)\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}

/// Bank of Baroda alerts.
class BankOfBarodaParser extends BaseBankParser {
  /// Creates the parser.
  BankOfBarodaParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'Bank of Baroda';

  @override
  Set<String> get smsHeaders => const {'BOBTXN', 'BOBSMS', 'BOBCRD', 'BOBCMS'};

  @override
  Set<String> get emailDomains => const {
        'bankofbaroda.com',
        'bankofbaroda.co.in',
        'bobcard.co.in',
        'bankofbaroda.bank.in',
      };

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+Dr\.?\s+from\s+A/C\s+[x*]*(?<acct>\d{3,4})\s+and\s+Cr\.?\s+to\s+(?<vpa>\S+?)\.\s''',
      type: TransactionType.debit,
    ),
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+Cr\.?\s+to\s+A/C\s+[x*]*(?<acct>\d{3,4})\s+from\s+(?<vpa>\S+?)\.\s''',
      type: TransactionType.credit,
    ),
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+spent\s+on\s+your\s+BOBCARD\s+ending\s+(?<acct>\d{4})\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''BOBCARD\s+ending\s+(?<acct>\d{4})\s+has\s+been\s+used\s+for\s+INR\s*(?<amt>%AMT%)\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}

/// Punjab National Bank alerts.
class PnbParser extends BaseBankParser {
  /// Creates the parser.
  PnbParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'Punjab National Bank';

  @override
  Set<String> get smsHeaders => const {'PNBSMS', 'PNBBNK', 'PUNBNK'};

  @override
  Set<String> get emailDomains =>
      const {'pnb.co.in', 'pnb.bank.in', 'pnbindia.in'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''debited\s+INR\s*(?<amt>%AMT%)\s+on\s+\S+\s+by\s+(?:UPI|IMPS)\s+Ref\s+(?<ref>\d{9,14})\s+to\s+(?<merchant>.+?)\.(?:\s|$)''',
      type: TransactionType.debit,
    ),
    Template(
      r'''credited\s+INR\s*(?<amt>%AMT%)\s+on\s+\S+\s+by\s+(?:UPI|IMPS)\s+Ref\s+(?<ref>\d{9,14})\s+from\s+(?<merchant>.+?)\.(?:\s|$)''',
      type: TransactionType.credit,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''PNB\s+Credit\s+Card\s+XX(?<acct>\d{4})\s+has\s+been\s+used\s+for\s+INR\s*(?<amt>%AMT%)\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}

/// AU Small Finance Bank alerts.
class AuBankParser extends BaseBankParser {
  /// Creates the parser.
  AuBankParser([super.config = const ParserConfig()]);

  @override
  String get bankName => 'AU Small Finance Bank';

  @override
  Set<String> get smsHeaders => const {'AUBANK', 'AUSFBL', 'AUBNKK'};

  @override
  Set<String> get emailDomains => const {'aubank.in', 'au.bank.in'};

  @override
  final List<Template> smsTemplates = [
    Template(
      r'''INR\s*(?<amt>%AMT%)\s+debited\s+from\s+AU\s+(?:Small\s+Finance\s+)?Bank\s+A/c\s+XX(?<acct>\d{4})\s+on\s+\S+\s+via\s+(?:UPI|IMPS|NEFT)\s+to\s+(?<merchant>.+?)\.(?:\s|$)''',
      type: TransactionType.debit,
    ),
  ];

  @override
  final List<Template> emailTemplates = [
    Template(
      r'''AU\s+Bank\s+Credit\s+Card\s+XX(?<acct>\d{4})\s+has\s+been\s+used\s+for\s+INR\s*(?<amt>%AMT%)\s+at\s+(?<merchant>.+?)\s+on\s''',
      type: TransactionType.debit,
      accountKind: AccountKind.card,
    ),
  ];
}
