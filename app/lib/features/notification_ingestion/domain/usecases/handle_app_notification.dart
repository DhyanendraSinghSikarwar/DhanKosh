import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ids.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';
import 'package:parser_core/parser_core.dart';

/// Result of one notification: an outcome or a generic skip, never text.
class NotificationResult {
  /// Ingested with [outcome].
  const NotificationResult.ingested(IngestOutcome this.outcome)
      : skip = null,
        reason = null;

  /// Not ingested for [skip]; [reason] is the parser's generic note, if any.
  const NotificationResult.skipped(NotificationSkip this.skip, [this.reason])
      : outcome = null;

  /// Pipeline outcome; null when skipped.
  final IngestOutcome? outcome;

  /// Skip kind; null when ingested.
  final NotificationSkip? skip;

  /// Parser's generic reason.
  final String? reason;
}

/// Allow-list, summary/ongoing, chat guard and setting checks, then parse and
/// ingest as Source.app (FR-04-01..03, FR-04-05, FR-04-06, FR-04-10,
/// FR-04-11).
class HandleAppNotification {
  /// Creates the use case.
  const HandleAppNotification({
    required NotificationSettingsRepository settings,
    required IngestMessage ingest,
  })  : _settings = settings,
        _ingest = ingest;

  final NotificationSettingsRepository _settings;
  final IngestMessage _ingest;

  static final _chatPayment = RegExp(
    r'^\s*(?:you\s+(?:have\s+)?(?:paid|sent|received)'
    r'|payment\s+(?:of|to|from|successful|received|sent|completed)'
    r'|(?:₹|rs\.?|inr)\s?[\d,]+(?:\.\d{1,2})?\s+(?:paid|sent|received))',
    caseSensitive: false,
  );

  /// WhatsApp: payment notifications only, never a conversation (FR-04-05).
  static bool isChatPayment(AppNotification n) {
    if (n.category == 'msg') return false;
    if (n.hasMessagesExtra) return false;
    final ch = n.channelId;
    if (ch != null && ch.toLowerCase().contains('chat')) return false;
    return n.joinedText.split('\n').any(_chatPayment.hasMatch);
  }

  /// Handles [n].
  Future<NotificationResult> call(AppNotification n) async {
    final app = PaymentApps.byPackage(n.packageName);
    if (app == null) {
      return const NotificationResult.skipped(NotificationSkip.notWatched);
    }
    if (n.isGroupSummary || n.isOngoing) {
      return const NotificationResult.skipped(NotificationSkip.ignoredKind);
    }
    if (n.parts.isEmpty) {
      return const NotificationResult.skipped(NotificationSkip.empty);
    }
    if (app.isChatApp && !isChatPayment(n)) {
      return const NotificationResult.skipped(NotificationSkip.chat);
    }
    if (!await _settings.isEnabled()) {
      return const NotificationResult.skipped(NotificationSkip.settingOff);
    }
    final d = await _ingest.detail(
      InboxSms(
        sender: app.displayName,
        body: n.joinedText,
        receivedAt: n.postTime,
      ),
      source: Source.app,
      messageId: NotificationIds.of(n),
    );
    return switch (d.parse) {
      Parsed() => NotificationResult.ingested(d.outcome),
      Rejected(:final reason) ||
      NotATransaction(:final reason) =>
        NotificationResult.skipped(NotificationSkip.parser, reason),
    };
  }
}
