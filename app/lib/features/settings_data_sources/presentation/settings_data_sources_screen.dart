import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/settings_data_sources/presentation/bank_sms_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/paste_sms_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_providers.dart';

/// More tab: data sources, privacy and developer tools (F-26).
class SettingsDataSourcesScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsDataSourcesScreen({
    this.notificationCard,
    this.statementsTile,
    super.key,
  });

  /// Payment-app notifications card (F-04), composed in `app/router.dart`.
  final Widget? notificationCard;

  /// Statements entry (F-05), composed in `app/router.dart`.
  final Widget? statementsTile;

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text('Deletes every transaction and account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('clear-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(developerActionsProvider.notifier).clearAll();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final hide = ref.watch(hideAmountsProvider).value ?? true;
    final dev = ref.watch(developerToolsProvider).value ?? true;
    final status = ref.watch(developerActionsProvider);
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: text.titleSmall),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            key: const Key('profile-tile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile'),
          ),
          head('Data sources'),
          const BankSmsCard(),
          const SizedBox(height: 12),
          const PasteSmsCard(),
          ListTile(
            key: const Key('email-tile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: const Text('Email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/email'),
          ),
          if (statementsTile != null) statementsTile!,
          if (notificationCard != null) ...[
            const SizedBox(height: 12),
            notificationCard!,
          ],
          head('Privacy'),
          SwitchListTile(
            key: hideAmountsKey,
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide amounts'),
            value: hide,
            onChanged: (v) => setHideAmounts(ref, value: v),
          ),
          if (dev) ...[
            head('Developer'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('add-sample'),
                  onPressed: () => ref
                      .read(developerActionsProvider.notifier)
                      .addSampleData(),
                  child: const Text('Add sample data'),
                ),
                OutlinedButton(
                  key: const Key('clear-all'),
                  onPressed: () => _confirmClear(context, ref),
                  child: const Text('Clear all data'),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(status, key: const Key('dev-status'), style: text.bodySmall),
            ],
          ],
        ],
      ),
    );
  }
}
