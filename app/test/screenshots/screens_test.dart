// Renders the main screens to full-length PNGs (dark, seeded with dummy data)
// for visual review. Skipped unless SHOTS_DIR is set:
//   SHOTS_DIR=/tmp/shots flutter test test/screenshots
// Optional: SHOT_HEIGHT (logical px, default 1700), SHOT_SCALE (default 2),
// SHOT_ONLY (comma separated names to capture).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/app.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/router.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';

import '../support/pipeline_fakes.dart';
import 'seed_data.dart';

const _fonts = '/home/user/sdk/flutter/bin/cache/artifacts/material_fonts';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final bytes = File('$_fonts/$f').readAsBytesSync();
    l.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await l.load();
}

void main() {
  final dir = Platform.environment['SHOTS_DIR'];
  final height =
      double.tryParse(Platform.environment['SHOT_HEIGHT'] ?? '') ?? 1700;
  final scale = double.tryParse(Platform.environment['SHOT_SCALE'] ?? '') ?? 2;
  final only = (Platform.environment['SHOT_ONLY'] ?? '')
      .split(',')
      .where((e) => e.isNotEmpty)
      .toSet();

  testWidgets(
    'screens',
    (tester) async {
      Directory(dir!).createSync(recursive: true);
      WidgetsApp.debugAllowBannerOverride = false;
      await tester.runAsync(() async {
        await _font(
          'Roboto',
          ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
        );
        await _font('MaterialIcons', ['MaterialIcons-Regular.otf']);
      });
      tester.view
        ..physicalSize = Size(390 * scale, height * scale)
        ..devicePixelRatio = scale;
      addTearDown(tester.view.reset);

      final h = PipelineHarness();
      addTearDown(h.dispose);
      final c = ProviderContainer(overrides: h.overrides);
      addTearDown(c.dispose);
      final key = GlobalKey();

      late SeedIds ids;
      await tester.runAsync(() async {
        await c.read(profileRepositoryProvider).save(
              const UserProfile(
                name: 'Aarav Demo',
                email: 'aarav.demo@example.com',
                phone: '9800000000',
                occupation: 'Product designer',
              ),
            );
        final s = c.read(settingsRepositoryProvider);
        await s.write(AppearanceKeys.mode, ThemeModeChoice.dark.name);
        await s.write(SettingKeys.hideAmounts, false);
        ids = await seedDummyData(h.db, DateTime.now());
      });

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: c,
            child: const HisaabApp(),
          ),
        ),
      );

      Future<void> settle([int rounds = 6]) async {
        for (var i = 0; i < rounds; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump(const Duration(milliseconds: 120));
          // Keep going on framework errors; they are listed on stderr.
          Object? e;
          while ((e = tester.takeException()) != null) {
            final line = e.toString().split('\n').first;
            stderr.writeln('[shots] ${tester.testDescription}: $line');
          }
        }
      }

      Future<void> shot(String name) async {
        await settle();
        if (only.isNotEmpty && !only.contains(name)) return;
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final img = await b.toImage();
          return await img.toByteData(format: ui.ImageByteFormat.png);
        });
        File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }

      Future<void> tapText(String text, {Finder? within}) async {
        final f = within == null
            ? find.text(text).first
            : find.descendant(of: within, matching: find.text(text)).first;
        await tester.tap(f);
        await settle();
      }

      final r = c.read(routerProvider);
      Future<void> go(String path) async {
        r.go(path);
        await tester.pump();
        await settle();
      }

      await go('/home');
      await shot('home');

      await go('/transactions');
      await shot('transactions');
      await tester.tap(find.byKey(const Key('ledger_view_dropdown')));
      await settle(2);
      await tester.tap(find.text('By category').last);
      await settle();
      await shot('transactions_by_category');

      await go('/portfolio');
      await shot('portfolio');

      await go('/analysis');
      final strip = find.byKey(const Key('analytics-view'));
      await shot('analysis_spend');
      await tapText('Trends', within: strip);
      await shot('analysis_trends');
      await tapText('Cash flow', within: strip);
      await shot('analysis_cash_flow');
      await tapText('Forecast', within: strip);
      await shot('analysis_forecast');

      for (final e in {
        'more': '/more',
        'accounts': '/accounts',
        'bills': '/bills',
        'card_detail': '/cards/${ids.cardIds.first}',
        'profile': '/profile',
        'support': '/settings/support',
        'news': '/news',
      }.entries) {
        await go(e.value);
        await shot(e.key);
      }

      await go('/home');
      try {
        await tester.tap(find.byKey(const Key('home_sync')));
        await settle();
        await shot('refresh_sheet');
      } on Object {
        // The sheet is optional in the harness.
      }
    },
    skip: dir == null,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
