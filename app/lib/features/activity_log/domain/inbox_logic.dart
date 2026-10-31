import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';

/// Inbox groups of the Activity log (FR-22-17).
enum InboxGroup {
  imports('Imports'),
  scans('Scans'),
  alerts('Alerts'),
  problems('Problems');

  const InboxGroup(this.label);

  /// Display name.
  final String label;
}

/// Pure Inbox rules over the activity log (memory 22 section 10).
abstract final class InboxLogic {
  /// Group of [e]: failed runs and problem entries are problems; email and
  /// statement runs are imports; payment-app notifications are alerts; the
  /// rest are scans (FR-22-17).
  static InboxGroup groupOf(ActivityEntry e) {
    if (e.source == ActivitySource.problems || e.error != null) {
      return InboxGroup.problems;
    }
    return switch (e.source) {
      ActivitySource.gmail ||
      ActivitySource.imap ||
      ActivitySource.statements =>
        InboxGroup.imports,
      ActivitySource.notifications ||
      ActivitySource.alerts =>
        InboxGroup.alerts,
      ActivitySource.smsScan ||
      ActivitySource.smsLive =>
        e.statements > 0 ? InboxGroup.imports : InboxGroup.scans,
      ActivitySource.problems => InboxGroup.problems,
    };
  }

  /// Entries strictly newer than [lastSeenMs] (FR-22-16).
  static int unread(Iterable<ActivityEntry> entries, int lastSeenMs) =>
      entries.where((e) => e.at.millisecondsSinceEpoch > lastSeenMs).length;

  /// Whether [e] is unread.
  static bool isUnread(ActivityEntry e, int lastSeenMs) =>
      e.at.millisecondsSinceEpoch > lastSeenMs;

  static final _code =
      RegExp(r'^[A-Z]{2}-[A-Z][A-Z0-9]{2,7}$|^[A-Z][A-Z0-9]{2,9}$');
  static final _digitRun = RegExp(r'\d{4,}');

  /// Sender header safe to store (FR-22-15): upper-case alphanumeric codes
  /// such as `AX-HDFCBK`. Phone numbers and anything else become `OTHER`.
  static String senderCode(String sender) {
    final s = sender.trim().toUpperCase();
    if (!_code.hasMatch(s) || _digitRun.hasMatch(s)) return 'OTHER';
    return s;
  }

  /// The most frequent sender code of [senders], or null when empty.
  static String? topSenderCode(Iterable<String> senders) {
    final counts = <String, int>{};
    for (final s in senders) {
      counts.update(senderCode(s), (v) => v + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return null;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }
}
