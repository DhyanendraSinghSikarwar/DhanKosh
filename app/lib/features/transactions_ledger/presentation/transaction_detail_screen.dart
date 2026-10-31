// Riverpod's autoDispose provider types are not worth spelling out.
// ignore_for_file: specify_nonobvious_property_types
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/categorization/domain/category_choice.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_category_style.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ledger_tx_tile.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';
import 'package:hisaab/shared/widgets/section_label.dart';
import 'package:intl/intl.dart';

/// Opens the category picker for a row (supplied by the app shell, which
/// binds the categorization sheet; features never import each other).
typedef CategoryPicker = Future<CategoryChoice?> Function(
  BuildContext context,
  LedgerTx tx,
);

final _txProvider = FutureProvider.autoDispose.family<LedgerTx?, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).byId(id),
);

final _sourcesProvider =
    FutureProvider.autoDispose.family<List<TxSourceRow>, int>(
  (ref, id) => ref.watch(transactionRepositoryProvider).sourcesOf(id),
);

final _accountLabelProvider =
    FutureProvider.autoDispose.family<String?, int>((ref, id) async {
  final a = await ref.watch(accountRepositoryProvider).byId(id);
  return a?.label;
});

/// Transaction detail: fields, category and note edit, source messages,
/// delete (FR-08-09, FR-08-10, FR-09-05, FR-09-06, FR-09-08, FR-09-09).
class TransactionDetailScreen extends ConsumerWidget {
  /// Creates the screen for [id].
  const TransactionDetailScreen({
    required this.id,
    required this.pickCategory,
    super.key,
  });

  /// Row id.
  final int id;

  /// Category picker.
  final CategoryPicker pickCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(_txProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          if (tx.value != null)
            IconButton(
              key: const Key('detail_delete'),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: tx.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (t) => t == null
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'Transaction not found',
              )
            : _Body(t, pickCategory),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete 1 transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(transactionRepositoryProvider).deleteTransactions([id]);
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/transactions');
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.t, this.pickCategory);
  final LedgerTx t;
  final CategoryPicker pickCategory;

  void _refresh(WidgetRef ref) => ref.invalidate(_txProvider(t.id));

  Future<void> _editCategory(BuildContext context, WidgetRef ref) async {
    final choice = await pickCategory(context, t);
    if (choice == null) return;
    final txs = ref.read(transactionRepositoryProvider);
    await txs.setCategory(
      [t.id],
      choice.category,
      customCategoryId: choice.customCategoryId,
    );
    final key = MerchantRule.keyOf(t.merchant, t.upiId);
    if (choice.saveRule && key != null) {
      final rule = MerchantRule(
        merchantKey: key,
        category: choice.category,
        customCategoryId: choice.customCategoryId,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        manual: true,
      );
      await ref.read(categoryRepositoryProvider).saveManualRule(rule);
      if (choice.applyToPast) await txs.applyRuleToPast(rule);
    }
    _refresh(ref);
    // FR-15-09: an EMI payment may be counted towards a loan.
    if (choice.category.name == 'emiLoan' &&
        choice.customCategoryId == null &&
        (t.merchant ?? '').length >= 2 &&
        context.mounted) {
      await context.push('/loan-link/${t.id}');
    }
  }

