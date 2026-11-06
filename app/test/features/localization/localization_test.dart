// FR-29: bundled YAML catalogues, switching language, placeholder safety.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/appearance_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/localization/presentation/language_screen.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class _Mem implements LanguageCatalogue {
  _Mem(this.files);
  final Map<Language, String> files;
  @override
  Future<String?> load(Language l) async => files[l];
}

String _yaml(Map<String, String> s) => [
      'version: 1',
      'code: hi',
      'strings:',
      for (final e in s.entries) '  "${e.key}": "${e.value}"',
    ].join('\n');

String _t(String s) => t(s);

void main() {
  tearDown(() => I18n.current = const Translator());

  test('t falls back to English and fills args (FR-29-01)', () {
    I18n.current = const Translator({'Hello {n}': 'नमस्ते {n}'});
    expect(t('Hello {n}', args: {'n': 3}), 'नमस्ते 3');
    expect(t('Unknown {n}', args: {'n': 3}), 'Unknown 3');
    expect(I18n.current.plural(1, '{n} item', '{n} items'), '1 item');
    expect(I18n.current.plural(2, '{n} item', '{n} items'), '2 items');
  });

  test('parseCatalogue ignores blanks and rejects bad files (FR-29-05)', () {
    expect(parseCatalogue(_yaml({'a': 'b', 'c': ' '})), {'a': 'b'});
    expect(parseCatalogue(_yaml({'a': ''})), isEmpty);
    expect(
      () => parseCatalogue('strings: [1'),
      throwsA(isA<CatalogueFormatException>()),
    );
    expect(
      () => parseCatalogue('version: 1'),
      throwsA(isA<CatalogueFormatException>()),
    );
  });

  test("every bundled catalogue keeps its keys' placeholders (FR-29-13)", () {
    final token = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');
    Set<String> tokens(String s) =>
        token.allMatches(s).map((m) => m.group(0)!).toSet();
    for (final l in Language.values) {
      final file = File('assets/l10n/${l.code}.yaml');
      expect(file.existsSync(), isTrue, reason: '${l.code}.yaml is bundled');
      parseCatalogue(file.readAsStringSync()).forEach((k, v) {
        expect(tokens(v), tokens(k), reason: '${l.code}: $k');
      });
    }
  });

  testWidgets('Language screen switches at once and remembers (FR-29-03/08)',
      (tester) async {
    final env = TestEnv();
    addTearDown(env.db.close);
    final cat = _Mem({
      Language.hi: _yaml({'Language': 'भाषा', 'Hindi': 'हिन्दी'}),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          languageCatalogueProvider.overrideWithValue(cat),
        ],
        child: const MaterialApp(home: LanguageScreen()),
      ),
    );
    await settle(tester);
    expect(find.text('Built in'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lang-hi')));
    await settle(tester);
    expect(_t('Language'), 'भाषा');
    expect(await env.settings.read(languageKey), 'hi');

    await tester.tap(find.byKey(const Key('lang-en')));
    await settle(tester);
    expect(_t('Language'), 'Language');
    expect(await env.settings.read(languageKey), 'en');
  });

  testWidgets('a language with no file falls back to English (FR-29-10)',
      (tester) async {
    final env = TestEnv();
    addTearDown(env.db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          languageCatalogueProvider.overrideWithValue(_Mem({})),
        ],
        child: const MaterialApp(home: LanguageScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('lang-ta')));
    await settle(tester);
    expect(_t('Language'), 'Language');
  });
}
