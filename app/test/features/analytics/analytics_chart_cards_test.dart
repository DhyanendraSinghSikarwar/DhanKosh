import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/analytics/domain/analytics_models.dart';
import 'package:hisaab/features/analytics/presentation/analytics_chart_cards.dart';

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
}
