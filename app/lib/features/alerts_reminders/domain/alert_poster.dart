import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';

/// Posts and cancels OS notifications (FR-21-01, FR-21-16). Implemented over
/// the native `alerts` channel; never throws.
abstract interface class AlertPoster {
  /// True when the OS allows notifications.
  Future<bool> areEnabled();

  /// Posts [decision]; true only when the OS accepted it.
  Future<bool> post(AlertDecision decision);

  /// Cancels notification [id].
  Future<void> cancel(int id);

  /// Route (`/transaction/3`) of the tapped alert that launched the app, once.
  Future<String?> takeLaunchRoute();
}

/// Persisted alert settings (FR-21-18).
abstract interface class AlertSettingsRepository {
  /// Current settings.
  Future<AlertSettings> read();

  /// Live settings.
  Stream<AlertSettings> watch();

  /// Saves the transaction-alerts switch.
  Future<void> setTransactionNotifications({required bool value});

  /// Saves the budget percent (80, 90 or 95).
  Future<void> setBudgetAlertPercent(int percent);

  /// Saves the card-reminders switch.
  Future<void> setCardDueReminders({required bool value});

  /// Turns the weekly summary on or off (FR-21-21).
  Future<void> setWeeklySummary({required bool value});
}

/// Maps a `hisaab://` link to an in-app route (FR-21-15).
String alertRouteFor(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null || uri.scheme != 'hisaab') return '/home';
  final host = uri.host;
  final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  switch (host) {
    case 'transaction':
      return seg.isEmpty ? '/transactions' : '/transaction/${seg.first}';
    case 'account':
      return seg.isEmpty ? '/accounts' : '/accounts/${seg.first}';
    case 'budgets':
      return '/budgets';
    case 'bills':
      return '/bills';
    case 'statements':
      final unlock = int.tryParse(uri.queryParameters['unlock'] ?? '');
      return unlock == null ? '/statements' : '/statements?unlock=$unlock';
    default:
      return '/home';
  }
}
