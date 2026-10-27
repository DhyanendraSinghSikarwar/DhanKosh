import 'package:hisaab/core/platform_channels/alerts_channel.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_poster.dart';

/// [AlertPoster] over the native `alerts` channel (FR-21-01, FR-21-16).
/// Swallows every channel error: a failed post just returns false.
class AlertPosterImpl implements AlertPoster {
  /// Creates the poster.
  const AlertPosterImpl([this._channel = const AlertsChannel()]);

  final AlertsChannel _channel;

  /// Native channel id for [kind] (`budget`, `bills`, `cards`, `info`).
  static String channelIdFor(AlertKind kind) => switch (kind) {
        AlertKind.budget => 'budget',
        AlertKind.lowBalanceBill || AlertKind.insuranceRenewal => 'bills',
        AlertKind.cardBill => 'cards',
        _ => 'info',
      };

  @override
  Future<bool> areEnabled() async {
    try {
      return await _channel.areEnabled();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> post(AlertDecision decision) async {
    try {
      return await _channel.post(
        id: decision.notificationId,
        channelId: channelIdFor(decision.kind),
        title: decision.title,
        body: decision.body,
        route: alertRouteFor(decision.link),
        actions: [
          for (final a in decision.actions)
            {'label': a.label, 'route': alertActionRoute(a)},
        ],
        timeoutMs: decision.timeoutMs,
      );
    } on Object {
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _channel.cancel(id);
    } on Object {
      // Nothing to cancel.
    }
  }

  @override
  Future<String?> takeLaunchRoute() async {
    try {
      return await _channel.takeLaunchRoute();
    } on Object {
      return null;
    }
  }
}
