// The extra dedup checks through the real ledger: references, balances and
// two payment apps (FR-07-19, FR-07-20, FR-07-21). Synthetic data.
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/test_env.dart';

const _min = 60000;
const _t0 = 1790310600000;

ParsedTransaction _tx({
  required int amount,
  Source source = Source.sms,
  TransactionType type = TransactionType.debit,
  String? last4 = '1234',
  String? ref,
  String? merchant,
  int? balance,
  int at = 0,
  String sender = 'VM-HDFCBK',
}) =>
    ParsedTransaction(
      amountMinor: amount,
      currency: 'INR',
      type: type,
      bankName: 'HDFC Bank',
      accountLast4: last4,
      accountKind: AccountKind.account,
      merchant: merchant,
      upiId: null,
      referenceNumber: ref,
      channel: Channel.upi,
      balanceMinor: balance,
      availableLimitMinor: null,
      transactionTime: _t0 + at,
      hasExplicitTime: false,
      category: Category.other,
      source: source,
      sender: sender,
      messageTimestamp: _t0 + at,
      confidence: 0.9,
      transactionHash: TransactionHasher.hash(
        amount,
        type,
        last4,
        civilDateOf(_t0 + at, const Duration(hours: 5, minutes: 30)),
        ref,
      ),
    );

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<int> flagged() async => (await env.db
          .customSelect(
            'SELECT COUNT(*) AS c FROM transactions WHERE needs_review = 1',
          )
          .getSingle())
      .read<int>('c');

  test('two ₹20 teas whose balances step by ₹20 are both recorded, unflagged',
      () async {
    final a = await env.ingest(_tx(amount: 2000, balance: 98000), id: 'm1');
    final b = await env.ingest(
      _tx(amount: 2000, balance: 96000, at: 2 * _min),
      id: 'm2',
    );
    expect(a.outcome, IngestOutcome.inserted);
    expect(b.outcome, IngestOutcome.inserted);
    expect(await env.count('transactions'), 2);
    expect(await flagged(), 0);
  });

  test('the same message with a new id and the same balance is one row',
      () async {
    await env.ingest(_tx(amount: 2000, balance: 98000), id: 'm1');
    final again = await env.ingest(
      _tx(amount: 2000, balance: 98000, at: 20 * _min),
      id: 'm2',
    );
    expect(again.outcome, IngestOutcome.merged);
    expect(await env.count('transactions'), 1);
  });

  test('a reference written with a prefix still finds its payment', () async {
    await env.ingest(_tx(amount: 50000, ref: '612345678901'), id: 'sms1');
    final r = await env.ingest(
      _tx(
        amount: 50000,
        ref: 'UPI612345678901',
        source: Source.statement,
        last4: null,
        at: 2 * 60 * 60000,
      ),
      id: 'stmt1',
    );
    expect(r.outcome, IngestOutcome.merged);
    expect(await env.count('transactions'), 1);
  });

  test('the same reference on money coming back is a second row', () async {
    await env.ingest(_tx(amount: 75000, ref: '612345678901'), id: 'out');
    final back = await env.ingest(
      _tx(
        amount: 75000,
        ref: '612345678901',
        type: TransactionType.credit,
        at: 24 * 60 * _min,
      ),
      id: 'in',
    );
    expect(back.outcome, IngestOutcome.inserted);
    expect(await env.count('transactions'), 2);
  });

  test('a bank app and Google Pay for one payment make one row', () async {
    await env.ingest(
      _tx(
        amount: 25000,
        source: Source.app,
        sender: 'Google Pay',
        last4: null,
        merchant: 'Raju',
      ),
      id: 'app:gpay',
    );
    final r = await env.ingest(
      _tx(
        amount: 25000,
        source: Source.app,
        sender: 'HDFC Bank',
        last4: null,
        merchant: 'Raju',
        at: 1 * _min,
      ),
      id: 'app:hdfc',
    );
    expect(r.outcome, IngestOutcome.merged);
    expect(await env.count('transactions'), 1);
    // The two apps are two sources of one row, so Split stays possible.
    expect(await env.count('transaction_sources'), 2);
  });
}
