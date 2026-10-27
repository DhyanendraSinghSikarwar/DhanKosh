import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/app/theme/backdrop.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';

void main() {
  test('TC-28-10 glow alphas: dark x strength, light x 0.62', () {
    final dark = backdropAlphas(dark: true, glowStrength: 0.25);
    expect(dark, [0.16 * 0.25, 0.13 * 0.25, 0.09 * 0.25]);
    final light = backdropAlphas(dark: false, glowStrength: 1);
    expect(light[0], closeTo(0.16 * 0.62, 1e-9));
  });

  test('FR-28-08 backdrop on by request, off on pure black', () {
    final on =
        AppTheme.build(PaletteId.dhankosh, Brightness.dark, backdrop: true);
    expect(on.extension<BackdropTheme>(), isNotNull);
    expect(on.scaffoldBackgroundColor, Colors.transparent);
    final black = AppTheme.build(
      PaletteId.dhankosh,
      Brightness.dark,
      pureBlack: true,
      backdrop: true,
    );
    expect(black.extension<BackdropTheme>(), isNull);
    expect(black.scaffoldBackgroundColor, isNot(Colors.transparent));
    expect(
      AppTheme.build(PaletteId.dhankosh, Brightness.light)
          .extension<BackdropTheme>(),
      isNull,
    );
  });

  testWidgets('FR-28-08 Backdrop paints under the page', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(PaletteId.ocean, Brightness.dark, backdrop: true),
        home: const Backdrop(child: Scaffold(body: Text('page'))),
      ),
    );
    expect(find.byKey(const Key('backdrop')), findsWidgets);
    expect(find.text('page'), findsOneWidget);
  });

  test('FR-28-10 reduceMotion defaults off and copies', () {
    expect(const AppearanceSettings().reduceMotion, isFalse);
    expect(
      const AppearanceSettings().copyWith(reduceMotion: true).reduceMotion,
      isTrue,
    );
  });
}
