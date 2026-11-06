// Evening daily summary (FR-21-29).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';

void main() {
  final day = DateTime.utc(2026, 11, 6);
  const on = AlertSettings(dailySummary: true);

  AlertDecision? run({
    int hour = 21,
    int spent = 125000,
    int count = 3,
    int sort = 2,
    AlertSettings settings = on,
    Set<String> alerted = const {},
  }) =>
      AlertRules.dailySummary(
        today: day,
        hour: hour,
        spentMinor: spent,
        paymentCount: count,
        uncategorisedCount: sort,
        settings: settings,
        alerted: alerted,
      );

  test('text: spent, payments and what is left to categorise', () {
    final d = run()!;
    expect(d.kind, AlertKind.dailySummary);
    expect(d.key, 'daily:2026-11-06');
    expect(d.title, 'Today: ₹1,250 spent');
    expect(d.body, '3 payments · 2 to categorise');
    expect(run(count: 1, sort: 0)!.body, '1 payment');
  });

  test('off by default, before 21:00, once a day, silent on an empty day', () {
    expect(run(settings: const AlertSettings()), isNull);
    expect(run(hour: 20), isNull);
    expect(run(alerted: {'daily:2026-11-06'}), isNull);
    expect(run(spent: 0, count: 0, sort: 0), isNull);
    expect(run(spent: 0, count: 1, sort: 1)!.title, 'Today: nothing spent');
  });
}
