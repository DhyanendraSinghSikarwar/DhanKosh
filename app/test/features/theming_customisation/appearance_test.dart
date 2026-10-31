import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/appearance_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/app/theme/palettes.dart';
import 'package:hisaab/features/theming_customisation/data/appearance_repository_impl.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';
import 'package:hisaab/features/theming_customisation/presentation/theming_customisation_screen.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final x = _lum(a);
  final y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('defaults (TC-28-01, FR-28-03)', () {
    const a = AppearanceSettings();
    expect(a.mode, ThemeModeChoice.system);
    expect(a.palette, PaletteId.mint);
    expect(a.pureBlack, false);
    expect(a.textSize.factor, 1);
  });

  test('23 palettes, three groups 11/6/6 (FR-28-02, FR-28-13)', () {
    expect(PaletteId.values.length, 23);
    expect(allPaletteSpecs.length, 23);
    int n(PaletteGroup g) => PaletteId.values.where((p) => p.group == g).length;
    expect(
      [n(PaletteGroup.classic), n(PaletteGroup.hero), n(PaletteGroup.cinema)],
      [11, 6, 6],
    );
    for (final s in allPaletteSpecs) {
      expect(s.heroLight.length, 3);
      expect(s.glows.length, 3);
    }
  });

  test('Mint dark tokens match the mockup (FR-28-29)', () {
    final d = allPaletteSpecs[PaletteId.mint.index].dark;
    expect(d.primary, const Color(0xFF8FD19E));
    expect(d.primaryContainer, const Color(0xFF1F4D4A));
    expect(d.surface, const Color(0xFF0B0E0D));
    expect(d.surfaceContainer, const Color(0xFF1A1F1E));
    expect(d.surfaceContainerHigh, const Color(0xFF222827));
    expect(d.outlineVariant, const Color(0xFF2A312F));
    expect(d.onSurface, const Color(0xFFE8EEEA));
    expect(d.onSurfaceVariant, const Color(0xFF8C9893));
    expect(d.tertiary, const Color(0xFF7FA9E6));
    expect(d.error, const Color(0xFFE8837C));
  });

  test('DHANKOSH values (TC-28-19)', () {
    final s = allPaletteSpecs[PaletteId.dhankosh.index];
    expect(s.light.surface, const Color(0xFFF6F8FA));
    expect(s.light.primary, const Color(0xFF2873BE));
    expect(s.dark.surface, const Color(0xFF0B1418));
  });

  test('text on surface >= 4.5:1 for every palette, light and dark', () {
    for (final id in PaletteId.values) {
      for (final b in Brightness.values) {
        final c = AppTheme.build(id, b).colorScheme;
        expect(
          contrast(c.onSurface, c.surface),
          greaterThanOrEqualTo(4.5),
          reason: '${id.name} ${b.name}',
        );
        expect(
          contrast(c.onSurface, c.surfaceContainer),
          greaterThanOrEqualTo(4.5),
          reason: '${id.name} ${b.name} card',
        );
      }
    }
  });

  test('pure black levels (TC-28-03, FR-28-04)', () {
    final d = AppTheme.build(PaletteId.nitro, Brightness.dark, pureBlack: true)
        .colorScheme;
    expect(d.surface, const Color(0xFF000000));
    expect(d.surfaceContainer, const Color(0xFF0B0B0D));
    expect(d.surfaceContainerHigh, const Color(0xFF141417));
    final l = AppTheme.build(PaletteId.nitro, Brightness.light, pureBlack: true)
        .colorScheme;
    expect(l.surface, allPaletteSpecs[PaletteId.nitro.index].light.surface);
  });

  test('text scale clamp and snap (TC-28-04, FR-28-09)', () {
    expect(effectiveTextScale(1, 1.2), closeTo(1.2, 1e-9));
    expect(effectiveTextScale(1.5, 1.2), 1.5);
    expect(effectiveTextScale(1, 0.9), closeTo(0.9, 1e-9));
    expect(effectiveTextScale(1.25, 1.2), 1.3);
    expect(TextSize.of(1.07), TextSize.large);
    expect(TextSize.of(1.03), TextSize.standard);
  });

  test('semantic colours independent of palette (FR-28-05)', () {
    final a = AppTheme.build(PaletteId.fold, Brightness.light);
    final b = AppTheme.build(PaletteId.spiceDune, Brightness.light);
    expect(
      a.extensions.values.first,
      b.extensions.values.first,
    );
  });

  test('persistence round trip (TC-28-18, FR-28-12)', () async {
    final env = TestEnv();
    addTearDown(env.db.close);
    final repo = AppearanceRepositoryImpl(env.settings);
    const want = AppearanceSettings(
      mode: ThemeModeChoice.dark,
      palette: PaletteId.neoMatrix,
      pureBlack: true,
      textSize: TextSize.xl,
    );
    await repo.save(want);
    final got = await repo.watch().firstWhere(
          (s) => s.palette == PaletteId.neoMatrix && s.textSize == TextSize.xl,
        );
    expect(got.mode, ThemeModeChoice.dark);
    expect(got.pureBlack, true);
  });

  testWidgets('Customise screen applies palette immediately (TC-28-12/13)',
      (t) async {
    final env = TestEnv();
    addTearDown(env.db.close);
    late WidgetRef wref;
    await t.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(env.settings)],
        child: Consumer(
          builder: (c, ref, _) {
            wref = ref;
            final a = ref.watch(appearanceProvider);
            return MaterialApp(
              theme: AppTheme.build(a.palette, Brightness.light),
              home: const ThemingCustomisationScreen(),
            );
          },
        ),
      ),
    );
    await settle(t);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Classic'), findsWidgets);
    await t.dragUntilVisible(
      find.byKey(const Key('palette-spiceDune')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await t.tap(find.byKey(const Key('palette-spiceDune')));
    await settle(t);
    await t.pump(const Duration(milliseconds: 500));
    expect(wref.read(appearanceProvider).palette, PaletteId.spiceDune);
    final ctx = t.element(find.byType(Scaffold));
    expect(Theme.of(ctx).colorScheme.primary, const Color(0xFFA34A12));
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.pump(const Duration(seconds: 1));
  });
}
