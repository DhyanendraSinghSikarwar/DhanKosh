import 'package:hisaab/core/platform_channels/sms_channel.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';

InboxSms _toInbox(RawSms r) => InboxSms(
      sender: r.sender,
      body: r.body,
      receivedAt: r.timestamp,
      sentAt: r.sentTimestamp,
    );

/// [SmsLiveSource] over the `sms` channel and `sms_live` events (FR-02-01).
class SmsLiveSourceImpl implements SmsLiveSource {
  /// Creates the source.
  const SmsLiveSourceImpl(this._channel);

  final SmsChannel _channel;

  @override
  Stream<InboxSms> get live => _channel.liveMessages().map(_toInbox);

  @override
  Future<List<InboxSms>> drainPending() async => [
        for (final r in await _channel.drainPending()) _toInbox(r),
      ];

  @override
  Future<void> configure({
    required bool enabled,
    required String senderPattern,
  }) =>
      _channel.configureLive(enabled: enabled, senderPattern: senderPattern);
}
