// Balances and limits follow the messages (FR-13-24, FR-14-29): a stated
// balance or limit wins, anything after it moves it, a card spend lowers the
// limit left and a card payment raises it. Synthetic data.
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<AccountWithActivity> only() async {
    final all = await env.accounts
        .watchWithActivity(monthStartMs: 0, monthEndMs: t0 + 400 * hour)
        .first;
    return all.single;
  }

  // FR-13-28
  group('own-account transfers move both balances', () {
    Future<Map<String, int?>> balances() async {
      final all = await env.accounts
          .watchWithActivity(monthStartMs: 0, monthEndMs: t0 + 400 * hour)
          .first;
      return {for (final a in all) a.account.last4: a.currentBalanceMinor};
    }

    test('a message naming the other own account', () async {
      await env.ingest(
        parsed(
          amountMinor: 100,
          ref: 'seed1',
          balance: 1000000,
          time: t0 - 2 * hour,
        ),
      );
      await env.ingest(
        parsed(
          bank: 'ICICI Bank',
          last4: '5678',
          type: TransactionType.credit,
          amountMinor: 100,
          ref: 'seed2',
          balance: 500000,
          time: t0 - 2 * hour,
        ),
      );
      await env.ingest(
        parsed(counterparty: '5678', amountMinor: 200000, ref: 'xfer0001'),
      );
      final b = await balances();
      expect(b['1234'], 800000);
    });

    test('two paired legs: out of one, into the other', () async {
      await env.ingest(
        parsed(
          amountMinor: 100,
          ref: 'seed1',
          balance: 1000000,
          time: t0 - 2 * hour,
        ),
      );
      await env.ingest(
        parsed(
          bank: 'ICICI Bank',
          last4: '5678',
          type: TransactionType.credit,
          amountMinor: 100,
          ref: 'seed2',
          balance: 500000,
          time: t0 - 2 * hour,
        ),
      );
      await env.ingest(parsed(amountMinor: 300000, ref: 'leg00001'));
      await env.ingest(
        parsed(
          bank: 'ICICI Bank',
          last4: '5678',
          type: TransactionType.credit,
          amountMinor: 300000,
          ref: null,
          time: t0 + 10 * minute,
        ),
      );
      final b = await balances();
      expect(b['1234'], 700000);
      expect(b['5678'], 800000);
    });
  });

  group('bank account', () {
    test(
        'a stated balance is kept, later messages move it, a newer stated '
        'balance replaces it', () async {
      await env.ingest(parsed(amountMinor: 10000, ref: 'a', balance: 100000));
      expect((await only()).currentBalanceMinor, 100000);

      await env.ingest(
        parsed(amountMinor: 20000, ref: 'b', time: t0 + hour),
      );
      expect((await only()).currentBalanceMinor, 80000);

      await env.ingest(
        parsed(
          amountMinor: 50000,
          type: TransactionType.credit,
          ref: 'c',
          time: t0 + 2 * hour,
        ),
      );
      expect((await only()).currentBalanceMinor, 130000);

      await env.ingest(
        parsed(
          amountMinor: 5000,
          ref: 'd',
          time: t0 + 3 * hour,
          balance: 125000,
        ),
      );
      expect((await only()).currentBalanceMinor, 125000);
    });

    test('an older message arriving late never rewinds the balance', () async {
      await env.ingest(
        parsed(
          amountMinor: 5000,
          ref: 'new',
          time: t0 + 5 * hour,
          balance: 90000,
        ),
      );
      await env.ingest(
        parsed(amountMinor: 7000, ref: 'old', balance: 200000),
      );
      expect((await only()).currentBalanceMinor, 90000);
    });
  });

  group('credit card', () {
    AccountKind cardKind() => AccountKind.card;

    test('the first spend creates a credit card even with no limit stated',
        () async {
      await env.ingest(
        parsed(
          bank: 'SBI',
          kind: cardKind(),
          amountMinor: 125000,
          ref: 'sbi1',
        ),
      );
      final a = await only();
      expect(a.account.kind, AccountKind.card);
      expect(a.account.accountType, AccountType.creditCard);
    });

    test(
        'spends lower the limit left, a payment raises it, a stated limit '
        'replaces it', () async {
      await env.ingest(
        parsed(
          bank: 'SBI',
          kind: cardKind(),
          amountMinor: 100000,
          ref: 'c1',
          limit: 5000000,
        ),
      );
      expect((await only()).currentBalanceMinor, 5000000);

      await env.ingest(
        parsed(
          bank: 'SBI',
          kind: cardKind(),
          amountMinor: 120000,
          ref: 'c2',
          time: t0 + hour,
        ),
      );
      expect((await only()).currentBalanceMinor, 4880000);

      await env.ingest(
        parsed(
          bank: 'SBI',
          kind: cardKind(),
          amountMinor: 100000,
          type: TransactionType.transfer,
          ref: 'pay',
          time: t0 + 2 * hour,
          merchant: null,
        ),
      );
      expect((await only()).currentBalanceMinor, 4980000);

      await env.ingest(
        parsed(
          bank: 'SBI',
          kind: cardKind(),
          amountMinor: 30000,
          ref: 'c3',
          time: t0 + 3 * hour,
          limit: 4900000,
        ),
      );
      expect((await only()).currentBalanceMinor, 4900000);
    });
  });
}
