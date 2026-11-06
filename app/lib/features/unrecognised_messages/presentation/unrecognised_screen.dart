import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/unrecognised_providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/add_draft.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/add_from_unrecognised.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/unrecognised_providers.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:intl/intl.dart';
import 'package:parser_core/parser_core.dart' hide Money;

/// Messages that look like payments but matched no bank format: Add opens the
/// form pre-filled, Dismiss hides them, Ignore sender switches the sender off
/// (F-38, FR-38-04, FR-38-08). Nothing is added until the user saves.
class UnrecognisedScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const UnrecognisedScreen({super.key});

  @override
  ConsumerState<UnrecognisedScreen> createState() => _State();
}

class _State extends ConsumerState<UnrecognisedScreen> {
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    // FR-38-10: old text is dropped whenever the queue is opened.
    unawaited(
      Future<void>.microtask(
        () => ref.read(unrecognisedRepositoryProvider).purge(),
      ),
    );
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    String text;
    try {
      final settings = await ref.read(smsSettingsRepositoryProvider).read();
      final since = DateTime.now()
          .subtract(Duration(days: settings.lookbackDays))
          .millisecondsSinceEpoch;
      final r = await ref.read(scanMissedMessagesProvider)(sinceMs: since);
      text = r.queued == 0
          ? 'Nothing new that looks like a payment'
          : '${r.queued} message${r.queued == 1 ? '' : 's'} to review';
    } on Object {
      text = 'Could not read messages. Check SMS permission.';
    }
    if (!mounted) return;
    setState(() => _scanning = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(freshMessagesProvider);
    final prefs = ref.watch(senderPrefsProvider).value ?? const [];
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unrecognised messages'),
        actions: [
          IconButton(
            key: const Key('unrecognised_scan'),
            tooltip: 'Find missed messages',
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.manage_search),
          ),
          IconButton(
            key: const Key('unrecognised_senders'),
            tooltip: 'Learned senders',
            onPressed: () => context.push('/review/unrecognised/senders'),
            icon: const Icon(Icons.school_outlined),
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                key: Key('unrecognised_empty'),
                icon: Icons.check_circle_outline,
                title: 'All messages recognised',
                hint: 'Tap the search icon to look for missed ones.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'These look like payments, but no bank format matched. '
                      'Nothing is added until you save.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  for (final m in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MessageCard(
                        message: m,
                        learned: prefs.any(
                          (p) => p.senderKey == m.senderKey && !p.ignored,
                        ),
                        masked: masked,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({
    required this.message,
    required this.learned,
    required this.masked,
  });

  final UnrecognisedMessage message;
  final bool learned;
  final bool masked;

  static final _digits = RegExp(r'\d');

  GenericSuggestion? get _suggestion => message.suggestion(
        learned: learned,
        loose: message.source == UnrecognisedSource.app,
      );

  String _line(GenericSuggestion s) {
    final amount = s.currency == 'INR'
        ? formatMoney(Money(s.amountMinor), masked: masked)
        : '${s.currency} ${(s.amountMinor / 100).toStringAsFixed(2)}';
    final kind = s.directionGuessed
        ? 'payment?'
        : s.type == TransactionType.credit
            ? 'credit'
            : 'debit';
    return [
      'Looks like: $amount $kind',
      if (s.merchant != null) s.merchant!,
      if (s.last4 != null) '••${s.last4}',
    ].join(' · ');
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final s = _suggestion;
    final repo = ref.read(unrecognisedRepositoryProvider);
    final accounts =
        await ref.read(accountRepositoryProvider).watchVisible().first;
    final pref = await repo.pref(message.senderKey);

    Account? pick;
    if (pref != null &&
        pref.accountFits(textLast4: s?.last4, textCurrency: s?.currency)) {
      pick = accounts
          .where((a) => a.last4 == pref.last4 && a.bankName == pref.bankName)
          .firstOrNull;
    }
    // The text's own digits: link only when exactly one account has them.
    if (pick == null && s?.last4 != null) {
      final same = accounts.where((a) => a.last4 == s!.last4).toList();
      if (same.length == 1) pick = same.single;
    }
    final add = ref.read(addFromUnrecognisedProvider);
    final draft = AddDraft(
      heading: 'Add from message',
      sourceText: masked ? message.body.replaceAll(_digits, '•') : message.body,
      amountMinor: s?.amountMinor,
      type: s == null || s.type == TransactionType.credit
          ? (s == null ? null : TransactionType.credit)
          : TransactionType.debit,
      merchant: s?.merchant,
      reference: s?.reference,
      category: s?.category,
      accountId: pick?.id,
      when: DateTime.fromMillisecondsSinceEpoch(message.receivedAt),
      onConfirm: (v) {
        final chosen = v.accountId == null
            ? null
            : accounts.where((a) => a.id == v.accountId).firstOrNull;
        return add(
          message,
          ConfirmedPayment(
            amountMinor: v.amountMinor,
            type: v.type,
            timestamp: v.timestamp,
            currency: s?.currency ?? 'INR',
            accountId: v.accountId,
            accountBank: chosen?.bankName,
            accountLast4: chosen?.last4,
            merchant: v.merchant,
            upiId: s?.upiId,
            category: v.category,
            reference: v.reference,
            note: v.note,
            channel: s?.channel ?? Channel.other,
          ),
        );
      },
    );
    if (!context.mounted) return;
    await context.push('/transactions/add', extra: draft);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(unrecognisedRepositoryProvider);
    final s = _suggestion;
    final when = DateFormat('d MMM, h:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(message.receivedAt),
    );
    final body = masked ? message.body.replaceAll(_digits, '•') : message.body;
    final theme = Theme.of(context);
    return AppCard(
      key: Key('unrecognised_${message.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message.sender,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(when, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          if (s != null) ...[
            const SizedBox(height: 8),
            Text(
              _line(s),
              key: Key('looks_like_${message.id}'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                key: Key('dismiss_${message.id}'),
                onPressed: () async {
                  await repo.dismiss(message.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Dismissed'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => repo.restore(message.id),
                      ),
                    ),
                  );
                },
                child: const Text('Dismiss'),
              ),
              TextButton(
                key: Key('ignore_${message.id}'),
                onPressed: () async {
                  await repo.ignoreSender(message.senderKey);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Sender switched off. See Learned senders.'),
                    ),
                  );
                },
                child: const Text('Ignore sender'),
              ),
              const Spacer(),
              FilledButton(
                key: Key('add_${message.id}'),
                onPressed: () => _add(context, ref),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
