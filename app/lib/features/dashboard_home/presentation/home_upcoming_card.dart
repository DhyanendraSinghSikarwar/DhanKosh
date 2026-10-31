import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// Upcoming in 7 days: bills, EMIs, insurance, card dues (FR-17-09); More
/// opens the month calendar (FR-17-43).
class HomeUpcomingCard extends ConsumerWidget {
  /// Creates the card.
  const HomeUpcomingCard({super.key});

  static AppIcon _icon(UpcomingKind k) => switch (k) {
        UpcomingKind.bill => AppIcons.bills,
        UpcomingKind.emi => AppIcons.loans,
        UpcomingKind.insurance => AppIcons.insurance,
        UpcomingKind.card => AppIcons.cards,
        UpcomingKind.income => AppIcons.income,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final rows = upcomingRows(ref.watch(homeUpcomingProvider));
    return AppCard(
      key: const Key('home_upcoming'),
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
              TextButton(
                key: const Key('home_upcoming_more'),
                onPressed: () => context.push('/bills'),
                child: const Text('More ›'),
              ),
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
              leading: IconBadge(_icon(r.kind), size: 36),
              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(upcomingWhen(r.days)),
              trailing: Text(formatAmount(r.amountMinor, masked: masked)),
            ),
        ],
      ),
    );
  }
}
