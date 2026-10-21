import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/appearance_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/localization/data/language_pack_store_impl.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/localization/presentation/language_screen.dart';

import '../../support/test_env.dart';
import '../../support/ui_harness.dart';

class _MemStore implements LanguagePackStore {
  final files = <Language, String>{};
  @override
  Future<Set<Language>> downloaded() async => files.keys.toSet();
  @override
  Future<String?> read(Language l) async => files[l];
  @override
  Future<void> write(Language l, String b) async => files[l] = b;
  @override
  Future<void> delete(Language l) async => files.remove(l);
}

class _Remote implements LanguagePackRemote {
  _Remote(this.body);
  String? body;
  @override
  Future<String> fetch(Language l) async =>
      body ?? (throw const SocketException('offline'));
}

String _pack(Map<String, String> s) =>
    jsonEncode({'version': 1, 'code': 'hi', 'strings': s});

void main() {
  tearDown(() => I18n.current = const Translator());

  test('t falls back to English and fills args (FR-29-01)', () {
    I18n.current = const Translator({'Hello {n}': 'नमस्ते {n}'});
    expect(t('Hello {n}', args: {'n': 3}), 'नमस्ते 3');
    expect(t('Unknown {n}', args: {'n': 3}), 'Unknown 3');
    expect(I18n.current.plural(1, '{n} item', '{n} items'), '1 item');
    expect(I18n.current.plural(2, '{n} item', '{n} items'), '2 items');
  });

  test('parsePack ignores blanks and rejects empty (FR-29-05/06)', () {
    expect(parsePack(_pack({'a': 'b', 'c': ' '})), {'a': 'b'});
    expect(
      () => parsePack(_pack({'a': ''})),
      throwsA(isA<PackFormatException>()),
    );
    expect(() => parsePack('{bad'), throwsA(isA<PackFormatException>()));
  });

  test('file store atomic write, list, delete (FR-29-07)', () async {
    final d = Directory.systemTemp.createTempSync('lang');
    addTearDown(() => d.deleteSync(recursive: true));
    final s = LanguagePackStoreImpl(() async => d);
    await s.write(Language.hi, _pack({'a': 'b'}));
    expect(await s.downloaded(), {Language.hi});
    expect(await s.read(Language.hi), contains('"b"'));
    await s.delete(Language.hi);
    expect(await s.downloaded(), isEmpty);
  });

  testWidgets('Language screen: download, use, remove, failure (FR-29-08..12)',
      (t) async {
    final env = TestEnv();
    addTearDown(env.db.close);
    final store = _MemStore();
    final remote = _Remote(null);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(env.settings),
          languagePackStoreProvider.overrideWithValue(store),
          languagePackRemoteProvider.overrideWithValue(remote),
        ],
        child: const MaterialApp(home: LanguageScreen()),
      ),
    );
    await settle(t);
    expect(find.text('Built in'), findsOneWidget);
    expect(find.text('Hindi · Tap to download'), findsOneWidget);

    await t.tap(find.byKey(const Key('lang-hi')));
    await settle(t);
    expect(find.textContaining("Couldn't download Hindi"), findsOneWidget);

    remote.body = _pack({'Language': 'भाषा', 'Hindi': 'हिन्दी'});
    await t.tap(find.byKey(const Key('lang-hi')));
    await settle(t);
    expect(t_('Language'), 'भाषा');
    expect(find.text('भाषा'), findsWidgets);
    expect(store.files.containsKey(Language.hi), true);
    expect(await env.settings.read(languageKey), 'hi');

    await t.tap(find.byKey(const Key('lang-en')));
    await settle(t);
    await t.tap(find.byKey(const Key('lang-remove-hi')));
    await settle(t);
    expect(store.files, isEmpty);
    expect(t_('Language'), 'Language');
  });
}

String t_(String s) => t(s);
