import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/analytics/domain/analytics_view.dart';
import 'package:parser_core/parser_core.dart';

/// Analysis filters: period, custom range, accounts and cards (FR-18-12,
/// FR-18-27). The account scope is the Book seam (memory 20).
class AnalyticsFilterBar extends ConsumerWidget {
  /// Creates the bar.
  const AnalyticsFilterBar({super.key});

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (r == null) return;
    ref.read(periodProvider.notifier).setCustom(r.start, r.end);
    ref
        .read(analyticsPeriodChoiceProvider.notifier)
        .select(AnalyticsPeriod.custom);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodChoiceProvider);
    final scope = ref.watch(accountScopeProvider);
    final accounts = ref.watch(analyticsAccountsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<AnalyticsPeriod>(
          key: const Key('analytics-period'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: AnalyticsPeriod.thisMonth,
              label: Text('This month'),
            ),
            ButtonSegment(
              value: AnalyticsPeriod.lastMonth,
              label: Text('Last month'),
            ),
            ButtonSegment(
              value: AnalyticsPeriod.custom,
              label: Text('Custom'),
            ),
          ],
          selected: {period},
          onSelectionChanged: (s) {
            if (s.first == AnalyticsPeriod.custom) {
              unawaited(_pickRange(context, ref));
            } else {
              ref.read(analyticsPeriodChoiceProvider.notifier).select(s.first);
            }
          },
        ),
        if (accounts.isNotEmpty)
          SingleChildScrollView(
            key: const Key('analytics-accounts'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('analytics-account-all'),
                  label: const Text('All accounts'),
                  selected: scope == null,
                  onSelected: (_) =>
                      ref.read(accountScopeProvider.notifier).set(null),
                ),
                for (final a in accounts)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      key: Key('analytics-account-${a.id}'),
                      avatar: Icon(
                        a.kind == AccountKind.card
                            ? Icons.credit_card
                            : Icons.account_balance,
                        size: 16,
                      ),
                      label: Text(a.nickname ?? '${a.bankName} ${a.last4}'),
                      selected: scope == a.id,
                      onSelected: (on) => ref
                          .read(accountScopeProvider.notifier)
                          .set(on ? a.id : null),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
