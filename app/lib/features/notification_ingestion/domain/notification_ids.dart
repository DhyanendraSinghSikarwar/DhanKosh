import 'dart:convert';
import 'dart:typed_data';

import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ids.dart';

/// Message identity for notifications (FR-04-10).
abstract final class NotificationIds {
  /// `"app:" + hex(first16bytes(SHA256(package|key|text)))`; a re-post of the
  /// same notification has the same id.
  static String of(AppNotification n) {
    final digest = SmsIds.sha256(
      Uint8List.fromList(
        utf8.encode('${n.packageName}|${n.key}|${n.joinedText}'),
      ),
    );
    final hex =
        digest.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'app:$hex';
  }
}
