import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/tax_centre/domain/tax_deductions.dart';
import 'package:hisaab/features/tax_centre/domain/tax_income.dart';
import 'package:hisaab/features/tax_centre/domain/tax_plan.dart';
import 'package:hisaab/features/tax_centre/presentation/tax_centre_screen.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';

import '../../support/ui_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester t, {
    int salary = 150000000,
    bool dark = false,
  }) async {
    await t.binding.setSurfaceSize(const Size(420, 2200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          hideAmountsProvider.overrideWith((ref) => Stream.value(false)),
          taxBaselineProvider.overrideWith(
            (ref) => Stream.value(
              TaxBaseline(
                period: ref.watch(taxPeriodChoiceProvider),
                fyStartYear: 2026,
                est: TaxIncomeEstimate(salary: salary),
                deductions: const DetectedDeductions(
                  items80C: [TaxItem('PPF', 15000000)],
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const TaxCentreScreen(),
        ),
      ),
    );
    await settle(t);
  }

  String totalOf(WidgetTester t, String name) =>
      (t.widget(find.byKey(Key('tax-total-$name'))) as Text).data!;

  for (final dark in [false, true]) {
    testWidgets(
        'regime comparison, memory 19 examples B and C '
        '(FR-19-03, FR-19-04) ${dark ? 'dark' : 'light'}', (t) async {
      await pump(t, dark: dark);
      expect(totalOf(t, 'New'), '₹97,500');
      expect(totalOf(t, 'Old'), '₹2,10,600');
      expect(find.text('New regime saves ₹1,13,100'), findsOneWidget);
      expect(find.byKey(const Key('tax-note')), findsOneWidget);
      expect(find.text('PPF'), findsOneWidget);
      await teardownApp(t);
    });
  }

  testWidgets('empty income shows hint (FR-19-02)', (t) async {
    await pump(t, salary: 0);
    expect(find.byKey(const Key('tax-no-income')), findsOneWidget);
    await teardownApp(t);
  });

  testWidgets(
      'what-if salary 12,75,000 gives zero new tax, resets '
      '(FR-19-07, FR-19-08)', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('tax-whatif')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('wi-salary')), '1275000');
    expect(find.byKey(const Key('wi-apply')), findsOneWidget);
    await t.tap(find.byKey(const Key('wi-apply')));
    await t.pumpAndSettle();
    await settle(t);
    expect(totalOf(t, 'New'), '₹0');
    await t.tap(find.byKey(const Key('tax-whatif-reset')));
    await settle(t);
    expect(totalOf(t, 'New'), '₹97,500');
    await teardownApp(t);
  });

  testWidgets('period change keeps screen working (FR-19-01)', (t) async {
    await pump(t);
    await t.tap(find.text('Last FY'));
    await settle(t);
    expect(find.byKey(const Key('tax-compare')), findsOneWidget);
    await teardownApp(t);
  });
}
