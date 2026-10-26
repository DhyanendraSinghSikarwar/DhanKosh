import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/sip_providers.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/recurring_transactions/presentation/sip_setup_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// SIP list: name, amount, frequency, next date and total invested
/// (FR-12-20). Used on Bills and Portfolio; tapping a row edits it. Shows
/// nothing when there are no SIPs and [showEmpty] is false.
class SipSection extends ConsumerWidget {
  /// Creates the section.
  const SipSection({this.showEmpty = false, super.key});

  /// Show an empty hint instead of nothing.
  final bool showEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sips = ref.watch(sipsProvider).value ?? const <Sip>[];
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    if (sips.isEmpty && !showEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    return AppCard(
      key: const Key('sip-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SIPs', style: theme.textTheme.titleSmall),
          if (sips.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No SIPs yet. Add one.', key: Key('sip-empty')),
            ),
          for (final s in sips)
            ListTile(
              key: Key('sip-${s.name}'),
              contentPadding: EdgeInsets.zero,
              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${s.frequency.label} · next ${s.nextDate.day}/'
                '${s.nextDate.month}/${s.nextDate.year}'
                '${s.detected ? ' · Detected' : ''}\n'
                'Invested ${money(s.totalInvestedMinor)}',
              ),
              isThreeLine: true,
              trailing: Text(money(s.amountMinor)),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => SipSetupSheet(source: s),
              ),
            ),
        ],
      ),
    );
  }
}
