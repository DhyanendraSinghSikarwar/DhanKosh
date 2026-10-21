// NBFC and fintech lenders: EMIs become debits on a loan account; disbursals and
// reminders become loan statuses. Port of LenderParserTest (FR-06-15,
// TC-06-21).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  final registry = ParserRegistry.standard();
  final at = receivedAt;

  test('propelld sms emi received is a debit on the loan account', () {
    final tx = registry.parse(
      'Dear Customer, EMI of Rs.12,345 for your loan a/c no. XXXX1234 has been '
          'received on 05-10-2026. Thank you. - Propelld',
      'VM-PROPLD-S',
      at,
      Source.sms,
    );
    expect(tx, isNotNull);
    expect(tx!.amountMinor, 1234500);
    expect(tx.type, TransactionType.debit);
    expect(tx.bankName, 'Propelld');
    expect(tx.merchant, 'Propelld');
    expect(tx.accountLast4, '1234');
    expect(tx.accountKind, AccountKind.account);
    expect(tx.category, Category.emiLoan);
  });

  test('propelld email takes the last 4 of an alphanumeric loan number', () {
    final tx = registry.parse(
      'Dear Student,\nWe have received your EMI payment of Rs. 8,500.00 '
          'towards your loan account PRPL0012345 on 05-10-2026.\nThank you,\n'
          'Team Propelld',
      'Propelld <noreply@propelld.com>',
      at,
      Source.email,
    );
    expect(tx, isNotNull);
    expect(tx!.amountMinor, 850000);
    expect(tx.accountLast4, '2345');
    expect(tx.category, Category.emiLoan);
  });

  test('propelld reminder is not a transaction but names the loan', () {
    const body =
        'Your EMI of Rs 8,500 towards Loan Account No. PROP12345 is due on '
        '05-Nov-2026. Please keep sufficient balance. - Propelld';
    expect(registry.parse(body, 'VM-PROPLD', at, Source.sms), isNull);
    final s = registry.loanStatus(body, 'VM-PROPLD', at, Source.sms);
    expect(s, LoanStatus('Propelld', '2345', null, null, at));
  });

  test('future emi debit is not a payment', () {
    const body =
        'Your EMI of Rs 8,500 for loan a/c XXXX1234 will be debited on '
        '05-11-2026. - Propelld';
    expect(registry.parse(body, 'VM-PROPLD', at, Source.sms), isNull);
    expect(
      registry.loanStatus(body, 'VM-PROPLD', at, Source.sms)?.last4,
      '1234',
    );
  });

  test('disbursal sets the principal and the outstanding amount', () {
    const body =
        'Congratulations! Loan of Rs 2,00,000 has been disbursed to your '
        'account. Loan A/c XXXX5678. - Propelld';
    expect(registry.parse(body, 'JD-PRPLDF', at, Source.sms), isNull);
    final s = registry.loanStatus(body, 'JD-PRPLDF', at, Source.sms);
    expect(s, LoanStatus('Propelld', '5678', 20000000, 20000000, at));
  });

  test(
      'abcd emi debit carries the outstanding principal as the loan '
      'balance', () {
    final tx = registry.parse(
      'Dear Customer, Rs 8,500 debited towards EMI for loan LAN ABCD000123 on '
          '05-10-2026. Outstanding principal Rs 1,45,000. - Aditya Birla Capital',
      'AX-ABCDAP-S',
      at,
      Source.sms,
    );
    expect(tx, isNotNull);
    expect(tx!.amountMinor, 850000);
    expect(tx.bankName, 'Aditya Birla Capital');
    expect(tx.accountLast4, '0123');
    expect(tx.balanceMinor, 14500000);
    expect(tx.category, Category.emiLoan);
  });

  test('abcd email from the app subdomain', () {
    final tx = registry.parse(
      'Dear Customer,\nThank you for your payment of Rs. 9,200.00 towards your '
          'Personal Loan Account No. ABFL0098765. Your outstanding principal is '
          'Rs. 1,20,000.00.\nRegards,\nAditya Birla Capital',
      'ABCD <noreply@abcd.adityabirlacapital.com>',
      at,
      Source.email,
    );
    expect(tx, isNotNull);
    expect(tx!.amountMinor, 920000);
    expect(tx.accountLast4, '8765');
    expect(tx.balanceMinor, 12000000);
  });

  test('otp promo and bounce are ignored', () {
    const cases = [
      (
        '123456 is your OTP to sign the loan agreement for Loan A/c XXXX5678. '
            'Do not share. - Propelld',
        'VM-PROPLD',
      ),
      (
        'You are eligible for a pre-approved Personal Loan of Rs 3,00,000 from '
            'ABCD. Apply now',
        'VM-ABCDAP',
      ),
      (
        'EMI of Rs 8,500 for loan a/c XXXX1234 has bounced. Pay now to avoid '
            'charges. - Aditya Birla Capital',
        'VM-ABCLTD',
      ),
    ];
    for (final (body, sender) in cases) {
      expect(
        registry.parse(body, sender, at, Source.sms),
        isNull,
        reason: body,
      );
      expect(
        registry.loanStatus(body, sender, at, Source.sms),
        isNull,
        reason: body,
      );
    }
  });

  test(
      'nach debit from a bank to a lender is an EMI named like the '
      'lender', () {
    final hdfc = registry.parse(
      'UPDATE: INR 8,500.00 debited from HDFC Bank XX4321 on 05-OCT-26. Info: '
          'ACH D- TP ACH PROPELLD-1234567. Avl bal:INR 23,410.00',
      'VM-HDFCBK',
      at,
      Source.sms,
    );
    expect(hdfc, isNotNull);
    expect(hdfc!.type, TransactionType.debit);
    expect(hdfc.merchant, 'Propelld');
    expect(hdfc.category, Category.emiLoan);
    expect(hdfc.channel, Channel.autoDebit);

    final au = registry.parse(
      'INR 9,200.00 debited from AU Bank A/c XX1234 on 05-Sep-26 towards '
          'NACH-ADITYA BIRLA FINANCE. Bal INR 44,491.50',
      'VM-AUBANK',
      at,
      Source.sms,
    );
    expect(au, isNotNull);
    expect(au!.merchant, 'Aditya Birla Capital');
    expect(au.category, Category.emiLoan);
  });

  test('lenders are registered for sms and email', () {
    expect(registry.resolve('VM-PROPLD'), isA<LenderParser>());
    expect(registry.resolve('AD-ABCLTD-S'), isA<LenderParser>());
    expect(registry.resolve('x@adityabirlacapital.com'), isA<LenderParser>());
    expect(Lenders.isLender('Aditya Birla Capital'), isTrue);
    expect(Lenders.isLender('HDFC Bank'), isFalse);
    final senders = registry.defaultEmailSenders;
    for (final d in [
      'propelld.com',
      'adityabirlacapital.com',
      'abcd.adityabirlacapital.com',
      'bajajfinserv.in',
    ]) {
      expect(senders, contains(d), reason: d);
    }
  });
}
