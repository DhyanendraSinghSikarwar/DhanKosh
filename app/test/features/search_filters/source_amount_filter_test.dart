import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<void> seed() async {
    await env.ingest(
      parsed(amountMinor: 10000, ref: 'R1'),
    );
    await env.ingest(
      parsed(
        amountMinor: 250050,
        ref: 'R2',
        time: t0 + minute,
        source: Source.email,
      ),
    );
    await env.ingest(
      parsed(
        amountMinor: 900000,
        ref: 'R3',
        time: t0 + 2 * minute,
        source: Source.statement,
      ),
    );
    await env.ingest(
      parsed(
        amountMinor: 5000,
        ref: 'R4',
        time: t0 + 3 * minute,
        source: Source.manual,
      ),
    );
  }

  Future<List<int>> amounts(LedgerFilter f) async =>
      ((await env.txs.watch(f).first).map((t) => t.amountMinor).toList()
        ..sort());

  // FR-20-15
  test('source filter reads transaction_sources', () async {
    await seed();
    expect(
      await amounts(const LedgerFilter(sources: {Source.sms})),
      [10000],
    );
    expect(
      await amounts(const LedgerFilter(sources: {Source.email, Source.manual})),
      [5000, 250050],
    );
    expect(await amounts(const LedgerFilter()), hasLength(4));
  });

  // FR-20-21
  test('amount range is inclusive in paise', () async {
    await seed();
    expect(
      await amounts(const LedgerFilter(minMinor: 10000, maxMinor: 250050)),
      [10000, 250050],
    );
    expect(await amounts(const LedgerFilter(minMinor: 250051)), [900000]);
    expect(await amounts(const LedgerFilter(maxMinor: 9999)), [5000]);
    expect(
      await amounts(
        const LedgerFilter(
          sources: {Source.statement, Source.sms},
          minMinor: 20000,
        ),
      ),
      [900000],
    );
  });

  // FR-20-21
  test('rupees convert to paise by integer math', () {
    expect(rupeesToMinor('1250'), 125000);
    expect(rupeesToMinor('1,250.5'), 125050);
    expect(rupeesToMinor('₹ 0.07'), 7);
    expect(rupeesToMinor('99.99'), 9999);
    expect(rupeesToMinor(''), isNull);
    expect(rupeesToMinor('abc'), isNull);
    expect(rupeesToMinor('1.234'), isNull);
    expect(rupeesToMinor('-5'), isNull);
  });

  // FR-20-16, FR-20-21
  test('view state carries and clears the new filters', () {
    const s = LedgerViewState(
      sources: {Source.sms},
      minMinor: 100,
      maxMinor: 200,
    );
    expect(s.hasChipFilters, isTrue);
    final f = s.toFilter(DateTime(2026, 10, 26));
    expect(f.sources, {Source.sms});
    expect(f.minMinor, 100);
    expect(f.maxMinor, 200);
    final c = s.cleared();
    expect(c.hasChipFilters, isFalse);
    expect(c.sources, isEmpty);
    expect(c.minMinor, isNull);
  });
}
