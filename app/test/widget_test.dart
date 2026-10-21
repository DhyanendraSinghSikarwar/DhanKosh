import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/app.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';

import 'support/pipeline_fakes.dart';

void main() {
  testWidgets('onboarded app shows the shell (FR-01-01)', (tester) async {
    final h = PipelineHarness();
    addTearDown(h.dispose);
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await tester.runAsync(() async {
      await c.read(profileRepositoryProvider).read();
      await c
          .read(keyValueStoreProvider)
          .setString('onboarding_skipped', 'true');
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const HisaabApp()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Transactions'), findsWidgets);
    expect(find.byKey(const Key('welcome-name')), findsNothing);
  });
}
