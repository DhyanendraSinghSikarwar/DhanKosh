// Safe to spend (FR-17-48, ADR-0012).
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/dashboard_home/domain/safe_to_spend.dart';

void main() {
  test('balance minus bills, spread over the days left', () {
    final r = SafeToSpend.compute(
      liquidMinor: 4500000,
      billsMinor: 300000,
      daysLeft: 10,
    )!;
    expect(r.spendableMinor, 4200000);
    expect(r.perDayMinor, 420000);
  });

  test('the budget left caps it', () {
    final r = SafeToSpend.compute(
      liquidMinor: 9000000,
      billsMinor: 300000,
      daysLeft: 10,
      budgetLeftMinor: 1500000,
    )!;
    expect(r.spendableMinor, 1500000);
    expect(r.perDayMinor, 150000);
  });

  test('never below zero; rounds down; last day counts as one', () {
    expect(
      SafeToSpend.compute(liquidMinor: 100, billsMinor: 5000, daysLeft: 3)!
          .perDayMinor,
      0,
    );
    expect(
      SafeToSpend.compute(
        liquidMinor: 1000,
        billsMinor: 0,
        daysLeft: 3,
        budgetLeftMinor: -50,
      )!
          .spendableMinor,
      0,
    );
    expect(
      SafeToSpend.compute(liquidMinor: 1000, billsMinor: 0, daysLeft: 3)!
          .perDayMinor,
      333,
    );
    expect(
      SafeToSpend.compute(liquidMinor: 900, billsMinor: 0, daysLeft: 0)!
          .perDayMinor,
      900,
    );
  });

  test('no known balance gives nothing', () {
    expect(
      SafeToSpend.compute(liquidMinor: null, billsMinor: 0, daysLeft: 5),
      isNull,
    );
  });
}
