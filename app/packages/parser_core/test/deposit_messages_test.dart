// FD, RD and PPF messages, end to end through the registry: the deposit status
// they give (account, balance, maturity, renew or pay out) and whether they
// also count as a transaction. Port of DepositMessagesTest (FR-06-15,
// TC-06-21).
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'support/corpus.dart';

void main() {
  final registry = ParserRegistry.standard();

  LoanStatus? status(
    String body,
    String sender, [
    Source source = Source.sms,
  ]) =>
      registry.loanStatus(body, sender, receivedAt, source);

  test(
      'HDFC FD booking SMS opens an FD with principal, rate, maturity and '
      'amount', () {
    const body =
        'Your FD No. XXXXXXXX5678 for INR 1,00,000.00 has been booked on '
        '24-09-2026 for 1 year at 7.10% p.a. Maturity date: 24-09-2027. '
        'Maturity amount INR 1,07,281.00. It will be auto renewed on '
        'maturity. -HDFC Bank';
    final s = status(body, 'VM-HDFCBK');
    expect(s, isNotNull);
    final d = s!.deposit!;
    expect(s.lender, 'HDFC Bank');
    expect(s.last4, '5678');
    expect(d.kind, DepositKind.fd);
    expect(s.principalMinor, 10000000);
    expect(s.outstandingMinor, 10000000);
    expect(d.rateBps, 710);
    expect(d.maturity, const CivilDate(2027, 9, 24));
    expect(d.maturityAmountMinor, 10728100);
    expect(d.action, DepositAction.renewAll);
    expect(d.closed, isFalse);
    // The advice is about the deposit, not money moving on a bank account.
    expect(registry.parse(body, 'VM-HDFCBK', receivedAt, Source.sms), isNull);
  });

  test('SBI term deposit opened with payout on maturity', () {
    final s = status(
      'Dear Customer, your Term Deposit A/c no. XXXXX4321 has been opened for '
          'Rs.50,000 with maturity date 12-Mar-2027 and maturity value Rs. '
          '53,550. Proceeds will be credited to your SB a/c on maturity. -SBI',
      'AD-SBIINB',
    )!;
    expect(s.last4, '4321');
    expect(s.outstandingMinor, 5000000);
    expect(s.deposit!.maturity, const CivilDate(2027, 3, 12));
    expect(s.deposit!.maturityAmountMinor, 5355000);
    expect(s.deposit!.action, DepositAction.payout);
    expect(s.deposit!.closed, isFalse);
  });

  test('ICICI FD renewal gives the new maturity', () {
    final s = status(
      'Dear Customer, your Fixed Deposit XX9876 of Rs 2,00,000 has been '
          'renewed for 12 months at 6.90% p.a. New maturity date 15-Oct-2027. '
          '-ICICI Bank',
      'JD-ICICIB',
    )!;
    expect(s.last4, '9876');
    expect(s.deposit!.kind, DepositKind.fd);
    expect(s.outstandingMinor, 20000000);
    expect(s.deposit!.maturity, const CivilDate(2027, 10, 15));
    expect(s.deposit!.action, DepositAction.renewAll);
    expect(s.deposit!.rateBps, 690);
  });

  test('FD matured and paid out is closed', () {
    final s = status(
      'Your FD A/c XX5678 has matured on 24-09-2026 and the proceeds of INR '
          '1,07,281.00 have been credited to your A/c XX1234. -HDFC Bank',
      'VM-HDFCBK',
    )!;
    expect(s.last4, '5678');
    expect(s.deposit!.closed, isTrue);
    expect(s.outstandingMinor, isNull);
    expect(s.deposit!.maturity, const CivilDate(2026, 9, 24));
  });

  test('RD instalment SMS gives the running balance, not the instalment', () {
    final s = status(
      'RD A/c XX9012: instalment of Rs 5,000 received on 24-09-2026. Total '
          'balance Rs 60,000. Maturity date 01-Apr-2028. -Axis Bank',
      'VM-AXISBK',
    )!;
    expect(s.deposit!.kind, DepositKind.rd);
    expect(s.last4, '9012');
    expect(s.outstandingMinor, 6000000);
    expect(s.deposit!.maturity, const CivilDate(2028, 4, 1));
  });

  test(
      'PPF deposit and interest SMS update the PPF balance and are not '
      'income', () {
    const deposit =
        'Rs.10,000.00 deposited in PPF A/c No. XXXX3456 on 05-09-2026. '
        'Available Bal Rs 2,55,678.00 -SBI';
    final s = status(deposit, 'AD-SBIINB')!;
    expect(s.deposit!.kind, DepositKind.ppf);
    expect(s.last4, '3456');
    expect(s.outstandingMinor, 25567800);
    expect(
      registry.parse(deposit, 'AD-SBIINB', receivedAt, Source.sms),
      isNull,
    );

    const interest =
        'Your PPF A/c XXXXXXX3456 has been credited with interest of Rs. '
        '12,345.00 on 31-03-2026. Balance: Rs. 2,45,678.00 -SBI';
    final i = status(interest, 'AD-SBIINB')!;
    expect(i.outstandingMinor, 24567800);
    expect(i.deposit!.closed, isFalse);
  });

  test('India Post PPF from a generic sender is named India Post', () {
    final s = status(
      'Dear Customer, Rs 5000 deposited in your PPF a/c ending 3456 on '
          '03/09/2026. Balance Rs 1,50,000. - India Post',
      'VM-DOPBNK',
    );
    expect(s, isNotNull);
    expect(s!.lender, 'India Post');
    expect(s.outstandingMinor, 15000000);
  });

  test(
      'a savings debit towards an RD stays a transaction on the savings '
      'account', () {
    const body =
        'INR 5,000.00 debited from A/c XX1234 on 24-09-26 towards RD A/c '
        'XX9012. Avl bal INR 45,000.00 -HDFC Bank';
    final tx = registry.parse(body, 'VM-HDFCBK', receivedAt, Source.sms);
    expect(tx, isNotNull);
    expect(tx!.accountLast4, '1234');
    expect(tx.amountMinor, 500000);
    expect(
      tx.type == TransactionType.debit || tx.type == TransactionType.investment,
      isTrue,
    );
    // ... and still tells about the RD.
    expect(status(body, 'VM-HDFCBK')!.last4, '9012');
  });

  test('FD offers and OTPs are not deposits', () {
    expect(
      status(
        'Book an FD online and earn up to 7.75% p.a. Apply now: hdfcbk.io/fd',
        'VM-HDFCBK',
      ),
      isNull,
    );
    expect(
      status(
        '123456 is the OTP to book your Fixed Deposit of Rs 50,000. Do not '
            'share. -ICICI Bank',
        'JD-ICICIB',
      ),
      isNull,
    );
    expect(
      status(
        'Rs.500 debited from A/c XX1234 for FD booking charges',
        'VM-HDFCBK',
      ),
      isNull,
    );
  });

  test('FD advice email from a bank, with an offer in its footer', () {
    const body = 'Dear Customer,\n'
        'Thank you for opening a Fixed Deposit with us. Your Fixed Deposit '
        'A/c No. 50300012347777 for Rs. 3,00,000.00 has been booked.\n'
        'Rate of interest: 7.25% p.a. Maturity Date: 05-Oct-2028. Maturity '
        'Amount: Rs. 3,46,512.00. Maturity instruction: Auto renewal of '
        'principal and interest.\n'
        'Regards,\n'
        'HDFC Bank. Book an FD now and earn up to 7.75%.';
    final s = status(body, 'HDFC Bank <alerts@hdfcbank.net>', Source.email)!;
    expect(s.last4, '7777');
    expect(s.outstandingMinor, 30000000);
    expect(s.deposit!.rateBps, 725);
    expect(s.deposit!.maturity, const CivilDate(2028, 10, 5));
    expect(s.deposit!.maturityAmountMinor, 34651200);
    expect(s.deposit!.action, DepositAction.renewAll);
    expect(
      registry.parse(
        body,
        'HDFC Bank <alerts@hdfcbank.net>',
        receivedAt,
        Source.email,
      ),
      isNull,
    );
  });

  test('deposit advices and summaries are fetched by subject', () {
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
  });

  test('lender messages still give loan status', () {
    final s = registry.loanStatus(
      'Dear Customer, your loan a/c no. PROP12345 has been disbursed. Loan '
          'amount Rs 2,00,000. -Propelld',
      'VM-PROPLD',
      receivedAt,
      Source.sms,
    );
    expect(s, isNotNull);
    expect(s!.deposit, isNull);
  });

  test('deposit dates parse the spellings of advices', () {
    expect(DepositParser.parseDate('24-09-2027'), const CivilDate(2027, 9, 24));
    expect(DepositParser.parseDate('24/9/27'), const CivilDate(2027, 9, 24));
    expect(
      DepositParser.parseDate('12-Mar-2027'),
      const CivilDate(2027, 3, 12),
    );
    expect(
      DepositParser.parseDate('12th March 2027'),
      const CivilDate(2027, 3, 12),
    );
    expect(
      DepositParser.parseDate('Mar 12, 2027'),
      const CivilDate(2027, 3, 12),
    );
    expect(DepositParser.parseDate('2027-03-12'), const CivilDate(2027, 3, 12));
    expect(DepositParser.parseDate('nonsense'), isNull);
    // A day past the end of the month is clamped, as Java's smart resolver does.
    expect(DepositParser.parseDate('31-02-2027'), const CivilDate(2027, 2, 28));
  });
}
