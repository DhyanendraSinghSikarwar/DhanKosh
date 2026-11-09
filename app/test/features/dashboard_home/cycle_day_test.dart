// Budget month that starts on a chosen day (FR-10-25).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';

void main() {
  tearDown(() => MonthRange.cycleDay = 1);

  test('day 1 is the calendar month', () {
    final m = MonthRange.of(DateTime(2026, 11, 9));
    expect(m.start, DateTime(2026, 11));
    expect(m.end, DateTime(2026, 12));
    expect(m.label, 'November 2026');
  });

  test('day 25: the cycle runs 25th to 24th', () {
    MonthRange.cycleDay = 25;
    final a = MonthRange.of(DateTime(2026, 11, 9));
    expect(a.start, DateTime(2026, 10, 25));
    expect(a.end, DateTime(2026, 11, 25));
    expect(a.label, '25 Oct - 24 Nov');
    final b = MonthRange.of(DateTime(2026, 11, 25));
    expect(b.start, DateTime(2026, 11, 25));
    expect(b.end, DateTime(2026, 12, 25));
    expect(b.previous, a);
    expect(a.next, b);
    expect(a.isCurrent(DateTime(2026, 11, 24, 23)), isTrue);
    expect(a.isCurrent(DateTime(2026, 11, 25)), isFalse);
  });

  test('January start reaches back into the previous year', () {
    MonthRange.cycleDay = 20;
    final m = MonthRange.of(DateTime(2027, 1, 5));
    expect(m.start, DateTime(2026, 12, 20));
    expect(m.end, DateTime(2027, 1, 20));
  });

  test('day 31 falls on the last day of a short month', () {
    MonthRange.cycleDay = 31;
    final m = MonthRange.of(DateTime(2026, 3, 5));
    expect(m.start, DateTime(2026, 2, 28));
    expect(m.end, DateTime(2026, 3, 31));
  });
}
