import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/di/home_sync_provider.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Home header: avatar, greeting and name, sync button with progress pill,
/// add, hide amounts, bell, accounts and edit (FR-17-02, FR-17-17,
/// FR-17-18).
class HomeHeader extends ConsumerWidget {
  /// Creates the header.
  const HomeHeader({
    required this.masked,
    this.editing = false,
    this.onEdit,
    super.key,
  });

  /// Amounts are hidden.
  final bool masked;

  /// Edit mode is on.
  final bool editing;

  /// Toggles edit mode.
  final VoidCallback? onEdit;

  static String initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return 'H';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(profileDataProvider).value?.name?.trim();
    final hasName = name != null && name.isNotEmpty;
    final sync = ref.watch(homeSyncProvider);
    return Column(
      children: [
        Row(
          children: [
            InkWell(
              key: const Key('home_avatar'),
              customBorder: const CircleBorder(),
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(initials(name)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting(DateTime.now().hour),
                    key: const Key('home_greeting'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    hasName ? name : 'Welcome',
                    key: const Key('home_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (!hasName)
                    Text(
                      'Tap to set up your profile',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (sync.running || sync.done != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  key: const Key('home_sync_pill'),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    sync.running
                        ? 'Reading ${sync.scanned} · ${sync.found} found'
                        : sync.done!,
                  ),
                ),
              ),
            IconButton(
              key: const Key('home_sync'),
              tooltip: sync.running ? 'Syncing' : 'Sync everything',
              icon: sync.running
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: sync.running
                  ? null
                  : () => ref.read(homeSyncProvider.notifier).sync(),
            ),
            IconButton(
              key: const Key('home_add'),
              tooltip: 'Add transaction',
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/transactions/add'),
            ),
            IconButton(
              key: const Key('home_eye'),
              tooltip: masked ? 'Show amounts' : 'Hide amounts',
              icon: Icon(
                masked
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => ref
                  .read(settingsRepositoryProvider)
                  .write(SettingKeys.hideAmounts, !masked),
            ),
            const _InboxBell(),
            IconButton(
              key: const Key('home_accounts_button'),
              tooltip: 'Accounts',
              icon: const Icon(Icons.account_balance_outlined),
              onPressed: () => context.push('/accounts'),
            ),
            IconButton(
              key: const Key('home_edit'),
              tooltip: editing ? 'Done' : 'Edit sections',
              icon: Icon(editing ? Icons.check : Icons.tune),
              onPressed: onEdit,
            ),
          ],
        ),
      ],
    );
  }
}

class _InboxBell extends ConsumerWidget {
  const _InboxBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(inboxUnreadProvider);
    return IconButton(
      key: const Key('home_bell'),
      tooltip: 'Inbox',
      icon: Badge(
        key: const Key('home_bell_badge'),
        isLabelVisible: n > 0,
        label: Text(n > 99 ? '99+' : '$n'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => context.push('/activity'),
    );
  }
}
