// Renders the main screens to PNG for visual review. Skipped unless
// SHOTS_DIR is set: `SHOTS_DIR=/tmp/shots flutter test test/screenshots`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/app.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/router.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_providers.dart';

import '../support/pipeline_fakes.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final bytes = File(
      '/home/user/sdk/flutter/bin/cache/artifacts/material_fonts/$f',
    ).readAsBytesSync();
    l.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await l.load();
}

void main() {
  final dir = Platform.environment['SHOTS_DIR'];
  testWidgets('screens', (tester) async {
    await tester.runAsync(() async {
      print('fonts');
      await _font('Roboto',
          ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
      await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    tester.view
      ..physicalSize = const Size(1170, 4800)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    print('fonts done');
    final h = PipelineHarness();
    addTearDown(h.dispose);
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    final key = GlobalKey();
    await tester.runAsync(() async {
      await c.read(profileRepositoryProvider).read();
      await c
          .read(keyValueStoreProvider)
          .setString('onboarding_skipped', 'true');
    });
    print('onboarded');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child:
            UncontrolledProviderScope(container: c, child: const HisaabApp()),
      ),
    );
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    print('before sample');
    await tester.runAsync(
        () => c.read(developerActionsProvider.notifier).addSampleData().timeout(
          const Duration(seconds: 25),
          onTimeout: () {},
        ));
    print('after sample');

    Future<void> shot(String name) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await tester.runAsync(() => b.toImage(pixelRatio: 1));
      final bytes = await tester
          .runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    // ignore: avoid_print
    print('B sample');
    final r = c.read(routerProvider);
    for (final e in {
      'home': '/home',
      'transactions': '/transactions',
      'portfolio': '/portfolio',
      'analysis': '/analysis',
      'more': '/more',
      'accounts': '/accounts',
      'bills': '/bills',
      'profile': '/profile',
    }.entries) {
      // ignore: avoid_print
      print('go ${e.key}');
      r.go(e.value);
      await tester.pump();
      await shot(e.key);
    }
  }, skip: dir == null);
}
