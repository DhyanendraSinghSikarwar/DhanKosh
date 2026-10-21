import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/localization/data/language_pack_remote_impl.dart';
import 'package:hisaab/features/localization/data/language_pack_store_impl.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/localization/presentation/language_controller.dart';
import 'package:hisaab/features/theming_customisation/data/appearance_repository_impl.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';
import 'package:path_provider/path_provider.dart';

/// Appearance persistence (F-28).
final appearanceRepositoryProvider = Provider<AppearanceRepository>(
  (ref) => AppearanceRepositoryImpl(ref.watch(settingsRepositoryProvider)),
);

/// Live appearance stream.
final appearanceStreamProvider = StreamProvider<AppearanceSettings>(
  (ref) => ref.watch(appearanceRepositoryProvider).watch(),
);

/// Current appearance; defaults while loading or on error (FR-28-03).
final appearanceProvider = Provider<AppearanceSettings>(
  (ref) =>
      ref.watch(appearanceStreamProvider).value ?? const AppearanceSettings(),
);

/// Language packs live in app-private storage (FR-29-18).
final languagePackStoreProvider = Provider<LanguagePackStore>(
  (ref) => LanguagePackStoreImpl(() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/lang');
  }),
);

/// Remote pack source (FR-29-06).
final languagePackRemoteProvider = Provider<LanguagePackRemote>(
  (ref) => LanguagePackRemoteImpl(),
);

/// Active language and packs (F-29).
final languageProvider = NotifierProvider<LanguageController, LanguageState>(
  () => LanguageController(
    (ref) => LanguagePorts(
      ref.watch(languagePackStoreProvider),
      ref.watch(languagePackRemoteProvider),
      ref.watch(settingsRepositoryProvider),
    ),
  ),
);
