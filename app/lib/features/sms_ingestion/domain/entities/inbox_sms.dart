import 'package:hisaab/features/sms_ingestion/domain/sms_ids.dart';

/// One SMS from the inbox or the live receiver.
class InboxSms {
  /// Creates an [InboxSms].
  const InboxSms({
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.sentAt = 0,
    this.nativeId = '',
  });

  /// Raw address.
  final String sender;

  /// Message text.
  final String body;

  /// Arrival time, epoch ms (`date`).
  final int receivedAt;

  /// Sent time, epoch ms (`date_sent`); 0 when unknown.
  final int sentAt;

  /// Android row id; empty for live messages.
  final String nativeId;

  /// Stable id, identical for live and scan paths (FR-02-04).
  String get messageId =>
      SmsIds.of(sender, sentAt > 0 ? sentAt : receivedAt, body);
}
