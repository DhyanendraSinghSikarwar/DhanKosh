import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/settings_data_sources/presentation/bank_sms_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/history_days_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/paste_sms_card.dart';
import 'package:hisaab/features/settings_data_sources/presentation/settings_providers.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_dropdown.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';
import 'package:hisaab/shared/widgets/settings_section.dart';

/// More tab: data sources, privacy and developer tools (F-26).
class SettingsDataSourcesScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsDataSourcesScreen({
    this.notificationCard,
    this.statementsTile,
    this.billsTile,
    this.goalsTile,
    this.loansTile,
    this.alertsTile,
    this.forexTile,
    this.backupTile,
    this.taxTile,
    this.rulesTile,
    this.securityTile,
    this.activityTile,
    this.customiseTile,
    this.languageTile,
    this.newsTile,
    this.supportTile,
    this.updatesTile,
    this.diagnosticLogTile,
    super.key,
  });

  /// Payment-app notifications card (F-04), composed in `app/router.dart`.
  final Widget? notificationCard;

  /// Statements entry (F-05), composed in `app/router.dart`.
  final Widget? statementsTile;

  /// Bills & insurance entry (F-12), composed in `app/router.dart`.
  final Widget? billsTile;

  /// Goals & salary plan entry (F-36), composed in `app/router.dart`.
  final Widget? goalsTile;

  /// Loans entry (F-15), composed in `app/router.dart`.
  final Widget? loansTile;

  /// Alerts entry (F-21), composed in `app/router.dart`.
  final Widget? alertsTile;

  /// Forex rates entry (F-23), composed in `app/router.dart`.
  final Widget? forexTile;

  /// Backup & Export entry (F-24), composed in `app/router.dart`.
  final Widget? backupTile;

  /// Tax Centre entry (F-19), composed in `app/router.dart`.
  final Widget? taxTile;

  /// Rules entry (F-09), composed in `app/router.dart`.
  final Widget? rulesTile;

  /// Security & privacy entry (F-25), embedded by the app.
  final Widget? securityTile;

  /// Activity log entry (F-22), embedded by the app.
  final Widget? activityTile;

  /// Customise entry (F-28), composed in `app/router.dart`.
  final Widget? customiseTile;

  /// Language entry (F-29), composed in `app/router.dart`.
  final Widget? languageTile;

  /// Market news entry (F-31), composed in `app/router.dart`.
  final Widget? newsTile;

  /// Support entry (F-31), only composed when configured.
  final Widget? supportTile;

  /// About and updates entry (F-31), composed in `app/router.dart`.
  final Widget? updatesTile;

  /// Diagnostic log entry (F-35), composed in `app/router.dart`.
  final Widget? diagnosticLogTile;

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

  static String _bookLabel(Book b) => switch (b) {
        Book.personal => 'Personal',
        Book.business => 'Business',
        Book.all => 'All books',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final hide = ref.watch(hideAmountsProvider).value ?? true;
    final dev = ref.watch(developerToolsProvider).value ?? true;
    final status = ref.watch(developerActionsProvider);
    final book = ref.watch(bookProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            key: const Key('profile-tile'),
            onTap: () => context.push('/profile'),
            child: const Row(
              children: [
                IconBadge(AppIcons.profile, size: 46),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile'),
                      Text(
                        'Photo, occupation, alternate names',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          SettingsSection(
            title: 'Book and accounts',
            children: [
              SettingsRow(
                key: const Key('book-row'),
                badge: AppIcons.book,
                title: 'Book',
                subtitle: 'Applies to every tab',
                trailing: AppDropdown<Book>(
                  key: const Key('book-dropdown'),
                  value: book,
                  options: Book.values,
                  labelOf: _bookLabel,
                  dense: true,
                  onChanged: (b) => ref.read(bookProvider.notifier).set(b),
                ),
              ),
              SettingsRow(
                key: const Key('accounts-row'),
                badge: AppIcons.accounts,
                title: 'Accounts',
                subtitle: 'Banks, wallets and cards',
                onTap: () => context.push('/accounts'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Capture',
            leading: [
              const BankSmsCard(),
              const PasteSmsCard(),
              const HistoryDaysCard(),
              if (notificationCard != null) notificationCard!,
            ],
            children: [
              SettingsRow(
                key: const Key('senders-tile'),
                badge: AppIcons.senders,
                title: 'Bank senders',
                subtitle: 'SMS ids and mail domains',
                onTap: () => context.push('/settings/senders'),
              ),
              SettingsRow(
                key: const Key('email-tile'),
                badge: AppIcons.email,
                title: 'Email',
                subtitle: 'Mailboxes and app passwords',
                onTap: () => context.push('/settings/email'),
              ),
              if (statementsTile != null) statementsTile!,
            ],
          ),
          SettingsSection(
            title: 'Money tools',
            children: [
              if (billsTile != null) billsTile!,
              if (goalsTile != null) goalsTile!,
              if (loansTile != null) loansTile!,
              if (taxTile != null) taxTile!,
              if (rulesTile != null) rulesTile!,
              if (forexTile != null) forexTile!,
              if (newsTile != null) newsTile!,
            ],
          ),
          SettingsSection(
            title: 'Alerts and activity',
            children: [
              if (alertsTile != null) alertsTile!,
              if (activityTile != null) activityTile!,
              if (diagnosticLogTile != null) diagnosticLogTile!,
            ],
          ),
          SettingsSection(
            title: 'Appearance',
            children: [
              if (customiseTile != null) customiseTile!,
              if (languageTile != null) languageTile!,
            ],
          ),
          SettingsSection(
            title: 'Privacy and security',
            children: [
              if (securityTile != null) securityTile!,
              SettingsRow(
                badge: AppIcons.hideAmounts,
                title: 'Hide amounts',
                subtitle: 'Mask every number in the app',
                onTap: () => setHideAmounts(ref, value: !hide),
                trailing: Switch(
                  key: hideAmountsKey,
                  value: hide,
                  onChanged: (v) => setHideAmounts(ref, value: v),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Data',
            children: [
              if (backupTile != null) backupTile!,
              if (dev) ...[
                SettingsRow(
                  key: const Key('add-sample'),
                  badge: AppIcons.sample,
                  title: 'Add sample data',
                  subtitle: 'Dummy rows to try the app',
                  onTap: () => ref
                      .read(developerActionsProvider.notifier)
                      .addSampleData(),
                ),
                SettingsRow(
                  key: const Key('clear-all'),
                  badge: AppIcons.erase,
                  title: 'Clear all data',
                  subtitle: 'Deletes every transaction and account',
                  destructive: true,
                  onTap: () => _confirmClear(context, ref),
                ),
              ],
            ],
          ),
          if (dev && status != null) ...[
            const SizedBox(height: 8),
            Text(status, key: const Key('dev-status'), style: text.bodySmall),
          ],
          SettingsSection(
            title: 'About',
            children: [
              if (supportTile != null) supportTile!,
              if (updatesTile != null) updatesTile!,
            ],
          ),
        ],
      ),
    );
  }
}
