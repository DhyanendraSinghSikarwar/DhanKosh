import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Language screen state (FR-29-08, FR-29-12).
class LanguageState {
  /// Creates state.
  const LanguageState({
    this.active = Language.en,
    this.downloaded = const {},
    this.busy,
    this.message,
  });

  /// In-use language.
  final Language active;

  /// Packs on the phone.
  final Set<Language> downloaded;

  /// Language being downloaded or applied.
  final Language? busy;

  /// One-shot snackbar text.
  final String? message;

  /// Copy with changes; [message] and [busy] are replaced as given.
  LanguageState copy({
    Language? active,
    Set<Language>? downloaded,
    Language? busy,
    String? message,
  }) =>
      LanguageState(
        active: active ?? this.active,
        downloaded: downloaded ?? this.downloaded,
        busy: busy,
        message: message,
      );
}

/// Ports used by [LanguageController].
class LanguagePorts {
  /// Creates the bundle.
  const LanguagePorts(this.store, this.remote, this.settings);

  /// Pack storage.
  final LanguagePackStore store;

  /// Pack source.
  final LanguagePackRemote remote;

  /// Settings store.
  final SettingsRepository settings;
}

/// Owns the active language, packs and the global [I18n] translator.
class LanguageController extends Notifier<LanguageState> {
  /// Creates the controller; ports are injected via [LanguagePorts].
  LanguageController(this._ports);

  final LanguagePorts Function(Ref ref) _ports;

  late LanguagePackStore store;
  late LanguagePackRemote remote;
  late SettingsRepository settings;

  @override
  LanguageState build() {
    final p = _ports(ref);
    store = p.store;
    remote = p.remote;
    settings = p.settings;
    unawaited(Future<void>.microtask(restore));
    return const LanguageState();
  }

  /// Restores the saved language; English on any error (FR-29-10).
  Future<void> restore() async {
    try {
      final dl = await store.downloaded();
      final l = Language.of(await settings.read(languageKey));
      if (l.builtIn) {
        _apply(Language.en, const {});
        state = state.copy(downloaded: dl);
        return;
      }
      final body = await store.read(l);
      _apply(l, parsePack(body ?? ''));
      state = state.copy(active: l, downloaded: dl);
    } on Object {
      _apply(Language.en, const {});
    }
  }

  void _apply(Language l, Map<String, String> strings) {
    I18n.current = Translator(strings);
    state = state.copy(active: l, downloaded: state.downloaded);
  }

  /// Picks [l]: downloads first when absent (FR-29-08, FR-29-12).
  Future<void> choose(Language l) async {
    if (state.busy != null) return;
    if (l.builtIn) {
      _apply(l, const {});
      await settings.write(languageKey, l.code);
      return;
    }
    state =
        state.copy(active: state.active, downloaded: state.downloaded, busy: l);
    var downloaded = state.downloaded;
    try {
      if (!downloaded.contains(l)) {
        final body = await remote.fetch(l);
        parsePack(body);
        await store.write(l, body);
        downloaded = {...downloaded, l};
      }
      final strings = parsePack(await store.read(l) ?? '');
      state = state.copy(active: state.active, downloaded: downloaded);
      _apply(l, strings);
      await settings.write(languageKey, l.code);
    } on PackFormatException {
      state = state.copy(
        active: state.active,
        downloaded: downloaded,
        message: t('That language pack is damaged. Download it again.'),
      );
    } on Object {
      state = state.copy(
        active: state.active,
        downloaded: downloaded,
        message: t(
          "Couldn't download {lang}. Check your connection.",
          args: {'lang': l.english},
        ),
      );
    }
  }

  /// Removes a downloaded pack; back to English if active (FR-29-09).
  Future<void> remove(Language l) async {
    if (l.builtIn) return;
    await store.delete(l);
    final dl = {...state.downloaded}..remove(l);
    state = state.copy(active: state.active, downloaded: dl);
    if (state.active == l) {
      _apply(Language.en, const {});
      await settings.write(languageKey, 'en');
    }
  }

  /// Clears the one-shot message.
  void messageShown() => state = state.copy(
        active: state.active,
        downloaded: state.downloaded,
        busy: state.busy,
      );
}
