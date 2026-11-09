import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/people_split/presentation/people_screen.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/ui/app_dates.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// One person (FR-40-05): balance, history, repayments and manual entries.
class PersonDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const PersonDetailScreen({required this.id, super.key});

  /// Person id.
  final int id;

  Future<void> _record(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int sign,
  }) async {
    final c = TextEditingController();
    final n = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('entry_amount'),
              controller: c,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0.00'),
            ),
            TextField(
              key: const Key('entry_note'),
              controller: n,
              decoration: InputDecoration(hintText: t('Note')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Cancel')),
          ),
          FilledButton(
            key: const Key('entry_save'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Save')),
          ),
        ],
      ),
    );
    final minor = parseMoney(c.text)?.minor;
    if (ok != true || minor == null || minor <= 0) return;
    await ref
        .read(peopleRepositoryProvider)
        .addEntry(id, sign * minor, note: n.text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final person =
        ref.watch(peopleProvider).value?.where((p) => p.id == id).firstOrNull;
    final entries = ref.watch(personEntriesProvider(id)).value ?? const [];
    final repo = ref.read(peopleRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(person?.name ?? t('Person')),
        actions: [
          IconButton(
            key: const Key('person_rename'),
            tooltip: t('Rename'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final n = await askPersonName(
                context,
                title: t('Rename'),
                initial: person?.name,
              );
              if (n != null && n.isNotEmpty) await repo.rename(id, n);
            },
          ),
          IconButton(
            key: const Key('person_delete'),
            tooltip: t('Delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await repo.deletePerson(id);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balanceText(person?.balanceMinor ?? 0, masked: masked),
                  key: const Key('person_balance'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('person_repaid'),
                      onPressed: () => _record(
                        context,
                        ref,
                        title: t('They paid back'),
                        sign: -1,
                      ),
                      child: Text(t('They paid back')),
                    ),
                    OutlinedButton(
                      key: const Key('person_lent'),
                      onPressed: () => _record(
                        context,
                        ref,
                        title: t('I lent'),
                        sign: 1,
                      ),
                      child: Text(t('I lent')),
                    ),
                    OutlinedButton(
                      key: const Key('person_borrowed'),
                      onPressed: () => _record(
                        context,
                        ref,
                        title: t('I borrowed'),
                        sign: -1,
                      ),
                      child: Text(t('I borrowed')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (final e in entries)
            Dismissible(
              key: Key('entry_${e.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) => repo.deleteEntry(e.id),
              child: ListTile(
                title: Text(
                  '${e.amountMinor > 0 ? '+' : '-'}'
                  '${formatAmount(e.amountMinor.abs(), masked: masked, paise: false)}',
                ),
                subtitle: Text(
                  [
                    AppDates.format(
                      DateTime.fromMillisecondsSinceEpoch(e.createdAt),
                    ),
                    if (e.note != null) e.note!,
                  ].join(' · '),
                ),
                onTap: e.transactionId == null
                    ? null
                    : () => context.push('/transaction/${e.transactionId}'),
              ),
            ),
        ],
      ),
    );
  }
}
