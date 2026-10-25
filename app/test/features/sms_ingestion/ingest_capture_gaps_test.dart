// FR-16-19..21 MF orders and NPS contributions, FR-13 deposit and FR-15-13
// loan status messages recorded by the ingest pipeline.
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:hisaab/features/statement_import/data/statement_account_store_impl.dart';
import 'package:hisaab/features/statement_import/domain/usecases/apply_statement_accounts.dart';
import 'package:parser_core/parser_core.dart' show Source;

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late IngestMessage ingest;
  late HoldingRepositoryImpl holdings;
  final t0 = DateTime(2026, 10, 20, 11, 15).millisecondsSinceEpoch;
  final day = DateTime(2026, 10, 20).millisecondsSinceEpoch;

  setUp(() {
    env = TestEnv();
    holdings = HoldingRepositoryImpl(env.db);
    ingest = IngestMessage(
      ledger: env.txs,
      holdings: holdings,
      accounts: ApplyStatementAccounts(StatementAccountStoreImpl(env.db)),
    );
  });
  tearDown(() => env.close());

  InboxSms sms(String body, String sender) => InboxSms(
        sender: sender,
        body: body,
        receivedAt: t0,
        sentAt: t0,
      );

  MfOrderEntry order({int at = 0, double? units = 10, double? nav = 100}) =>
      MfOrderEntry(
        schemeName: 'Parag Parikh Flexi Cap Fund',
        identifier: 'MF:PARAG PARIKH FLEXI CAP',
        at: at == 0 ? day : at,
        amountMinor: 100000,
        units: units,
        nav: nav,
      );

  group('recordMfOrder (FR-16-19)', () {
    test('new fund inserts units, invested and value', () async {
      expect(await holdings.recordMfOrder(order(), claimKey: 'a'), isTrue);
      final h = (await holdings.list()).single;
      expect(h.units, 10);
      expect(h.investedMinor, 100000);
      expect(h.valueMinor, 100000);
    });

    test('same claim key or same order is applied once', () async {
      await holdings.recordMfOrder(order(), claimKey: 'a');
      expect(await holdings.recordMfOrder(order(), claimKey: 'a'), isFalse);
      expect(await holdings.recordMfOrder(order(), claimKey: 'b'), isFalse);
      expect((await holdings.list()).single.units, 10);
    });

    test('existing fund adds units and invested, value = units x NAV',
        () async {
      await holdings.recordMfOrder(order(), claimKey: 'a');
      await holdings.recordMfOrder(
        order(at: day + 86400000 * 30, nav: 110),
        claimKey: 'b',
      );
      final h = (await holdings.list()).single;
      expect(h.units, 20);
      expect(h.investedMinor, 200000);
      expect(h.valueMinor, 220000);
    });

    test('statement dated on or after the order already counts it', () async {
      await holdings.record(
        [
          HoldingSnapshot(
            kind: HoldingKind.mutualFund,
            name: 'Parag Parikh Flexi Cap Fund',
            identifier: 'MF:PARAG PARIKH FLEXI CAP',
            asOf: day + 1000,
            units: 50,
            valueMinor: 500000,
          ),
        ],
        HoldingSource.statement,
      );
      expect(await holdings.recordMfOrder(order(), claimKey: 'a'), isFalse);
      final h = (await holdings.list()).single;
      expect(h.units, 50);
      expect(h.investedMinor, isNull);
    });
  });

  group('recordNpsContribution (FR-16-20, FR-16-21)', () {
    NpsContributionEntry c(int at, {String key = 'k1'}) => NpsContributionEntry(
          identifier: 'NPS:1234',
          name: 'NPS ••1234',
          amountMinor: 500000,
          at: at,
          key: key,
        );

    test('existing holding adds to invested and value; once per key', () async {
      await holdings.recordNpsContribution(c(day));
      expect(await holdings.recordNpsContribution(c(day)), isFalse);
      await holdings.recordNpsContribution(c(day + 1000, key: 'k2'));
      final h = (await holdings.list()).single;
      expect(h.investedMinor, 1000000);
      expect(h.valueMinor, 1000000);
    });

    test('statement dated on or after the contribution wins', () async {
      await holdings.record(
        [
          HoldingSnapshot(
            kind: HoldingKind.nps,
            name: 'NPS ••1234',
            identifier: 'NPS:1234',
            asOf: day + 5000,
            valueMinor: 9000000,
            investedMinor: 8000000,
          ),
        ],
        HoldingSource.statement,
      );
      expect(await holdings.recordNpsContribution(c(day)), isFalse);
      expect((await holdings.list()).single.investedMinor, 8000000);
    });

    test('claim set is capped at 500 keys', () async {
      for (var i = 0; i < 501; i++) {
        await holdings.recordNpsContribution(c(day, key: 'k$i'));
      }
      // k0 was trimmed, so it can be claimed again; k500 cannot.
      expect(
        await holdings.recordNpsContribution(c(day, key: 'k500')),
        isFalse,
      );
      expect(await holdings.recordNpsContribution(c(day, key: 'k0')), isTrue);
    });
  });

  group('pipeline', () {
    const nps = 'Dear Subscriber, Contribution of Rs.5000.00 for PRAN '
        'XXXXXXXX1234 has been credited to your Tier I account on 20-10-2026 '
        'and units allotted. -NPSCRA';

    test('NPS contribution with a bank debit nearby adds no transaction',
        () async {
      await ingest.detail(
        sms(
          'Rs.5000.00 debited from HDFC Bank A/c XX2779 on 19-10-26 towards '
              'NPS. UPI Ref 529912340111',
          'VM-HDFCBK',
        ),
      );
      expect(await env.count('transactions'), 1);
      await ingest.detail(sms(nps, 'AX-NPSCRA'));
      expect(await env.count('transactions'), 1);
      expect((await holdings.list()).single.investedMinor, 500000);
    });

    test('NPS contribution via email is claimed once with the SMS', () async {
      await ingest.detail(sms(nps, 'AX-NPSCRA'));
      await ingest.detail(
        sms(nps, 'noreply@npscra.in'),
        source: Source.email,
      );
      expect((await holdings.list()).single.investedMinor, 500000);
    });

    test('lender disbursal then outstanding updates one loan account',
        () async {
      await ingest.detail(
        sms(
          'Congratulations! Loan of Rs 2,00,000 has been disbursed to your '
              'account. Loan A/c XXXX5678. - Propelld',
          'VM-PROPLD',
        ),
      );
      final rows = await env.db
          .customSelect(
            'SELECT account_type, loan_principal_minor, latest_balance_minor '
            "FROM accounts WHERE last4 = '5678'",
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.data['account_type'], anyOf('LOAN', 'loan'));
      expect(rows.single.data['loan_principal_minor'], 20000000);
      expect(rows.single.data['latest_balance_minor'], 20000000);
      expect(await env.count('transactions'), 0);
    });

    test('without the accounts use case a status SMS is ignored', () async {
      final plain = IngestMessage(ledger: env.txs, holdings: holdings);
      final d = await plain.detail(
        sms(
          'Congratulations! Loan of Rs 2,00,000 has been disbursed to your '
              'account. Loan A/c XXXX5678. - Propelld',
          'VM-PROPLD',
        ),
      );
      expect(d.outcome.name, 'rejected');
      expect(await env.count('accounts'), 0);
    });
  });
}
