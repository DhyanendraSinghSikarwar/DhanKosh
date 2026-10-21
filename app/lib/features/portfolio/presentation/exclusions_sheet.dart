import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';

/// Include or exclude asset classes and liabilities from net worth
/// (FR-16-14).
class ExclusionsSheet extends ConsumerWidget {
  /// Creates the sheet.
  const ExclusionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(netWorthFilterProvider).value ?? const NetWorthFilter();
    Future<void> save(NetWorthFilter n) =>
        ref.read(netWorthPrefsRepositoryProvider).save(n);

    Widget tile(
      String key,
      String label, {
      required bool on,
      required void Function({required bool v}) set,
    }) =>
        SwitchListTile(
          key: Key(key),
          title: Text(label),
          value: on,
          onChanged: (v) => set(v: v),
        );

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Include in net worth',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final c in AssetClass.values)
            tile(
              'nw-class-${c.name}',
              c.label,
              on: !f.excludedClasses.contains(c),
              set: ({required v}) => save(
                NetWorthFilter(
                  excludedClasses: _toggled(f.excludedClasses, c, include: v),
                  excludedLiabilities: f.excludedLiabilities,
                  excludedAccountIds: f.excludedAccountIds,
                ),
              ),
            ),
          for (final l in LiabilityKind.values)
            tile(
              'nw-liab-${l.name}',
              l == LiabilityKind.loans ? 'Loans' : 'Card dues',
              on: !f.excludedLiabilities.contains(l),
              set: ({required v}) => save(
                NetWorthFilter(
                  excludedClasses: f.excludedClasses,
                  excludedLiabilities:
                      _toggled(f.excludedLiabilities, l, include: v),
                  excludedAccountIds: f.excludedAccountIds,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Set<T> _toggled<T>(Set<T> s, T x, {required bool include}) =>
    include ? ({...s}..remove(x)) : {...s, x};
