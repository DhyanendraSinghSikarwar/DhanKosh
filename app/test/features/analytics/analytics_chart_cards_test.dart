import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/domain/ledger_math.dart';
import 'package:hisaab/features/analytics/presentation/analytics_chart_cards.dart';
import 'package:hisaab/shared/widgets/charts/chart_style.dart';

void main() {
  testWidgets('fan chart and Sankey paint from paise fixtures (FR-18-09, 13)',
      (t) async {
    final f = Forecast(
      month: DateTime.utc(2026, 10),
      actual: const [0, 100000, 250000],
      expected: const [0, 100000, 250000, 400000, 550000],
      low: const [0, 100000, 250000, 350000, 450000],
      high: const [0, 100000, 250000, 450000, 650000],
      billsLeft: 50000,
      dailyRate: 100000,
    );
    final data = AnalyticsData(
      loaded: true,
      forecast: f,
      budget: 500000,
      income: 1000000,
      salary: 1000000,
      spent: 600000,
      invested: 100000,
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ForecastCard(data: data, money: (m) => '₹${m ~/ 100}'),
              IncomeFlowCard(data: data, money: (m) => '₹${m ~/ 100}'),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('analytics-fan')), findsOneWidget);
    expect(find.byKey(const Key('analytics-sankey')), findsOneWidget);
    expect(find.text('Over budget by ₹500'), findsOneWidget);
  });

  test('axis labels are compact and masked (FR-18-18)', () {
    expect(axisLabel(0), '0');
    expect(axisLabel(4700000), '47K');
    expect(axisLabel(11000000), '1.1L');
    expect(axisLabel(20000000), '2L');
    expect(axisLabel(20000000, masked: true), '••');
    expect(compactMoney(6200000), '₹62K');
    expect(compactMoney(6200000, masked: true), '₹••••');
    expect(niceMax(24000000), 24000000);
    expect(niceMax(11000000), 12000000);
  });

  testWidgets('cash flow cards draw from fixtures (FR-18-09, FR-18-11)',
      (t) async {
    final months = [
      for (var i = 0; i < 7; i++)
        MonthFlow(
          month: DateTime.utc(2026, 4 + i),
          spent: 100000 + i * 1000,
          income: 240000,
          invested: 0,
          byGroup: const {},
        ),
    ];
    final data = AnalyticsData(
      loaded: true,
      monthly: months,
      savingsRates: [
        for (final m in months)
          (m.month, (m.income - m.spent) * 100 / m.income),
      ],
      isCurrentMonth: true,
      previousLabel: 'Sep 2026',
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              IncomeVsSpendCard(months: months),
              SavingsRateCard(data: data),
              CompareCard(data: data, money: (m) => '₹${m ~/ 100}'),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('analytics-income-spend')), findsOneWidget);
    expect(find.byKey(const Key('analytics-savings-line')), findsOneWidget);
    expect(find.text('INCOME AGAINST SPEND'), findsOneWidget);
    expect(find.text('SAVINGS RATE'), findsOneWidget);
    expect(find.text('THIS MONTH VS LAST'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
  });
}
