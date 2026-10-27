import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/accounts_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/merge_suggestions.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart';

/// Suggestion keys dismissed this session (FR-13-09): "Not duplicates" and
/// "Not now" are not stored.
final dismissedSuggestionsProvider =
    NotifierProvider<DismissedSuggestions, Set<String>>(
  DismissedSuggestions.new,
);

/// Session-only set of dismissed suggestion keys.
class DismissedSuggestions extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  /// Remembers [key] for the session.
  void dismiss(String key) => state = {...state, key};
}

/// Duplicate-merge and debit-card link suggestion cards (FR-13-09).
class AccountSuggestions extends ConsumerWidget {
  /// Creates the list for [items].
  const AccountSuggestions(this.items, {super.key});

  final List<AccountWithActivity> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(dismissedSuggestionsProvider);
    final accounts = [for (final i in items) i.account];
    final counts = {for (final i in items) i.account.id: i.transactionCount};
    final admin = ref.read(accountAdminRepositoryProvider);
    final merges = [
      for (final m in duplicateSuggestions(accounts, counts))
        if (!dismissed.contains('merge:${m.key}')) m,
    ];
    final links = [
      for (final l in linkSuggestions(accounts, counts))
        if (!dismissed.contains('link:${l.card.id}')) l,
    ];
    return Column(
      children: [
        for (final m in merges)
          _SuggestionCard(
            key: Key('suggest_merge_${m.source.id}'),
            title: m.source.kind == AccountKind.card
                ? 'Possible duplicate card'
                : 'Possible duplicate account',
            body: '${m.source.label} and ${m.target.label}',
            primary: 'Merge',
            secondary: 'Not duplicates',
            onPrimary: () => admin.merge(m.source.id, m.target.id),
            onSecondary: () => ref
                .read(dismissedSuggestionsProvider.notifier)
                .dismiss('merge:${m.key}'),
          ),
        for (final l in links)
          _SuggestionCard(
            key: Key('suggest_link_${l.card.id}'),
            title: 'Link this debit card?',
            body: '${l.card.label} to ${l.account.label}. ${l.reason}',
            primary: 'Link',
            secondary: 'Not now',
            onPrimary: () async {
              await admin.setLinkedAccount(l.card.id, l.account.id);
              if (l.card.accountType == null) {
                await ref
                    .read(accountRepositoryProvider)
                    .setType(l.card.id, AccountType.debitCard);
              }
            },
            onSecondary: () => ref
                .read(dismissedSuggestionsProvider.notifier)
                .dismiss('link:${l.card.id}'),
          ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
    required this.onPrimary,
    required this.onSecondary,
    super.key,
  });

  final String title;
  final String body;
  final String primary;
  final String secondary;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(body),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onSecondary, child: Text(secondary)),
                  FilledButton(onPressed: onPrimary, child: Text(primary)),
                ],
              ),
            ],
          ),
        ),
      );
}
