import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/app.dart';

void main() {
  testWidgets('app shows the Home placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HisaabApp()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard_home_placeholder')), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
  });
}
