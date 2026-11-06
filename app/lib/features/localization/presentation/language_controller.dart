import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Language screen state (FR-29-08).
class LanguageState {
  /// Creates state.
  const LanguageState({this.active = Language.en, this.message});

  /// In-use language.
  final Language active;

  /// One-shot snackbar text.
  final String? message;
}

/// Ports used by [LanguageController].
class LanguagePorts {
  /// Creates the bundle.
  const LanguagePorts(this.catalogue, this.settings);

  /// Bundled catalogues.
  final LanguageCatalogue catalogue;

  /// Settings store.
  final SettingsRepository settings;
}

/// Owns the active language and the global [I18n] translator.
class LanguageController extends Notifier<LanguageState> {
  /// Creates the controller; ports are injected via [LanguagePorts].
  LanguageController(this._ports);

  final LanguagePorts Function(Ref ref) _ports;

  late LanguageCatalogue catalogue;
  late SettingsRepository settings;

  @override
  LanguageState build() {
    final p = _ports(ref);
    catalogue = p.catalogue;
    settings = p.settings;
    unawaited(Future<void>.microtask(restore));
    return const LanguageState();
  }

  Future<Map<String, String>> _strings(Language l) async {
    if (l.builtIn) return const {};
    final body = await catalogue.load(l);
    return body == null ? const {} : parseCatalogue(body);
  }

  /// Restores the saved language; English on any error (FR-29-10).
  Future<void> restore() async {
    try {
      final l = Language.of(await settings.read(languageKey));
      _apply(l, await _strings(l));
    } on Object {
      _apply(Language.en, const {});
    }
  }

  void _apply(Language l, Map<String, String> strings) {
    I18n.current = Translator(strings);
    state = LanguageState(active: l, message: state.message);
  }

  /// Switches to [l]; every screen rebuilds at once (FR-29-03, FR-29-08).
  Future<void> choose(Language l) async {
    try {
      _apply(l, await _strings(l));
      await settings.write(languageKey, l.code);
    } on Object {
      _apply(Language.en, const {});
      state = LanguageState(
        message: t(
          "Couldn't load {lang}. Showing English.",
          args: {'lang': l.english},
        ),
      );
    }
  }

  /// Clears the one-shot message.
  void messageShown() => state = LanguageState(active: state.active);
}
