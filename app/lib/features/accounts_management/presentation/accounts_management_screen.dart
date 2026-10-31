import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/accounts_providers.dart';
import 'package:hisaab/app/di/cards_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/restore_missing.dart';
import 'package:hisaab/features/accounts_management/presentation/account_providers.dart';
import 'package:hisaab/features/accounts_management/presentation/account_suggestions.dart';
import 'package:hisaab/features/accounts_management/presentation/account_tile.dart';
import 'package:hisaab/features/accounts_management/presentation/add_account_sheet.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:parser_core/parser_core.dart';

/// Accounts list (route `/accounts`): FR-13-04 (sections, Phase 1), FR-13-05
/// (add), FR-13-10 (hidden section).
class AccountsManagementScreen extends ConsumerWidget {
  const AccountsManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final list = ref.watch(accountsWithActivityProvider);
    final hidden = ref.watch(hiddenAccountsProvider).value ?? const [];
    final book = ref.watch(bookProvider);
    final cardInfo = {
      for (final c
          in ref.watch(activeCardsProvider).value ?? const <CardLimit>[])
        c.id: c,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          TextButton.icon(
            key: const Key('accounts_add'),
            onPressed: () => showAddAccountSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          PopupMenuButton<int>(
            key: const Key('accounts_menu'),
            onSelected: (_) async {
              final n = await restoreMissingAccounts(
                ref.read(accountAdminRepositoryProvider),
                ref.read(transactionRepositoryProvider),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Restored $n accounts')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Restore missing accounts')),
            ],
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: Text('Loading…')),
        error: (e, _) => const Center(child: Text("Couldn't load accounts")),
        data: (items) {
          if (items.isEmpty && hidden.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No accounts yet',
              hint: 'Add one, or read your SMS.',
            );
          }
          final shown = items.where((a) => _inBook(a.account, book)).toList();
          final cards =
              shown.where((a) => a.account.kind == AccountKind.card).toList();
          bool isCredit(Account a) =>
              a.accountType != AccountType.debitCard &&
              a.accountType != AccountType.prepaidCard;
          final credit = cards.where((a) => isCredit(a.account)).toList();
          final others = shown
              .where(
                (a) =>
                    a.account.kind == AccountKind.account ||
                    !isCredit(a.account),
              )
              .toList();
          bool isWallet(Account a) =>
              a.accountType == AccountType.wallet ||
              a.accountType == AccountType.prepaidCard;
          final banks = others.where((a) => !isWallet(a.account));
          final wallets = others.where((a) => isWallet(a.account));
          final total = shown
              .where((a) => a.account.isLiquid)
              .fold<int>(0, (s, a) => s + (a.currentBalanceMinor ?? 0));
          final dues = credit.fold<int>(
            0,
            (s, a) => s + (cardInfo[a.account.id]?.owedMinor ?? 0),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _Header(
                total: total,
                dues: dues,
                accounts: others.length,
                cards: credit.length,
                book: book,
                masked: masked,
              ),
              AccountSuggestions(items),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No accounts in this book yet.'),
                ),
              _Section('Bank accounts', banks, masked: masked),
              _Section('Cash and wallets', wallets, masked: masked),
              _Section(
                'Credit cards',
                credit,
                masked: masked,
                cardInfo: cardInfo,
              ),
              if (hidden.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Hidden (${hidden.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final a in hidden)
                  ListTile(
                    key: Key('hidden_${a.id}'),
                    title: Text(a.label),
                    trailing: TextButton(
                      onPressed: () => ref
                          .read(accountRepositoryProvider)
                          .setHidden(a.id, hidden: false),
                      child: const Text('Show again'),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
    this.title,
    this.items, {
    required this.masked,
    this.cardInfo = const {},
  });

  final Map<int, CardLimit> cardInfo;

  final String title;
  final Iterable<AccountWithActivity> items;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$title (${items.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AccountTile(
              item: a,
              masked: masked,
              cardDueMinor: a.account.kind == AccountKind.card
                  ? cardInfo[a.account.id]?.owedMinor ?? 0
                  : null,
              usedPercent: _used(cardInfo[a.account.id]),
              onTap: () => a.account.kind == AccountKind.card &&
                      a.account.accountType != AccountType.debitCard &&
                      a.account.accountType != AccountType.prepaidCard
                  ? _openCard(context, a.account.id)
                  : context.push('/accounts/${a.account.id}'),
            ),
          ),
      ],
    );
  }
}

bool _inBook(Account a, Book b) => switch (b) {
      Book.all => true,
      Book.personal => a.usage == AccountUsage.personal,
      Book.business => a.usage == AccountUsage.business,
    };

int? _used(CardLimit? c) {
  final limit = c?.limitMinor;
  final left = c?.limitLeftMinor;
  if (limit == null || limit <= 0 || left == null) return null;
  return ((limit - left) * 100 / limit).round().clamp(0, 100);
}

/// Opens the card detail (`/cards/<id>`); falls back to the cards list when
/// that route is not registered.
void _openCard(BuildContext context, int id) {
  final router = GoRouter.of(context);
  final match = router.configuration.findMatch(Uri.parse('/cards/$id'));
  unawaited(router.push(match.isError ? '/cards' : '/cards/$id'));
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.dues,
    required this.accounts,
    required this.cards,
    required this.book,
    required this.masked,
  });

  final int total;
  final int dues;
  final int accounts;
  final int cards;
  final Book book;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (book) {
      Book.personal => 'Personal',
      Book.business => 'Business',
      Book.all => 'All books',
    };
    return AppCard(
      key: const Key('accounts_header'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Balance', style: theme.textTheme.bodySmall),
                    Text(
                      formatAmount(total, masked: masked),
                      key: const Key('accounts_total'),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Card dues', style: theme.textTheme.bodySmall),
                  Text(
                    formatAmount(dues, masked: masked),
                    key: const Key('accounts_dues'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$accounts accounts · $cards cards · $label',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
