/// One notification from an allow-listed app, as the native listener sent it
/// (FR-04-04).
class AppNotification {
  /// Creates an [AppNotification].
  const AppNotification({
    required this.packageName,
    required this.key,
    required this.postTime,
    required this.parts,
    this.isGroupSummary = false,
    this.isOngoing = false,
    this.category,
    this.hasMessagesExtra = false,
    this.channelId,
  });

  /// Posting app package.
  final String packageName;

  /// `StatusBarNotification.key`.
  final String key;

  /// Post time, epoch ms.
  final int postTime;

  /// Trimmed, distinct, non-empty text parts.
  final List<String> parts;

  /// Group summary notification.
  final bool isGroupSummary;

  /// Ongoing notification.
  final bool isOngoing;

  /// `Notification.category`.
  final String? category;

  /// Conversation-style notification.
  final bool hasMessagesExtra;

  /// Notification channel id.
  final String? channelId;

  /// Parts joined by newline: the raw text stored and hashed.
  String get joinedText => parts.join('\n');
}

/// Why a notification was not ingested; generic text only (FR-04-06,
/// FR-04-17).
enum NotificationSkip {
  /// Package not allow-listed.
  notWatched('not a watched app'),

  /// Summary or ongoing.
  ignoredKind('summary or ongoing'),

  /// WhatsApp chat.
  chat('chat message'),

  /// In-app switch off.
  settingOff('app notifications are off in settings'),

  /// Parser rejected it; the parser's own generic reason is attached.
  parser('not a payment'),

  /// Nothing readable.
  empty('no text');

  const NotificationSkip(this.text);

  /// Generic reason.
  final String text;
}
