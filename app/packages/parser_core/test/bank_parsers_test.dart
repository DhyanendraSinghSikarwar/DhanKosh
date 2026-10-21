// Every bank parser runs the same checks over its own corpus (FR-06-08,
// AC-06-01). Port of BankParserContract + BankParserTests.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'corpus/au_corpus.dart';
import 'corpus/axis_corpus.dart';
import 'corpus/bob_corpus.dart';
import 'corpus/hdfc_corpus.dart';
import 'corpus/icici_corpus.dart';
import 'corpus/idfc_corpus.dart';
import 'corpus/kotak_corpus.dart';
import 'corpus/pnb_corpus.dart';
import 'corpus/sbi_corpus.dart';
import 'corpus/yes_corpus.dart';
import 'support/corpus.dart';

void verify(BankParser parser, Sample s) {
  final tx = parser.parse(s.body, s.sender, receivedAt, s.source);
  final e = s.expect;
  if (e == null) {
    expect(tx, isNull, reason: 'expected rejection, parsed $tx');
    return;
  }
  expect(tx, isNotNull, reason: 'expected a transaction, got null');
  final t = tx!;
  expect(t.amountMinor, Money.parse(e.amount)!.minor, reason: 'amount');
  expect(t.currency, e.currency, reason: 'currency');
  expect(t.type, e.type, reason: 'type');
  expect(t.accountLast4, e.last4, reason: 'accountLast4');
  expect(t.referenceNumber, e.ref, reason: 'referenceNumber');
  if (e.merchant != null) expect(t.merchant, e.merchant, reason: 'merchant');
  if (e.balance != null) {
    expect(t.balanceMinor, Money.parse(e.balance!)!.minor, reason: 'balance');
  }
  if (e.kind != null) expect(t.accountKind, e.kind, reason: 'accountKind');
  if (e.date != null) {
    expect(istDate(t.transactionTime), e.date, reason: 'date');
  }
}

void contract(
  String name,
  BankParser Function() parser,
  List<Sample> samples,
) {
  group(name, () {
    final registry = ParserRegistry.standard();
    for (final s in samples) {
      test(s.label, () => verify(parser(), s));
    }

    test(
      'corpus has at least 10 sms and 5 email transactions plus otp promo and '
      'failed negatives',
      () {
        final positives = samples.where((s) => s.expect != null);
        expect(
          positives.where((s) => s.source == Source.sms).length,
          greaterThanOrEqualTo(10),
        );
        expect(
          positives.where((s) => s.source == Source.email).length,
          greaterThanOrEqualTo(5),
        );
        final negatives = [
          for (final s in samples)
            if (s.expect == null) s.body.toLowerCase(),
        ];
        expect(
          negatives.any((b) => b.contains('otp') || b.contains('one time password')),
          isTrue,
        );
        expect(
          negatives.any(
            (b) =>
                b.contains('apply now') ||
                b.contains('pre-approved') ||
                b.contains('eligible'),
          ),
          isTrue,
        );
        expect(
          negatives.any(
            (b) =>
                b.contains('declined') ||
                b.contains('failed') ||
                b.contains('unsuccessful'),
          ),
          isTrue,
        );
      },
    );

    test('registry routes every sample sender to this parser', () {
      for (final s in samples) {
        expect(
          registry.resolve(s.sender)?.runtimeType,
          parser().runtimeType,
          reason: s.sender,
        );
      }
    });
  });
}

void main() {
  contract('HdfcBankParser', HdfcBankParser.new, hdfcSamples);
  contract('IciciBankParser', IciciBankParser.new, iciciSamples);
  contract('SbiParser', SbiParser.new, sbiSamples);
  contract('AxisBankParser', AxisBankParser.new, axisSamples);
  contract('KotakBankParser', KotakBankParser.new, kotakSamples);
  contract('IdfcFirstBankParser', IdfcFirstBankParser.new, idfcSamples);
  contract('YesBankParser', YesBankParser.new, yesSamples);
  contract('BankOfBarodaParser', BankOfBarodaParser.new, bobSamples);
  contract('PnbParser', PnbParser.new, pnbSamples);
  contract('AuBankParser', AuBankParser.new, auSamples);
}
