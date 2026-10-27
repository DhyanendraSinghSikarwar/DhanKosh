import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Upcoming in 7 days: bills, EMIs, insurance, card dues (FR-17-09).
class HomeUpcomingCard extends ConsumerWidget {
  /// Creates the card.
  const HomeUpcomingCard({super.key});

  static IconData _icon(UpcomingKind k) => switch (k) {
        UpcomingKind.bill => Icons.receipt_long_outlined,
        UpcomingKind.emi => Icons.account_balance_outlined,
        UpcomingKind.insurance => Icons.shield_outlined,
        UpcomingKind.card => Icons.credit_card_outlined,
        UpcomingKind.income => Icons.south_west,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final rows = upcomingRows(ref.watch(homeUpcomingProvider));
    return AppCard(
      key: const Key('home_upcoming'),
      onTap: () => context.push('/bills'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Upcoming · 7 days',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Text('Calendar'),
            ],
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Nothing due in the next 7 days'),
            ),
          for (final r in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(_icon(r.kind)),
              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(upcomingWhen(r.days)),
              trailing: Text(formatAmount(r.amountMinor, masked: masked)),
            ),
        ],
      ),
    );
  }
}
