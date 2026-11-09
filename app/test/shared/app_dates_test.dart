// The chosen date style reaches every date the app writes (FR-28-31).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/day_groups.dart';
import 'package:hisaab/shared/ui/app_dates.dart';

void main() {
  tearDown(() => AppDates.style = DateStyle.auto);
  final d = DateTime(2026, 11, 7, 18, 5);

  test('each style writes the date its own way', () {
    expect(AppDates.format(d), '7 Nov 2026');
    AppDates.style = DateStyle.dayFirst;
    expect(AppDates.format(d), '07/11/2026');
    expect(AppDates.format(d, year: false), '07/11');
    AppDates.style = DateStyle.monthFirst;
    expect(AppDates.format(d, time: true), '11/07/2026, 6:05 PM');
    AppDates.style = DateStyle.iso;
    expect(AppDates.format(d, weekday: true), 'Sat, 2026-11-07');
    expect(AppDates.format(d, year: false), '11-07');
  });

  test('list day headers follow the style', () {
    final now = DateTime(2026, 11, 20);
    expect(dayLabel(DateTime(2026, 11, 7), now), 'Sat, 7 Nov 2026');
    AppDates.style = DateStyle.iso;
    expect(dayLabel(DateTime(2026, 11, 7), now), 'Sat, 2026-11-07');
    expect(dayLabel(now, now), 'Today');
  });

  test('unknown name is Auto', () {
    expect(DateStyle.of('nope'), DateStyle.auto);
    expect(DateStyle.of('iso'), DateStyle.iso);
  });
}
