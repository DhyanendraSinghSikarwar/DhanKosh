// AMFI NAV file parser and optional refresh (FR-16-23, FR-16-24).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/nav_file.dart';
import 'package:hisaab/features/portfolio/domain/nav_refresh.dart';

import '../../support/test_env.dart';

// Fictional funds; the layout is the public NAVAll.txt layout.
const fixture = '''
Scheme Code;ISIN Div Payout/ISIN Growth;ISIN Div Reinvestment;Scheme Name;Net Asset Value;Date

Open Ended Schemes(Equity Scheme - Large Cap Fund)

Sample Mutual Fund
100001;INF000A01011;INF000A01029;Sample Large Cap Fund - Growth;123.4567;23-Oct-2026
100002;-;-;Sample Closed Plan;N.A.;23-Oct-2026
100003;INF000A01037;-;Sample Mid Cap Fund - Growth;250.50;22-Oct-2026
garbage line without separators
100004;INF000A01045;-;Bad Date Fund;10.0;32-Foo-2026
''';

class _Source implements NavSource {
  _Source(this.text);
  String? text;
  int calls = 0;
  @override
  Future<String?> fetch() async {
    calls++;
    return text;
  }
}

void main() {
  test('parser reads both ISIN columns and skips bad lines (FR-16-23)', () {
    final q = NavFileParser.parse(fixture);
    expect(q.keys, {'INF000A01011', 'INF000A01029', 'INF000A01037'});
    expect(q['INF000A01011']!.nav, 123.4567);
    expect(q['INF000A01029']!.name, 'Sample Large Cap Fund - Growth');
    expect(
      q['INF000A01011']!.dateMs,
      DateTime.utc(2026, 10, 23, 12).millisecondsSinceEpoch - 19800000,
    );
    expect(NavFileParser.parseDate('1-jan-2026'), isNotNull);
    expect(NavFileParser.parseDate('x'), isNull);
    expect(NavFileParser.parse(''), isEmpty);
  });

  group('refresh service', () {
    late TestEnv env;
    late HoldingRepositoryImpl holdings;
    final noon = DateTime.utc(2026, 10, 26, 6).millisecondsSinceEpoch;
    var clock = noon;
    setUp(() async {
      env = TestEnv();
      clock = noon;
      holdings = HoldingRepositoryImpl(env.db, now: () => clock);
      await holdings.record(
        [
          HoldingSnapshot(
            kind: HoldingKind.mutualFund,
            name: 'Sample Large Cap Fund',
            identifier: 'INF000A01011',
            asOf: DateTime.utc(2026, 9, 30, 6).millisecondsSinceEpoch,
            units: 100,
            valueMinor: 1000000,
            investedMinor: 900000,
          ),
          HoldingSnapshot(
            kind: HoldingKind.mutualFund,
            name: 'Named Only Fund',
            identifier: 'MF:named only fund',
            asOf: DateTime.utc(2026, 9, 30, 6).millisecondsSinceEpoch,
            units: 10,
            valueMinor: 50000,
          ),
        ],
        HoldingSource.statement,
      );
    });
    tearDown(() => env.close());

    NavRefreshService svc(NavSource s) => NavRefreshService(
          holdings: holdings,
          settings: env.settings,
          source: s,
          parse: (t) async => NavFileParser.parse(t),
          now: () => clock,
        );

    test('off by default: nothing downloaded', () async {
      final s = _Source(fixture);
      expect(await svc(s).refresh(), NavOutcome.off);
      expect(s.calls, 0);
    });

    test('updates value by ISIN with the NAV date, once a day', () async {
      await env.settings.write(NavSettings.enabled, true);
      final s = _Source(fixture);
      final r = svc(s);
      expect(await r.refresh(), NavOutcome.done);
      final h = (await holdings.list())
          .firstWhere((x) => x.identifier == 'INF000A01011');
      expect(h.valueMinor, (100 * 123.4567 * 100).round());
      expect(h.asOf, NavFileParser.parseDate('23-Oct-2026'));
      expect(h.previousValueMinor, 1000000);
      final other = (await holdings.list())
          .firstWhere((x) => x.identifier == 'MF:named only fund');
      expect(other.valueMinor, 50000);
      // Throttled the same day, forced by Refresh now.
      expect(await r.refresh(), NavOutcome.throttled);
      expect(s.calls, 1);
      expect(await r.refresh(force: true), NavOutcome.done);
      expect(s.calls, 2);
      clock += 86400000;
      expect(await r.refresh(), NavOutcome.done);
    });

    test('failure leaves holdings alone and never throws', () async {
      await env.settings.write(NavSettings.enabled, true);
      expect(await svc(_Source(null)).refresh(), NavOutcome.failed);
      expect(
        await env.settings.read(NavSettings.lastResult),
        'Could not download',
      );
      clock += 86400000;
      expect(await svc(_Source('nonsense')).refresh(), NavOutcome.failed);
      final h = (await holdings.list())
          .firstWhere((x) => x.identifier == 'INF000A01011');
      expect(h.valueMinor, 1000000);
    });

    test('never overwrites newer or manual figures (FR-16-24)', () async {
      final h = (await holdings.list())
          .firstWhere((x) => x.identifier == 'INF000A01011');
      expect(
        await holdings.applyNav(h.id, valueMinor: 1, asOf: h.asOf!),
        isFalse,
      );
      final m = await holdings.addManual(
        kind: HoldingKind.mutualFund,
        name: 'Mine',
        valueMinor: 100,
        at: 1,
      );
      expect(
        await holdings.applyNav(m, valueMinor: 5, asOf: noon),
        isFalse,
      );
    });
  });
}
