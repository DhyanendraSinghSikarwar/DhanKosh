import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';

/// Totals for one period (FR-22-07).
class ActivityTotals {
  /// Creates totals.
  const ActivityTotals({
    this.sms = 0,
    this.emails = 0,
    this.added = 0,
    this.statements = 0,
  });

  /// SMS read (scan + live).
  final int sms;

  /// Emails read.
  final int emails;

  /// Transactions added.
  final int added;

  /// Statements read.
  final int statements;
}

/// Pure derivations over the log (memory 22 section 10).
abstract final class ActivityStats {
  /// Sums [list] (FR-22-07).
  static ActivityTotals totals(Iterable<ActivityEntry> list) {
    var sms = 0;
    var emails = 0;
    var added = 0;
    var statements = 0;
    for (final e in list) {
      if (e.source == ActivitySource.smsScan ||
          e.source == ActivitySource.smsLive) {
        sms += e.read;
      }
      emails += e.emails;
      added += e.added;
      statements += e.statements;
    }
    return ActivityTotals(
      sms: sms,
      emails: emails,
      added: added,
      statements: statements,
    );
  }

  /// Midnight on the Monday on or before [now].
  static DateTime weekStart(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// Entries since local midnight.
  static ActivityTotals today(List<ActivityEntry> l, DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    return totals(l.where((e) => !e.at.isBefore(start)));
  }

  /// Entries since the week start.
  static ActivityTotals week(List<ActivityEntry> l, DateTime now) {
    final start = weekStart(now);
    return totals(l.where((e) => !e.at.isBefore(start)));
  }

  /// Newest error-free SMS scan (FR-22-08).
  static DateTime? lastSms(List<ActivityEntry> l) {
    for (final e in l) {
      if (e.source == ActivitySource.smsScan && e.error == null) return e.at;
    }
    return null;
  }

  /// Newest error-free email run (FR-22-08).
  static DateTime? lastEmail(List<ActivityEntry> l) {
    for (final e in l) {
      if ((e.source == ActivitySource.gmail ||
              e.source == ActivitySource.imap) &&
          e.error == null) {
        return e.at;
      }
    }
    return null;
  }

  /// Pill filter (FR-22-09).
  static bool matches(ActivityEntry e, ActivitySource? filter) {
    if (filter == null) return true;
    if (filter == ActivitySource.statements) {
      return e.source == ActivitySource.statements || e.statements > 0;
    }
    return e.source == filter;
  }

  /// Row title with the run count (FR-22-10).
  static String title(ActivityEntry e) =>
      e.runs > 1 ? '${e.source.label} · ×${e.runs}' : e.source.label;

  /// Row subtitle (FR-22-10).
  static String subtitle(ActivityEntry e) {
    if (e.source == ActivitySource.problems) {
      return '${e.read} unreadable${e.note == null ? '' : ' from ${e.note}'}';
    }
    if (e.error != null) return 'Failed: ${e.error}';
    final parts = <String>[];
    if (e.read > 0) {
      if (e.source == ActivitySource.notifications) {
        parts.add('${e.read} notifications');
      } else if ((e.source == ActivitySource.smsScan ||
              e.source == ActivitySource.smsLive) &&
          e.relevant != e.read) {
        parts.add('${e.read} SMS, ${e.relevant} from banks');
      } else {
        parts.add('${e.read} SMS');
      }
    }
    if (e.emails > 0) parts.add('${e.emails} emails');
    parts.add('${e.added} added');
    if (e.merged > 0) parts.add('${e.merged} merged');
    if (e.review > 0) parts.add('${e.review} to review');
    if (e.skipped > 0) parts.add('${e.skipped} duplicates');
    if (e.statements > 0) parts.add('${e.statements} statements');
    if (e.locked > 0) parts.add('${e.locked} locked');
    if (e.note != null) parts.add('Skipped: ${e.note}');
    return parts.join(' · ');
  }
}
