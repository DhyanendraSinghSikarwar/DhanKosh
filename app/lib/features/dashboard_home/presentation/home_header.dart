import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/di/home_sync_provider.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_logic.dart';
import 'package:hisaab/features/dashboard_home/presentation/home_refresh_sheet.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// Home header: avatar, greeting, name with Book tag, then eye, refresh and
/// bell on top; add, accounts and edit below (FR-17-02, FR-17-17,
/// FR-17-18, FR-17-40, FR-17-41).
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
    final name = ref.watch(profileDataProvider).value?.name?.trim();
    final hasName = name != null && name.isNotEmpty;
    final sync = ref.watch(homeSyncProvider);
    final book = ref.watch(bookProvider);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            key: const Key('home_avatar'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/profile'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting(DateTime.now().hour),
                  key: const Key('home_greeting'),
                  style: MockText.small(context),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        hasName ? name : 'Welcome',
                        key: const Key('home_name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (book != Book.personal) ...[
                      const SizedBox(width: 8),
                      _BookTag(book),
                    ],
                  ],
                ),
                if (!hasName)
                  Text(
                    'Tap to set up your profile',
                    style: MockText.small(context),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const Key('home_eye'),
          tooltip: masked ? 'Show amounts' : 'Hide amounts',
          icon: Icon(
            masked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          onPressed: () => ref
              .read(settingsRepositoryProvider)
              .write(SettingKeys.hideAmounts, !masked),
        ),
        IconButton(
          key: const Key('home_sync'),
          tooltip: sync.running ? 'Syncing' : 'Fetch new SMS and email',
          icon: sync.running
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          onPressed: () => _refresh(context, ref),
        ),
        const _InboxBell(),
        if (editing)
          IconButton(
            key: const Key('home_edit_done'),
            tooltip: 'Done',
            icon: const Icon(Icons.check),
            onPressed: onEdit,
          ),
        PopupMenuButton<String>(
          key: const Key('home_menu'),
          tooltip: 'More',
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            switch (v) {
              case 'add':
                unawaited(context.push('/transactions/add'));
              case 'accounts':
                unawaited(context.push('/accounts'));
              case 'edit':
                onEdit?.call();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              key: Key('home_add'),
              value: 'add',
              child: Text('Add transaction'),
            ),
            const PopupMenuItem(
              key: Key('home_accounts_button'),
              value: 'accounts',
              child: Text('Accounts'),
            ),
            PopupMenuItem(
              key: const Key('home_edit'),
              value: 'edit',
              child: Text(editing ? 'Done editing' : 'Edit sections'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(homeSyncProvider.notifier);
    if (!ref.read(homeSyncProvider).running) {
      unawaited(notifier.sync());
    }
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const HomeRefreshSheet(),
    );
  }
}

/// Small tag next to the name while the shared Book is not Personal
/// (FR-17-40).
class _BookTag extends StatelessWidget {
  const _BookTag(this.book);

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('home_book_tag'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        book == Book.business ? 'Business' : 'All books',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
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
