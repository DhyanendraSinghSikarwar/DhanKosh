import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/alerts_reminders/presentation/change_category_sheet.dart';
import 'package:parser_core/parser_core.dart';

void main() {
  testWidgets('lists the type, checks current, tap saves and closes (FR-21-22)',
      (t) async {
    Category? saved;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  saved = await showModalBottomSheet<Category>(
                context: ctx,
                isScrollControlled: true,
                builder: (c) => ChangeCategorySheet(
                  current: Category.food,
                  isCredit: false,
                  onPick: (v) => Navigator.of(c).pop(v),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Change category'), findsOneWidget);
    expect(find.byKey(const Key('current_check')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pick_food')),
        matching: find.byKey(const Key('current_check')),
      ),
      findsOneWidget,
    );
    final all =
        AlertRules.categoriesFor(isCredit: false, current: Category.food);
    expect(find.byKey(const Key('pick_shopping')), findsOneWidget);
    expect(find.byKey(const Key('pick_salary')), findsNothing);
    expect(all, contains(Category.shopping));
    await t.tap(find.byKey(const Key('pick_shopping')));
    await t.pumpAndSettle();
    expect(saved, Category.shopping);
    expect(find.text('Change category'), findsNothing);
  });
}
