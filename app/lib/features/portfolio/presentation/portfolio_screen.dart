import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/scope_bar.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_summary.dart';
import 'package:hisaab/features/portfolio/presentation/allocation_card.dart';
import 'package:hisaab/features/portfolio/presentation/exclusions_sheet.dart';
import 'package:hisaab/features/portfolio/presentation/holding_class_card.dart';
import 'package:hisaab/features/portfolio/presentation/holding_sheet.dart';
import 'package:hisaab/features/portfolio/presentation/investment_tx_section.dart';
import 'package:hisaab/features/portfolio/presentation/maturity_calendar.dart';
import 'package:hisaab/features/portfolio/presentation/net_worth_chart.dart';
import 'package:hisaab/features/portfolio/presentation/networth_split_section.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_class_style.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_loans_section.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_settings_sheet.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
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
  /// Creates the screen. [sipSection] and [sipSheet] are composed in
  /// `app/router.dart` (SIPs belong to Bills, F-12).
  const PortfolioScreen({
    this.sipSection,
    this.sipSheet,
    this.layoutEditor,
    super.key,
  });

  /// Section editor shown from the app bar, composed by the router from
  /// Customise (FR-28-15).
  final Widget? layoutEditor;

  /// SIP list shown under the shortcuts (FR-16-26).
  final Widget? sipSection;

  /// Builds the Add SIP sheet (FR-16-26).
  final WidgetBuilder? sipSheet;

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  int _range = 2;
  PortfolioClass? _focus;

  void _sheet(Widget w) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => w,
      );

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final nw = ref.watch(bookNetWorthProvider).value;
    final holdings = ref.watch(holdingsProvider).value ?? const <Holding>[];
    final points = ref.watch(netWorthPointsProvider).value ?? const [];
    final maturities =
        ref.watch(maturitiesProvider).value ?? const <MaturityItem>[];
    final invTxs = ref.watch(investmentTxsProvider).value ?? const [];
    final asOfMs = holdings.fold<int>(
      0,
      (a, h) => (h.asOf ?? 0) > a ? h.asOf! : a,
    );
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
    final groups = groupByClass(holdings);
    final focus = groups.any((g) => g.cls == _focus) ? _focus : null;

    final visible = ref.watch(visibleSectionsProvider(ScreenIds.portfolio));
    final loans = ref.watch(loansStateProvider).value?.loans ?? const [];
    final sections = <String, Widget?>{
      'value': Column(
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
          Row(
            key: const Key('portfolio-shortcuts'),
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('shortcut-import'),
                  onPressed: () => context.push('/statements'),
                  child: const Text('Import statement'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('shortcut-holding'),
                  onPressed: () => _sheet(const HoldingSheet()),
                  child: const Text('Add holding'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('shortcut-sip'),
                  onPressed: widget.sipSheet == null
                      ? null
                      : () => _sheet(widget.sipSheet!(context)),
                  child: const Text('Add SIP'),
                ),
              ),
            ],
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
                const Divider(height: 24),
                _SummaryRow(
                  investments: summary.valueMinor,
                  bank: cash,
                  loans: nw?.liabilitiesMinor ?? 0,
                  money: money,
                ),
              ],
            ),
          ),
        ],
      ),
      'allocation': groups.isEmpty
          ? null
          : AllocationCard(
              groups: groups,
              focus: focus,
              onFocus: (c) => setState(() => _focus = c),
              investedMinor: summary.investedMinor,
              gainMinor: summary.gainMinor,
              money: money,
              asOfLabel: asOfMs > 0 ? 'as of ${asOfLabel(asOfMs)}' : '',
            ),
      'networth': nw == null || nw.parts.isEmpty
          ? null
          : NetWorthSplitSection(
              worth: nw,
              money: money,
              onChoose: () => _sheet(const ExclusionsSheet()),
            ),
      'holdings': Column(
        children: [
          if (widget.sipSection != null) ...[
            widget.sipSection!,
            const SizedBox(height: 12),
          ],
          if (holdings.isNotEmpty || invTxs.isNotEmpty) ...[
            InvestmentTxSection(items: invTxs, money: money),
            const SizedBox(height: 12),
          ],
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
          else ...[
            _ClassChips(
              classes: [for (final g in groups) g.cls],
              focus: focus,
              onFocus: (c) => setState(() => _focus = c),
            ),
            const SizedBox(height: 12),
            for (final g in groups)
              if (focus == null || focus == g.cls)
                HoldingClassCard(
                  group: g,
                  money: money,
                  dateLabel: asOfLabel,
                  onTap: (h) => _sheet(HoldingSheet(holding: h)),
                ),
          ],
        ],
      ),
      'loans': loans.any((l) => !l.closed)
          ? PortfolioLoansSection(loans: loans, money: money)
          : null,
      'maturity':
          maturities.isEmpty ? null : MaturityCalendar(items: maturities),
    };

    return Scaffold(
      appBar: AppBar(
        title: const TabTitle('Portfolio'),
        actions: [
          IconButton(
            key: const Key('portfolio-news'),
            tooltip: 'Latest news',
            icon: Badge(
              smallSize: 8,
              isLabelVisible: !ref.watch(newsSeenProvider),
              child: const Icon(Icons.newspaper_outlined),
            ),
            onPressed: () => context.push('/news'),
          ),
          IconButton(
            key: const Key('portfolio-settings'),
            tooltip: 'Portfolio settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _sheet(const PortfolioSettingsSheet()),
          ),
          PopupMenuButton<String>(
            key: const Key('portfolio-more'),
            onSelected: (v) {
              if (v == 'sections') {
                _sheet(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: widget.layoutEditor,
                  ),
                );
              } else {
                _sheet(const ExclusionsSheet());
              }
            },
            itemBuilder: (_) => [
              if (widget.layoutEditor != null)
                const PopupMenuItem(
                  key: Key('portfolio-sections'),
                  value: 'sections',
                  child: Text('Edit sections'),
                ),
              const PopupMenuItem(
                key: Key('nw-filter'),
                value: 'filter',
                child: Text('Include in net worth'),
              ),
            ],
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
          for (final id in visible)
            if (sections[id] case final w?) ...[
              w,
              const SizedBox(height: 12),
            ],
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
            'as of ${asOfLabel(DateTime.now().millisecondsSinceEpoch)}',
            key: const Key('nw-as-of'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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

/// `d MMM yyyy` of [ms] in IST.
String asOfLabel(int ms) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = DateTime.fromMillisecondsSinceEpoch(ms + 19800000, isUtc: true);
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.investments,
    required this.bank,
    required this.loans,
    required this.money,
  });

  final int investments;
  final int bank;
  final int loans;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sem = theme.extension<SemanticColors>()!;
    Widget cell(String label, String value, {Color? color, Key? key}) =>
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                key: key,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
        );
    return Row(
      key: const Key('nw-summary'),
      children: [
        cell('Investments', money(investments)),
        cell('Bank', money(bank)),
        cell(
          'Loans',
          loans > 0 ? '-${money(loans)}' : money(0),
          color: loans > 0 ? sem.expense : null,
        ),
      ],
    );
  }
}

class _ClassChips extends StatelessWidget {
  const _ClassChips({
    required this.classes,
    required this.focus,
    required this.onFocus,
  });

  final List<PortfolioClass> classes;
  final PortfolioClass? focus;
  final ValueChanged<PortfolioClass?> onFocus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('class-chips'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('class-chip-all'),
            label: const Text('All'),
            selected: focus == null,
            onSelected: (_) => onFocus(null),
          ),
          for (final c in classes) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: Key('class-chip-${c.name}'),
              avatar: Icon(
                portfolioClassIcon(c).icon,
                size: 16,
                color: portfolioClassColor(c),
              ),
              label: Text(c.label),
              selected: focus == c,
              onSelected: (_) => onFocus(c),
            ),
          ],
        ],
      ),
    );
  }
}
