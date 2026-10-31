import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/features/dashboard_home/domain/home_charts.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

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
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final rows = upcomingRows(ref.watch(homeUpcomingProvider));
    return AppCard(
      key: const Key('home_upcoming'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            'Upcoming',
            trailing: MoreLink(
              'More ›',
              key: const Key('home_upcoming_more'),
              onTap: () => context.push('/bills'),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Nothing due in the next 7 days',
                style: MockText.small(context),
              ),
            ),
          for (final (i, r) in rows.indexed)
            IconAmountRow(
              icon: _icon(r.kind),
              title: r.name,
              subtitle: upcomingWhen(r.days),
              amount: formatAmount(r.amountMinor, masked: masked, paise: false),
              divider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}
