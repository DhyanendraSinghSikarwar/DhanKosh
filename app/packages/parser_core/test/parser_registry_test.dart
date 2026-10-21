// Port of ParserRegistryTest (FR-02..FR-04, TC-06-03..05).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

class _HdfcClone extends BaseBankParser {
  @override
  String get bankName => 'Clone';
  @override
  Set<String> get smsHeaders => const {'HDFCBK'};
  @override
  Set<String> get emailDomains => const {};
}

void main() {
  final registry = ParserRegistry.standard();

  test('sms headers resolve regardless of operator prefix and suffix', () {
    for (final s in [
      'VM-HDFCBK',
      'AD-HDFCBK-S',
      'JD-HDFCBK-T',
      'HDFCBK',
      'vm-hdfcbk',
    ]) {
      expect(registry.resolve(s).runtimeType, HdfcBankParser, reason: s);
    }
  });

  test('email senders resolve by address, domain, or parent domain', () {
    expect(
      registry.resolve('HDFC Bank <alerts@hdfcbank.net>').runtimeType,
      HdfcBankParser,
    );
    expect(
      registry.resolve('alerts@hdfcbank.bank.in').runtimeType,
      HdfcBankParser,
    );
    expect(
      registry.resolve('donotreply.sbiatm@alerts.sbi.co.in').runtimeType,
      SbiParser,
    );
    expect(registry.resolve('x@mail.sbi.co.in').runtimeType, SbiParser);
  });

  test('unknown senders are filtered out before parsing', () {
    expect(registry.isKnownSender('VM-AMAZON'), isFalse);
    expect(registry.isKnownSender('+919876543210'), isFalse);
    expect(registry.isKnownSender('offers@shopping.com'), isFalse);
    expect(registry.isKnownSender('AX-ICICIB'), isTrue);
  });

  test(
      'accepts is true for registered keys and generic bank-looking '
      'headers, false for shops (TC-06-05)', () {
    for (final s in ['VM-HDFCBK', 'AX-ICICIB', 'VM-ZZXBNK', 'AD-AMEXIN']) {
      expect(registry.accepts(s), isTrue, reason: s);
    }
    for (final s in ['VM-AMAZON', 'JD-PIZZA', '+919876543210']) {
      expect(registry.accepts(s), isFalse, reason: s);
    }
    // Every header and domain of the standard parsers is accepted.
    for (final p in registry.parsers) {
      for (final k in p.senderKeys) {
        final sender = k.contains('@') || !k.contains('.') ? k : 'a@$k';
        expect(registry.accepts(sender), isTrue, reason: k);
      }
    }
  });

  test('the generic parser takes bank-looking senders nobody claims', () {
    final tx = registry.parse(
      'INR 500.00 debited from A/c XX4321 on 24-09-26 to SWIGGY. UPI Ref '
          '526812340000',
      'VM-ZZXBNK',
      receivedAt,
      Source.sms,
    );
    expect(tx, isNotNull);
    expect(tx!.bankName, 'ZZXBNK');
    expect(tx.accountLast4, '4321');
    expect(tx.merchant, 'Swiggy');
  });

  test('the generic parser ignores senders that are not banks', () {
    expect(
      registry.parse(
        'INR 500.00 debited from A/c XX4321 on 24-09-26',
        'VM-SWIGGY',
        receivedAt,
        Source.sms,
      ),
      isNull,
    );
  });

  test('default email whitelist covers every bank', () {
    final senders = registry.defaultEmailSenders;
    for (final d in [
      'hdfcbank.net',
      'icicibank.com',
      'sbi.co.in',
      'axisbank.com',
      'kotak.com',
      'idfcfirstbank.com',
      'yesbank.in',
      'bankofbaroda.co.in',
      'pnb.co.in',
      'aubank.in',
    ]) {
      expect(senders, contains(d), reason: d);
    }
  });

  test('two parsers may not claim the same key', () {
    expect(
      () => ParserRegistry([HdfcBankParser(), _HdfcClone()]),
      throwsArgumentError,
    );
  });

  test('sender keys', () {
    expect(SenderKeys.candidates('VM-HDFCBK-S'), ['HDFCBK']);
    expect(SenderKeys.candidates('SBI <a@alerts.sbi.co.in>'), [
      'a@alerts.sbi.co.in',
      'alerts.sbi.co.in',
      'sbi.co.in',
      'co.in',
    ]);
    expect(SenderKeys.candidates('  '), <String>[]);
    expect(
        SenderKeys.candidates('HDFC Bank InstaAlerts <alerts@hdfcbank.net>'), [
      'alerts@hdfcbank.net',
      'hdfcbank.net',
    ]);
  });

  test('smsHeader vectors (TC-06-03)', () {
    expect(SenderKeys.smsHeader('VM-HDFCBK-S'), 'HDFCBK');
    expect(SenderKeys.smsHeader('AX-ICICIB-T'), 'ICICIB');
    expect(SenderKeys.smsHeader('HDFCBK'), 'HDFCBK');
    expect(SenderKeys.smsHeader('JD-AB'), 'AB');
    expect(SenderKeys.smsHeader('A-B-CDE'), 'B');
    expect(SenderKeys.smsHeader(''), '');
  });

  test('statement subjects are fetched by subject', () {
    expect(
      ParserRegistry.isStatementSubject('Fixed Deposit Advice - A/c XX7777'),
      isTrue,
    );
    expect(
      ParserRegistry.isStatementSubject('Your PPF account statement'),
      isTrue,
    );
    expect(
      ParserRegistry.isStatementSubject('Your weekly portfolio summary'),
      isTrue,
    );
    expect(ParserRegistry.isStatementSubject('Your Swiggy order'), isFalse);
    expect(ParserRegistry.isStatementSubject(null), isFalse);
  });
}
