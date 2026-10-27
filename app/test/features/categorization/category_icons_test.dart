import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/categorization/presentation/category_icons.dart';
import 'package:hisaab/features/categorization/presentation/name_icon_dialog.dart';

void main() {
  test('FR-09-33 icon keys resolve, unknown falls back to label', () {
    expect(CategoryIcons.get('restaurant'), Icons.restaurant);
    expect(CategoryIcons.get('pets'), Icons.pets);
    expect(CategoryIcons.get('nope'), Icons.label);
    expect(CategoryIcons.get(null), Icons.label);
    expect(CategoryIcons.pickable.first.key, 'category');
    expect(CategoryIcons.pickable.length, greaterThan(100));
  });

  testWidgets('FR-09-33 dialog returns the picked name and icon', (t) async {
    ({String name, String icon})? got;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async =>
                got = await showNameIconDialog(ctx, title: 'New category'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('new_category_name')), 'Pets');
    await t.tap(find.byKey(const Key('icon_pets')));
    await t.pump();
    await t.tap(find.byKey(const Key('new_category_add')));
    await t.pumpAndSettle();
    expect(got, (name: 'Pets', icon: 'pets'));
  });
}
