import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_summary.dart';
import 'package:hisaab/features/portfolio/presentation/exclusions_sheet.dart';
import 'package:hisaab/features/portfolio/presentation/holding_labels.dart';
import 'package:hisaab/features/portfolio/presentation/holding_sheet.dart';
import 'package:hisaab/features/portfolio/presentation/net_worth_chart.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

const _ranges = <(String, int?)>[
  ('1M', 30),
  ('6M', 182),
  ('1Y', 365),
  ('3Y', 1095),
  ('All', null),
];

/// Portfolio tab: net worth, history, allocation, holdings and maturities
/// (F-16; FR-16-01, FR-16-03, FR-16-05, FR-16-06, FR-16-08, FR-16-12).
class PortfolioScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  int _range = 2;

  void _sheet(Widget w) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => w,
      );

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final nw = ref.watch(netWorthProvider).value;
    final holdings = ref.watch(holdingsProvider).value ?? const <Holding>[];
    final points = ref.watch(netWorthPointsProvider).value ?? const [];
    final maturities =
        ref.watch(maturitiesProvider).value ?? const <MaturityItem>[];
    String money(int m) => formatAmount(m, masked: masked, paise: false);

    final days = _ranges[_range].$2;
    final latest = points.isEmpty ? null : points.last.day;
    final inRange = [
      for (final p in points)
        if (days == null || latest == null || p.day >= latest - days) p,
    ];
    final cash = nw == null
        ? 0
        : nw.parts
            .where((p) => p.kind == PartKind.bank && !p.liability)
            .fold<int>(0, (a, p) => a + p.amountMinor);
    final summary = summarisePortfolio(holdings, cashMinor: cash);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            key: const Key('nw-filter'),
            tooltip: 'Include in net worth',
            icon: const Icon(Icons.tune),
            onPressed: () => _sheet(const ExclusionsSheet()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('holding-add'),
        onPressed: () => _sheet(const HoldingSheet()),
        icon: const Icon(Icons.add),
        label: const Text('Add holding'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _Hero(
            net: nw?.netMinor ?? 0,
            assets: nw?.assetsMinor ?? 0,
            liabilities: nw?.liabilitiesMinor ?? 0,
            change: inRange.length < 2
                ? null
                : inRange.last.netMinor - inRange.first.netMinor,
            base: inRange.length < 2 ? null : inRange.first.netMinor,
            money: money,
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                NetWorthChart(points: inRange),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < _ranges.length; i++)
                      ChoiceChip(
                        key: Key('range-${_ranges[i].$1}'),
                        label: Text(_ranges[i].$1),
                        selected: i == _range,
                        onSelected: (_) => setState(() => _range = i),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (summary.byClass.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Allocation(summary: summary, money: money),
          ],
          if (maturities.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Maturities(items: maturities),
          ],
          const SizedBox(height: 16),
          if (holdings.isEmpty)
            const SizedBox(
              height: 220,
              child: EmptyState(
                key: Key('portfolio_empty'),
                icon: Icons.account_balance_wallet_outlined,
                title: 'No holdings yet',
                hint: 'Add one or import a statement.',
              ),
            )
          else
            for (final k in HoldingKind.values)
              if (holdings.any((h) => h.kind == k))
                _Group(
                  kind: k,
                  items: holdings.where((h) => h.kind == k).toList(),
                  money: money,
                  onTap: (h) => _sheet(HoldingSheet(holding: h)),
                ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.net,
    required this.assets,
    required this.liabilities,
    required this.change,
    required this.base,
    required this.money,
  });

  final int net;
  final int assets;
  final int liabilities;
  final int? change;
  final int? base;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    final c = change;
    final b = base;
    final pct = (c != null && b != null && b != 0)
        ? ' (${(c / b.abs() * 100).toStringAsFixed(1)}%)'
        : '';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net worth', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            money(net),
            key: const Key('nw-value'),
            style: theme.textTheme.headlineMedium,
          ),
          if (c != null)
            Text(
              '${c >= 0 ? '+' : '-'}${money(c.abs())}$pct',
              key: const Key('nw-change'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: c >= 0 ? sem.income : sem.expense),
            ),
          const SizedBox(height: 8),
          Text(
            'Assets ${money(assets)}  ·  Liabilities ${money(liabilities)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Color _classColor(AssetClass c, ColorScheme s) => switch (c) {
      AssetClass.equity => s.primary,
      AssetClass.retirement => s.tertiary,
      AssetClass.debt => s.secondary,
      AssetClass.gold => const Color(0xFFC9A227),
      AssetClass.cash => const Color(0xFF26A69A),
      AssetClass.other => s.outline,
    };

class _Allocation extends StatelessWidget {
  const _Allocation({required this.summary, required this.money});

  final PortfolioSummary summary;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = summary.byClass.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    return AppCard(
      key: const Key('allocation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Allocation', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                for (final e in entries)
                  Expanded(
                    flex: (e.value * 1000 ~/ total).clamp(1, 1000),
                    child: Container(
                      height: 12,
                      color: _classColor(e.key, theme.colorScheme),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _classColor(e.key, theme.colorScheme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key.label)),
                  Text('${(e.value * 100 / total).round()}%'),
                  const SizedBox(width: 12),
                  Text(money(e.value)),
                ],
              ),
            ),
          if (summary.investedMinor > 0) ...[
            const Divider(),
            Text(
              'Invested ${money(summary.investedMinor)}  ·  Gain '
              '${summary.gainMinor < 0 ? '-' : '+'}'
              '${money(summary.gainMinor.abs())}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Maturities extends StatelessWidget {
  const _Maturities({required this.items});

  final List<MaturityItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    return AppCard(
      key: const Key('maturities'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upcoming maturities', style: theme.textTheme.titleSmall),
          for (final m in items)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(child: Text(m.name)),
                  Text(
                    m.daysLeft == 0 ? 'Today' : 'in ${m.daysLeft} d',
                    style: TextStyle(color: m.soon ? sem.warning : null),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.kind,
    required this.items,
    required this.money,
    required this.onTap,
  });

  final HoldingKind kind;
  final List<Holding> items;
  final String Function(int) money;
  final void Function(Holding) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    final total = items.fold<int>(0, (a, h) => a + (h.valueMinor ?? 0));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  holdingKindLabel(kind),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(money(total), style: theme.textTheme.titleSmall),
            ],
          ),
          for (final h in items)
            ListTile(
              key: Key('holding-${h.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: h.investedMinor == null
                  ? null
                  : Text('Invested ${money(h.investedMinor!)}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(h.valueMinor ?? 0)),
                  if (h.returnPct != null)
                    Text(
                      '${h.returnPct! >= 0 ? '+' : ''}'
                      '${h.returnPct!.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: h.returnPct! >= 0 ? sem.income : sem.expense,
                      ),
                    ),
                ],
              ),
              onTap: () => onTap(h),
            ),
        ],
      ),
    );
  }
}
