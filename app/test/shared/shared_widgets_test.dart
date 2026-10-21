import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  for (final dark in [false, true]) {
    testWidgets('EmptyState shows title and hint (dark=$dark)', (t) async {
      await t.pumpWidget(
        _wrap(
          const EmptyState(
            icon: Icons.pie_chart_outline,
            title: 'No investments yet',
            hint: 'Tap + to add one.',
          ),
          dark: dark,
        ),
      );
      expect(find.text('No investments yet'), findsOneWidget);
      expect(find.text('Tap + to add one.'), findsOneWidget);
    });
  }
  testWidgets('AppCard passes taps through', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _wrap(AppCard(onTap: () => taps++, child: const Text('x'))),
    );
    await t.tap(find.text('x'));
    expect(taps, 1);
  });
}
