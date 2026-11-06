// Ignored accounts: their messages are dropped at ingest (FR-13-22).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/data/account_admin_repository_impl.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/test_env.dart';

ParsedTransaction _tx(String last4, {int at = 0}) => ParsedTransaction(
      amountMinor: 12000,
      currency: 'INR',
      type: TransactionType.debit,
      bankName: 'HDFC Bank',
      accountLast4: last4,
      accountKind: AccountKind.account,
      merchant: 'Cafe',
      upiId: null,
      referenceNumber: null,
      channel: Channel.upi,
      balanceMinor: null,
      availableLimitMinor: null,
      transactionTime: 1790310600000 + at,
      hasExplicitTime: false,
      category: Category.other,
      source: Source.sms,
      sender: 'VM-HDFCBK',
      messageTimestamp: 1790310600000 + at,
      confidence: 0.9,
      transactionHash: 'h$last4$at',
    );

void main() {
  late TestEnv env;
  late AccountAdminRepositoryImpl admin;
  setUp(() {
    env = TestEnv();
    admin = env.adminForTest;
  });
  tearDown(() => env.close());

  test('an ignored account drops its messages; others are untouched', () async {
    await env.ingest(_tx('1111'), id: 'a');
    final id = (await env.db.select(env.db.accounts).getSingle()).id;
    await admin.ignore(id);
    await env.accounts.delete(id);
    expect(await admin.isIgnored('HDFC Bank', '1111'), isTrue);

    final dropped = await env.ingest(_tx('1111', at: 86400000), id: 'b');
    expect(dropped.outcome, IngestOutcome.skipped);
    expect(dropped.reason, 'ignored_account');
    expect(await env.count('accounts'), 0);

    final other = await env.ingest(_tx('2222', at: 86400000), id: 'c');
    expect(other.outcome, IngestOutcome.inserted);
  });

  test('stop ignoring lets messages through again', () async {
    await env.ingest(_tx('1111'), id: 'a');
    final id = (await env.db.select(env.db.accounts).getSingle()).id;
    await admin.ignore(id);
    await admin.ignore(id); // idempotent
    expect((await admin.ignored()).length, 1);
    await admin.unignore('HDFC Bank', '1111');
    expect(await admin.ignored(), isEmpty);
    final r = await env.ingest(_tx('1111', at: 86400000), id: 'b');
    expect(r.outcome, IngestOutcome.inserted);
  });
}
