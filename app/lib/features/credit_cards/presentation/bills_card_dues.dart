import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/home_cards_providers.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/features/credit_cards/presentation/card_due_format.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// Card dues of the month (or one day) shown on the Bills calendar page,
/// with Mark paid (FR-14-28). [month] is the first day of the month (UTC);
/// [day] narrows to one date.
class BillsCardDues extends ConsumerWidget {
  /// Creates the section.
  const BillsCardDues({required this.month, this.day, super.key});

  /// First day of the shown month (UTC).
  final DateTime month;

  /// Selected day, if any.
  final DateTime? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final rows = <({DateTime date, int id, String name, int owed, bool paid})>[
      for (final v in ref.watch(homeCardsProvider))
        if (v.card.dueDay != null && (v.dueMinor > 0 || v.card.paid))
          (
            date: DateTime.utc(1970).add(Duration(days: v.card.dueDay!)),
            id: v.card.id,
            name: v.card.name,
            owed: v.dueMinor,
            paid: v.card.paid,
          ),
    ].where((r) {
      if (r.date.year != month.year || r.date.month != month.month) {
        return false;
      }
      return day == null || r.date.day == day!.day;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: const Key('bills_card_dues'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (final r in rows)
              ListTile(
                key: Key('bills_card_due_${r.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(AppIcons.cards, size: 36),
                title: Text('${r.name} card bill'),
                subtitle: Text(
                  '${r.paid ? 'Paid' : 'Due'} · '
                  '${cardDate(r.date.difference(DateTime.utc(1970)).inDays)}',
                ),
                trailing: r.paid
                    ? const Icon(Icons.check_circle_outline)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cardMoney(r.owed, masked: masked)),
                          TextButton(
                            key: Key('bills_card_paid_${r.id}'),
                            onPressed: () =>
                                ref.read(cardDueActionsProvider).markPaid(
                                      ref
                                          .read(homeCardsProvider)
                                          .firstWhere((v) => v.card.id == r.id)
                                          .card,
                                    ),
                            child: const Text('Mark paid'),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
