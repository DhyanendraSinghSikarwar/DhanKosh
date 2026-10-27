import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';

void main() {
  final now = DateTime(2026, 10, 27, 15);
  int ms(int y, int m, [int d = 1]) => DateTime(y, m, d).millisecondsSinceEpoch;

  test('FR-20-22: period presets resolve to local ranges', () {
    expect(periodRange(PeriodKind.thisWeek, now).fromMs, ms(2026, 10, 26));
    expect(periodRange(PeriodKind.thisWeek, now).toMs, ms(2026, 11, 2));
    expect(periodRange(PeriodKind.thisFy, now).fromMs, ms(2026, 4));
    expect(periodRange(PeriodKind.thisFy, now).toMs, ms(2027, 4));
    expect(periodRange(PeriodKind.lastFy, now).fromMs, ms(2025, 4));
    expect(periodRange(PeriodKind.lastFy, now).toMs, ms(2026, 4));
    final early = DateTime(2026, 2, 10);
    expect(periodRange(PeriodKind.thisFy, early).fromMs, ms(2025, 4));
    expect(periodRange(PeriodKind.last12Months, now).fromMs, ms(2025, 11));
    expect(periodRange(PeriodKind.last12Months, now).toMs, ms(2026, 11));
  });

  test('FR-20-22, FR-20-23: shared stores feed the ledger view', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(bookProvider), Book.all);
    c.read(bookProvider.notifier).set(Book.business);
    c.read(periodProvider.notifier).set(PeriodKind.lastFy);
    expect(bookUsage(c.read(bookProvider)), 'BUSINESS');
    expect(c.read(periodProvider).kind, PeriodKind.lastFy);
    expect(c.read(accountScopeProvider), isNull);
    c.read(accountScopeProvider.notifier).set(3);
    expect(c.read(accountScopeProvider), 3);
  });
}
