import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_models.dart';

/// Alerts settings: switches, budget percent and the OS permission state
/// (FR-21-17, FR-21-18).
class AlertsRemindersScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AlertsRemindersScreen({super.key});

  @override
  ConsumerState<AlertsRemindersScreen> createState() =>
      _AlertsRemindersScreenState();
}

class _AlertsRemindersScreenState extends ConsumerState<AlertsRemindersScreen>
    with WidgetsBindingObserver {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final on = await ref.read(alertPosterProvider).areEnabled();
    if (mounted) setState(() => _enabled = on);
  }

  Future<void> _allow() async {
    try {
      await ref.read(notificationPermissionProvider).request();
    } on Object {
      // Native side missing.
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = ref.watch(alertSettingsProvider).value ?? const AlertSettings();
    final repo = ref.read(alertSettingsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_enabled == false)
            Card(
              key: const Key('alerts-off-banner'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications are off', style: text.titleSmall),
                    const SizedBox(height: 4),
                    const Text(
                      'Settings > Apps > DhanKosh > Notifications',
                      key: Key('alerts-howto'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('alerts-allow'),
                      onPressed: _allow,
                      child: const Text('Allow'),
                    ),
                  ],
                ),
              ),
            ),
          ListTile(
            key: const Key('alerts-status'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: Text(
              switch (_enabled) {
                null => 'Checking',
                true => 'Notifications on',
                false => 'Notifications off',
              },
            ),
          ),
          SwitchListTile(
            key: const Key('alerts-transactions'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Transaction alerts'),
            value: s.transactionNotifications,
            onChanged: (v) =>
                unawaited(repo.setTransactionNotifications(value: v)),
          ),
          SwitchListTile(
            key: const Key('alerts-cards'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Card bill reminders'),
            value: s.cardDueReminders,
            onChanged: (v) => unawaited(repo.setCardDueReminders(value: v)),
          ),
          SwitchListTile(
            key: const Key('alerts-weekly'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Weekly summary'),
            subtitle: const Text('Spent last week vs the week before'),
            value: s.weeklySummary,
            onChanged: (v) => unawaited(repo.setWeeklySummary(value: v)),
          ),
          const SizedBox(height: 12),
          Text('Budget alert at', style: text.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            key: const Key('alerts-percent'),
            segments: const [
              ButtonSegment(value: 80, label: Text('80%')),
              ButtonSegment(value: 90, label: Text('90%')),
              ButtonSegment(value: 95, label: Text('95%')),
            ],
            selected: {s.budgetAlertPercent},
            onSelectionChanged: (v) =>
                unawaited(repo.setBudgetAlertPercent(v.first)),
          ),
        ],
      ),
    );
  }
}
