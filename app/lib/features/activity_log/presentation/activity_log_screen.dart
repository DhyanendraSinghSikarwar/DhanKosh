import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/security_providers.dart';
import 'package:hisaab/features/activity_log/domain/activity_stats.dart';
import 'package:hisaab/features/activity_log/domain/entities/activity_entry.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:intl/intl.dart';

/// Activity log (F-22): totals, sync times, source filter and entries by day.
class ActivityLogScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [now] is injectable for tests.
  const ActivityLogScreen({this.now, super.key});

  /// Clock override.
  final DateTime Function()? now;

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  ActivitySource? _filter;

  DateTime get _now => (widget.now ?? DateTime.now)();

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear log?'),
        content: const Text('Removes every entry. Transactions are not '
            'affected.'),
        actions: [
          TextButton(
            key: const Key('activity-clear-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(activityLogRepositoryProvider).clear();
  }

  static String _day(DateTime d, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(activityEntriesProvider).value ?? const [];
    final settings = ref.watch(settingsRepositoryProvider);
    final now = _now;
    final shown = [
      for (final e in entries)
        if (ActivityStats.matches(e, _filter)) e,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity log'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              key: const Key('activity-clear'),
              tooltip: 'Clear log',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TotalsCard(
            title: 'Today',
            totals: ActivityStats.today(entries, now),
          ),
          const SizedBox(height: 12),
          _TotalsCard(
            title: 'This week',
            totals: ActivityStats.week(entries, now),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<int>>(
            future: Future.wait([
              settings.read(_nextSms),
              settings.read(_nextEmail),
            ]),
            builder: (context, snap) {
              final due = [
                for (final v in snap.data ?? const <int>[])
                  if (v > now.millisecondsSinceEpoch) v,
              ]..sort();
              return _SyncCard(
                lastSms: ActivityStats.lastSms(entries),
                lastEmail: ActivityStats.lastEmail(entries),
                next: due.isEmpty
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(due.first),
              );
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _pill('All', null),
                for (final s in ActivitySource.values) _pill(s.label, s),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                key: Key('activity-empty'),
                children: [
                  Icon(Icons.history, size: 40),
                  SizedBox(height: 8),
                  Text('No activity yet'),
                  Text('Each sync is recorded here, on this phone only.'),
                ],
              ),
            )
          else
            ..._days(shown, now),
        ],
      ),
    );
  }

  static const _nextSms = SettingKey<int>('next_sms_sync_at', 0);
  static const _nextEmail = SettingKey<int>('next_email_sync_at', 0);

  Widget _pill(String label, ActivitySource? s) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          key: Key('pill-${s?.code ?? 'all'}'),
          label: Text(label),
          selected: _filter == s,
          onSelected: (_) => setState(() => _filter = _filter == s ? null : s),
        ),
      );

  List<Widget> _days(List<ActivityEntry> shown, DateTime now) {
    final out = <Widget>[];
    String? current;
    var rows = <ActivityEntry>[];
    void flush() {
      final c = current;
      if (c == null) return;
      out
        ..add(_DayCard(title: c, entries: rows))
        ..add(const SizedBox(height: 12));
    }

    for (final e in shown) {
      final d = _day(e.at, now);
      if (d != current) {
        flush();
        current = d;
        rows = [];
      }
      rows.add(e);
    }
    flush();
    return out;
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.title, required this.totals});

  final String title;
  final ActivityTotals totals;

  @override
  Widget build(BuildContext context) {
    Widget kpi(String label, int v) => Expanded(
          child: Column(
            children: [
              Text('$v', style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
    return Card(
      key: Key('activity-$title'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                kpi('SMS read', totals.sms),
                kpi('Emails read', totals.emails),
                kpi('Added', totals.added),
                kpi('Statements', totals.statements),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.lastSms,
    required this.lastEmail,
    required this.next,
  });

  final DateTime? lastSms;
  final DateTime? lastEmail;
  final DateTime? next;

  static String _t(DateTime? d, String none) =>
      d == null ? none : DateFormat('d MMM yyyy, h:mm a').format(d);

  @override
  Widget build(BuildContext context) => Card(
        key: const Key('activity-sync'),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Last SMS scan'),
              trailing: Text(_t(lastSms, 'Not yet')),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Last email sync'),
              trailing: Text(_t(lastEmail, 'Not yet')),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Next scheduled sync'),
              trailing: Text(_t(next, 'Not scheduled')),
            ),
          ],
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.title, required this.entries});

  final String title;
  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final e in entries) _EntryRow(e),
          ],
        ),
      );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow(this.e);

  final ActivityEntry e;

  @override
  Widget build(BuildContext context) {
    final err = e.error != null;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            err ? scheme.errorContainer : scheme.secondaryContainer,
        child: Icon(
          switch (e.source) {
            ActivitySource.smsScan || ActivitySource.smsLive => Icons.sms,
            ActivitySource.gmail || ActivitySource.imap => Icons.mail,
            ActivitySource.statements => Icons.description,
            ActivitySource.notifications => Icons.notifications,
          },
          size: 18,
        ),
      ),
      title: Text(ActivityStats.title(e)),
      subtitle: Text(ActivityStats.subtitle(e)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(DateFormat('h:mm a').format(e.at)),
          if (e.millis >= 1000)
            Text('${(e.millis / 1000).toStringAsFixed(1)}s'),
        ],
      ),
    );
  }
}
