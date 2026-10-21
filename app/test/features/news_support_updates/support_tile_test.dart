import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/news_support_updates/presentation/support_tile.dart';

void main() {
  testWidgets('FR-31-10 tile hidden without a donation address', (t) async {
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: SupportTile())),
    );
    expect(find.byKey(const Key('support-tile')), findsNothing);
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: SupportTile(upiId: 'dummy@upi'))),
    );
    expect(find.byKey(const Key('support-tile')), findsOneWidget);
  });
}
