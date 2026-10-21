import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/core/platform_channels/sms_channel.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';

InboxSms _toInbox(RawSms r) => InboxSms(
      sender: r.sender,
      body: r.body,
      receivedAt: r.timestamp,
      sentAt: r.sentTimestamp,
      nativeId: r.id,
    );

/// [SmsInboxSource] over the native `sms` channel (FR-02-09).
class SmsInboxSourceImpl implements SmsInboxSource {
  /// Creates the source. [senderPattern] lets native skip bodies early.
  const SmsInboxSourceImpl(this._channel, {this.senderPattern});

  final SmsChannel _channel;

  /// Optional native-side address regex; Dart `accept` is always applied too.
  final String? senderPattern;

  @override
  Future<SmsReadStats> readBatches({
    required int since,
    required int batchSize,
    required bool Function(String sender) accept,
    required Future<void> Function(List<InboxSms> batch) onBatch,
  }) async {
    var from = since;
    int? afterId;
    var examined = 0;
    var last = 0;
    while (true) {
      final RawSmsPage page;
      try {
        page = await _channel.readInbox(
          sinceMillis: from,
          afterId: afterId,
          limit: batchSize,
          senderPattern: senderPattern,
        );
      } on ChannelFailure catch (e) {
        if (e.code == 'permission') {
          throw const PermissionFailure('READ_SMS not granted');
        }
        rethrow;
      }
      examined += page.examined;
      if (page.examined > 0) last = page.nextSince;
      final accepted = [
        for (final r in page.items)
          if (accept(r.sender)) _toInbox(r),
      ];
      if (accepted.isNotEmpty) await onBatch(accepted);
      if (page.done || page.examined == 0) break;
      from = page.nextSince;
      afterId = page.nextAfterId;
    }
    return SmsReadStats(examined: examined, lastTimestamp: last);
  }
}
