// FR-30-16: Balance, Budget and Bills widget payloads.
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/expense_tracking/domain/budget.dart';
import 'package:hisaab/features/home_widget/domain/extra_widget_data.dart';
import 'package:hisaab/features/home_widget/domain/extra_widget_sync.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:parser_core/parser_core.dart' show Category;

class _Updater implements ExtraWidgetUpdater {
  final pushed = <Map<String, String>>[];
  @override
  Future<void> update(Map<String, String> payload) async => pushed.add(payload);
}

void main() {
  test('balance shows the amount, a dash when unknown, masked when hidden', () {
    expect(
      balancePayload(balanceMinor: 12345600, hidden: false)['bal_amount'],
      '₹1,23,456',
    );
    expect(balancePayload(hidden: false)['bal_amount'], '—');
    expect(balancePayload(balanceMinor: 100)['bal_amount'], '₹••••');
  });

  test('budget left, percent used, and over budget', () {
    final ok = budgetPayload(
      limitMinor: 1000000,
      spentMinor: 250000,
      hidden: false,
    );
    expect(ok['bud_left'], '₹7,500');
    expect(ok['bud_percent'], '25');
    expect(ok['bud_caption'], 'Budget left');
    expect(ok['bud_sub'], '₹2,500 of ₹10,000');

    final over = budgetPayload(
      limitMinor: 100000,
      spentMinor: 150000,
      hidden: false,
    );
    expect(over['bud_caption'], 'Over budget');
    expect(over['bud_left'], '₹500');
    expect(over['bud_percent'], '100');

    expect(
      budgetPayload(limitMinor: 0, spentMinor: 5)['bud_sub'],
      'No budget set',
    );
  });

  test('bills: next three, soonest first, blank lines when fewer', () {
    final p = billsPayload(
      [
        WidgetBill(name: 'Rent', amountMinor: 2000000, due: DateTime(2026, 12)),
        WidgetBill(
          name: 'Netflix',
          amountMinor: 64900,
          due: DateTime(2026, 11, 20),
        ),
      ],
      hidden: false,
    );
    expect(p['bill_1'], 'Netflix · ₹649 · 20 Nov');
    expect(p['bill_2'], 'Rent · ₹20,000 · 1 Dec');
    expect(p['bill_3'], '');
    expect(billsPayload(const [])['bill_1'], 'No bills coming up');
  });

  test('next due: this month if still ahead, else next; clamps short months',
      () {
    final today = DateTime(2026, 11, 15);
    expect(
      nextDueOf(dayOfMonth: 20, today: today),
      DateTime(2026, 11, 20),
    );
    expect(nextDueOf(dayOfMonth: 10, today: today), DateTime(2026, 12, 10));
    expect(nextDueOf(dayOfMonth: 15, today: today), DateTime(2026, 11, 15));
    expect(
      nextDueOf(dayOfMonth: 31, today: DateTime(2026, 2, 5)),
      DateTime(2026, 2, 28),
    );
    expect(
      nextDueOf(dayOfMonth: 3, month: 3, today: today),
      DateTime(2027, 3, 3),
    );
  });

  test('the sync pushes balance, budget and bills together', () async {
    final u = _Updater();
    final sync = ExtraWidgetSync(
      accounts: Stream.value(const []),
      budgets: Stream.value(const [
        Budget(category: Category.food, monthlyLimitMinor: 1000000),
      ]),
      categorySpend: Stream.value({Category.food: 400000}),
      bills: Stream.value([
        const RecurringItem(
          id: 1,
          name: 'Rent',
          amountMinor: 2000000,
          income: false,
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 20,
          category: Category.rent,
          createdAt: 0,
        ),
        const RecurringItem(
          id: 2,
          name: 'Salary',
          amountMinor: 9000000,
          income: true,
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 1,
          category: Category.salary,
          createdAt: 0,
        ),
      ]),
      hidden: Stream.value(false),
      updater: u,
      clock: () => DateTime(2026, 11, 15),
      debounce: const Duration(milliseconds: 1),
    )..start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    sync.stop();
    final p = u.pushed.last;
    expect(p['bal_amount'], '—');
    expect(p['bud_left'], '₹6,000');
    expect(p['bud_percent'], '40');
    expect(p['bill_1'], 'Rent · ₹20,000 · 20 Nov');
    expect(p['bill_2'], '');
  });
}
