import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/mock_kit.dart';

/// "Safe to spend" per day (FR-17-48, ADR-0012). Hidden until turned on in
/// Customise.
class HomeSafeToSpendCard extends ConsumerWidget {
  /// Creates the card.
  const HomeSafeToSpendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final r = ref.watch(safeToSpendProvider);
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    return AppCard(
      key: const Key('home_safe'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(t('Safe to spend')),
          const SizedBox(height: 8),
          if (r == null)
            Text(
              t('Add an account balance to see this.'),
              style: MockText.small(context),
            )
          else ...[
            Text(
              '${money(r.perDayMinor)} ${t('a day')}',
              key: const Key('home_safe_per_day'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              t(
                '{left} for {n} days, after {bills} of bills',
                args: {
                  'left': money(r.spendableMinor),
                  'n': r.daysLeft,
                  'bills': money(r.billsMinor),
                },
              ),
              style: MockText.small(context),
            ),
          ],
        ],
      ),
    );
  }
}
