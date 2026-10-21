import 'package:hisaab/app/di/phase4_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_poster_impl.dart';
import 'package:hisaab/features/alerts_reminders/data/alert_settings_store.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerts_engine.dart';
import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'alerts_providers.g.dart';

// F-21 alerts wiring. Presentation reads the domain interfaces only.

/// Notification poster over the native `alerts` channel; override in tests.
@Riverpod(keepAlive: true)
AlertPoster alertPoster(Ref ref) => const AlertPosterImpl();

/// Persisted alert settings.
@Riverpod(keepAlive: true)
AlertSettingsRepository alertSettingsRepository(Ref ref) =>
    AlertSettingsStore(ref.watch(settingsRepositoryProvider));

/// Alert settings, live.
@riverpod
Stream<AlertSettings> alertSettings(Ref ref) =>
    ref.watch(alertSettingsRepositoryProvider).watch();

/// Runs all alert checks and posts the results.
@Riverpod(keepAlive: true)
AlertsEngine alertsEngine(Ref ref) => AlertsEngine(
      budgets: ref.watch(budgetRepositoryProvider),
      recurring: ref.watch(recurringRepositoryProvider),
      accounts: ref.watch(accountRepositoryProvider),
      alerted: ref.watch(alertedKeyStoreProvider),
      poster: ref.watch(alertPosterProvider),
      settings: ref.watch(alertSettingsRepositoryProvider),
    );

/// Foreign spend counts per currency, live (F-23).
@riverpod
Stream<List<CurrencyCount>> forexForeign(Ref ref) =>
    ref.watch(forexRepositoryProvider).watchForeign();