  // FR-08-10: sub-category as free text; empty clears it.
  Future<void> _editSubcategory(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController(text: t.subcategory ?? '');
    final sub = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sub-category'),
        content: TextField(
          key: const Key('sub_field'),
          controller: c,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('sub_save'),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (sub == null) return;
    await ref
        .read(transactionRepositoryProvider)
        .setSubcategory(t.id, sub.isEmpty ? null : sub);
    _refresh(ref);
  }

  // FR-08-10: move the row to another account.
  Future<void> _editAccount(BuildContext context, WidgetRef ref) async {
    final accounts =
        await ref.read(accountRepositoryProvider).watchVisible().first;
    if (!context.mounted) return;
    var remember = false;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SimpleDialog(
          title: const Text('Account'),
          children: [
            for (final a in accounts)
              SimpleDialogOption(
                key: Key('acct_${a.id}'),
                onPressed: () => Navigator.pop(ctx, a.id),
                child: Text(a.label),
              ),
            if (t.merchant != null || t.upiId != null)
              CheckboxListTile(
                key: const Key('acct_remember'),
                dense: true,
                value: remember,
                onChanged: (v) => setS(() => remember = v ?? false),
                title: const Text('Remember for this payee'),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(transactionRepositoryProvider)
        .setAccount(t.id, picked, rememberPayee: remember);
    ref.invalidate(_accountLabelProvider);
    _refresh(ref);
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController(text: t.note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          key: const Key('note_field'),
          controller: c,
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('note_save'),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (note == null) return;
    await ref
        .read(transactionRepositoryProvider)
        .setNote(t.id, note.isEmpty ? null : note);
    _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final account = t.accountId == null
        ? null
        : ref.watch(_accountLabelProvider(t.accountId!)).value;
    final sources = ref.watch(_sourcesProvider(t.id)).value ?? const [];
    final last4 = t.accountLast4;
    final fallbackAccount =
        last4 == null ? t.bankName : '${t.bankName} ••$last4';
    final when = DateFormat(
      t.hasExplicitTime ? 'd MMM yyyy, h:mm a' : 'd MMM yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(t.timestamp));
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  categoryStyle(t.category).icon,
                  color: categoryStyle(t.category).color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      txAmountText(t, masked: masked),
                      key: const Key('detail_amount'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (t.needsReview)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t.reviewReason ?? 'Needs review',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              SourceTag(t.accountKind),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            children: withDividers([
              _Row(
                'Category',
                t.category.label,
                tag: 'detail_category',
                onTap: () => _editCategory(context, ref),
              ),
              _Row(
                'Sub-category',
                t.subcategory ?? 'Add',
                tag: 'detail_subcategory',
                onTap: () => _editSubcategory(context, ref),
              ),
              _Row(
                'Account',
                account ?? fallbackAccount,
                tag: 'detail_account',
                onTap: () => _editAccount(context, ref),
              ),
              _Row('Date', when),
              _Row('Channel', t.channel.name.toUpperCase()),
              if (t.currency != 'INR')
                _Row(
                  'In rupees',
                  t.inrMinor == null
                      ? 'Add a ${t.currency} rate in Settings'
                      : '≈ ${formatAmount(t.inrMinor!, masked: masked)}',
                  tag: 'detail_inr',
                ),
              if (t.upiId != null) _Row('UPI id', t.upiId!),
              if (t.referenceNumber != null)
                _Row('Reference', t.referenceNumber!),
              _Row(
                'Note',
                t.note ?? 'Add note',
                tag: 'detail_note',
                onTap: () => _editNote(context, ref),
              ),
            ]),
          ),
        ),
        const SectionLabel(
          'Messages',
          padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
        ),
        if (sources.isEmpty)
          const Text('No source messages')
        else
          for (final s in sources)
            _MessageView(
              s,
              onSplit: sources.length > 1 && s.rawText != null
                  ? () async {
                      final id = await ref
                          .read(transactionRepositoryProvider)
                          .splitSource(t.id, s.id);
                      ref
                        ..invalidate(_sourcesProvider(t.id))
                        ..invalidate(_txProvider(t.id));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              id == null
                                  ? 'Could not split'
                                  : 'Split into its own transaction',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.onTap, this.tag});
  final String label;
  final String value;
  final VoidCallback? onTap;

  final String? tag;

  @override
  Widget build(BuildContext context) => ListTile(
        key: tag == null ? null : Key(tag!),
        dense: true,
        onTap: onTap,
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(value, textAlign: TextAlign.end)),
            if (onTap != null) const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      );
}

/// Source message with sender, time and copy (FR-08-20 basic).
class _MessageView extends StatelessWidget {
  const _MessageView(this.s, {this.onSplit});
  final TxSourceRow s;

  /// Splits this message into its own row (FR-07-13); null when not allowed.
  final VoidCallback? onSplit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = s.rawText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.source.name.toUpperCase()} · ${s.sender}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            if (raw == null)
              const Text('Original text not available')
            else ...[
              Text(raw, maxLines: 10, overflow: TextOverflow.ellipsis),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  children: [
                    if (onSplit != null)
                      TextButton(
                        key: Key('split_${s.id}'),
                        onPressed: onSplit,
                        child: const Text('Split out'),
                      ),
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: raw)),
                      child: const Text('Copy text'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
