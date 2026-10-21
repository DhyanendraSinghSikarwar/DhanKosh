import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/home_widget/data/widget_updater_impl.dart';
import 'package:hisaab/features/home_widget/domain/build_spend_widget_data.dart';
import 'package:hisaab/features/home_widget/domain/spend_widget_data.dart';
import 'package:hisaab/features/home_widget/domain/widget_sync.dart';
import 'package:hisaab/features/home_widget/domain/widget_updater.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';

class _Capture implements WidgetUpdater {
  final shots = <SpendWidgetData>[];
  bool throws = false;

  @override
  Future<void> update(SpendWidgetData data) async {
    if (throws) throw StateError('native missing');
    shots.add(data);
  }
}

void main() {
  final now = DateTime(2026, 10, 17, 12);

  test('TC-30-03 formats paise, masks when hidden', () {
    SpendWidgetData b(int m, {bool? hidden}) => buildSpendWidgetData(
          todayMinor: m,
          monthMinor: m,
          now: now,
          hidden: hidden,
        );
    expect(b(123456, hidden: false).todayText, '₹1,234.56');
    expect(b(120000, hidden: false).todayText, '₹1,200');
    expect(b(120000, hidden: true).monthText, '₹••••');
  });

  test('TC-30-04 masked until the setting is read', () {
    final d = buildSpendWidgetData(todayMinor: 5, monthMinor: 5, now: now);
    expect(d.hidden, isTrue);
    expect(d.todayText, '₹••••');
  });

  test('TC-30-05 empty ledger shows zero, not an error', () {
    final d = buildSpendWidgetData(
      todayMinor: 0,
      monthMinor: 0,
      now: now,
      hidden: false,
    );
    expect((d.todayText, d.monthText), ('₹0', '₹0'));
    expect(d.todayCaption, 'Spent today');
    expect(d.monthCaption, 'This month');
  });

  test('FR-30-15 payload has only the five native keys', () {
    final p = widgetPayload(
      buildSpendWidgetData(
        todayMinor: 100,
        monthMinor: 250,
        now: now,
        hidden: false,
      ),
    );
    expect(p.keys.toSet(), {
      'spent_today_text',
      'spent_month_text',
      'caption_today',
      'caption_month',
      'updated_at',
    });
    expect(p['spent_month_text'], '₹2.50');
  });

  group('WidgetSync (FR-30-04, FR-30-08, FR-30-10)', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.close());

    test('sums debit and investment, respects hide setting', () async {
      final nowDt = DateTime.fromMillisecondsSinceEpoch(t0);
      await env.ingest(parsed(amountMinor: 50000, ref: 'a'));
      await env.settings.write(SettingKeys.hideAmounts, false);
      final cap = _Capture();
      final sync = WidgetSync(
        transactions: env.txs,
        settings: env.settings,
        updater: cap,
        clock: () => nowDt,
        debounce: const Duration(milliseconds: 10),
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      sync.stop();
      expect(cap.shots, isNotEmpty);
      expect(cap.shots.last.todayMinor, 50000);
      expect(cap.shots.last.monthText, '₹500');
    });

    test('updater failure is swallowed', () async {
      final cap = _Capture()..throws = true;
      final sync = WidgetSync(
        transactions: env.txs,
        settings: env.settings,
        updater: cap,
      );
      await sync.flush();
    });
  });
}
