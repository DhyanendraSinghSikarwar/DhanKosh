import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/localization/data/asset_language_catalogue.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/localization/presentation/language_controller.dart';
import 'package:hisaab/features/theming_customisation/data/appearance_repository_impl.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';

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

/// Bundled language catalogues (FR-29-05).
final languageCatalogueProvider = Provider<LanguageCatalogue>(
  (ref) => AssetLanguageCatalogue(),
);

/// Active language (F-29).
final languageProvider = NotifierProvider<LanguageController, LanguageState>(
  () => LanguageController(
    (ref) => LanguagePorts(
      ref.watch(languageCatalogueProvider),
      ref.watch(settingsRepositoryProvider),
    ),
  ),
);

/// Day the budget month starts on (FR-10-25).
final cycleDayProvider = StreamProvider<int>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(AppearanceKeys.cycleDay),
);
