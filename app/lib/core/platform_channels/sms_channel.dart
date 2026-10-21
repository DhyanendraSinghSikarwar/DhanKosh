import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// One SMS as returned by the native layer.
class RawSms {
  /// Creates a [RawSms].
  const RawSms({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.sentTimestamp,
  });

  /// Parses a native map (`id`, `sender`, `body`, `timestamp`, `sentTimestamp`).
  factory RawSms.fromMap(Map<Object?, Object?> m) => RawSms(
        id: (m['id'] ?? '').toString(),
        sender: (m['sender'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
        sentTimestamp: (m['sentTimestamp'] as num?)?.toInt() ?? 0,
      );

  /// Native row id; empty for live messages.
  final String id;

  /// Raw address.
  final String sender;

  /// Message text.
  final String body;

  /// Arrival time, epoch ms (`date`).
  final int timestamp;

  /// Sent time, epoch ms (`date_sent`), 0 when unknown.
  final int sentTimestamp;
}

/// One page of inbox rows, oldest first.
class RawSmsPage {
  /// Creates a [RawSmsPage].
  const RawSmsPage({
    required this.items,
    required this.examined,
    required this.nextSince,
    required this.nextAfterId,
    required this.done,
  });

  /// Parses a native map.
  factory RawSmsPage.fromMap(Map<Object?, Object?> m) => RawSmsPage(
        items: [
          for (final e in (m['items'] as List<Object?>? ?? const []))
            RawSms.fromMap(e! as Map<Object?, Object?>),
        ],
        examined: (m['examined'] as num?)?.toInt() ?? 0,
        nextSince: (m['nextSince'] as num?)?.toInt() ?? 0,
        nextAfterId: (m['nextAfterId'] as num?)?.toInt() ?? 0,
        done: m['done'] as bool? ?? true,
      );

  /// Rows whose sender matched (all rows when no pattern was sent).
  final List<RawSms> items;

  /// Rows examined in this page, matched or not.
  final int examined;

  /// Pass as `sinceMillis` to continue.
  final int nextSince;

  /// Pass as `afterId` to continue.
  final int nextAfterId;

  /// True when the inbox is exhausted.
  final bool done;
}

/// Typed wrapper for the `sms` platform channel (+ `sms_live` events).
///
/// Native errors surface as `ChannelFailure`; code `permission` means
/// READ_SMS is missing.
class SmsChannel extends ChannelBase {
  /// Creates the wrapper over the `sms` channel.
  const SmsChannel() : super(_channel);

  static const MethodChannel _channel = MethodChannel(ChannelNames.sms);
  static const EventChannel _live = EventChannel(ChannelNames.smsLive);

  /// Whether READ_SMS and RECEIVE_SMS are both granted.
  Future<bool> hasPermission() async =>
      (await invoke<bool>('hasPermission')) ?? false;

  /// Reads inbox rows with `date > sinceMillis` or
  /// (`date == sinceMillis` and `_id > afterId`), oldest first (FR-02-09).
  ///
  /// Omit [afterId] on the first call. [senderPattern] is a case-insensitive
  /// regex tested against the address before the body is read.
  Future<RawSmsPage> readInbox({
    required int sinceMillis,
    int? afterId,
    int limit = 500,
    String? senderPattern,
  }) async {
    final map = await invoke<Map<Object?, Object?>>('readInbox', {
      'sinceMillis': sinceMillis,
      if (afterId != null) 'afterId': afterId,
      'limit': limit,
      if (senderPattern != null) 'senderPattern': senderPattern,
    });
    return RawSmsPage.fromMap(map ?? const {});
  }

  /// Returns and clears live messages queued while Dart was not listening.
  Future<List<RawSms>> drainPending() async {
    final list = await invoke<List<Object?>>('drainPending');
    return [
      for (final e in list ?? const <Object?>[])
        RawSms.fromMap(e! as Map<Object?, Object?>),
    ];
  }

  /// Pushes the pause flag and sender regex the native receiver filters with
  /// (FR-02-05). Until called, the receiver queues nothing.
  Future<void> configureLive({
    required bool enabled,
    required String senderPattern,
  }) =>
      invoke<void>('configureLive', {
        'enabled': enabled,
        'senderPattern': senderPattern,
      });

  /// Live messages while the engine is running.
  Stream<RawSms> liveMessages() => _live.receiveBroadcastStream().map(
        (e) => RawSms.fromMap(e! as Map<Object?, Object?>),
      );
}
