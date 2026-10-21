import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/cards_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/presentation/card_amounts_sheet.dart';
import 'package:hisaab/features/credit_cards/presentation/card_tile.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Credit cards: per-card position, Mark paid and Edit amounts
/// (FR-14-07, FR-14-09, FR-14-13).
class CreditCardsScreen extends ConsumerWidget {
  /// Creates the screen.
  const CreditCardsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, CardLimit c) async {
    final r = await showModalBottomSheet<CardEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CardAmountsSheet(card: c),
    );
    if (r == null) return;
    final actions = ref.read(cardDueActionsProvider);
    if (r.reset) {
      await actions.resetAll(c);
    } else {
      await actions.saveEdit(
        c,
        calculated: c.position.calculated ?? c.position,
        billedMinor: r.billed,
        minDueMinor: r.minDue,
        unbilledMinor: r.unbilled,
        outstandingMinor: r.outstanding,
        dueEpochDay: r.dueDay,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(activeCardsProvider);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final now = DateTime.now().millisecondsSinceEpoch;
    return Scaffold(
      appBar: AppBar(title: const Text('Credit cards')),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load cards')),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.credit_card_outlined,
                title: 'No credit cards',
                hint: 'Bills from SMS or email appear here.',
              )
            : ListView.separated(
                key: const Key('cards_list'),
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final c = list[i];
                  final actions = ref.read(cardDueActionsProvider);
                  return CardTile(
                    card: c,
                    masked: masked,
                    nowMs: now,
                    onMarkPaid: () => actions.markPaid(c),
                    onUndo: () => actions.undoPaid(c),
                    onEdit: () => _edit(context, ref, c),
                  );
                },
              ),
      ),
    );
  }
}
