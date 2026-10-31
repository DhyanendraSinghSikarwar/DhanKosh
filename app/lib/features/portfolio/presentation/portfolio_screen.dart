import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/app/di/net_worth_estimate_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/scope_bar.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_estimate.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_summary.dart';
import 'package:hisaab/features/portfolio/presentation/allocation_card.dart';
import 'package:hisaab/features/portfolio/presentation/compact_money.dart';
import 'package:hisaab/features/portfolio/presentation/exclusions_sheet.dart';
import 'package:hisaab/features/portfolio/presentation/holding_class_card.dart';
import 'package:hisaab/features/portfolio/presentation/holding_sheet.dart';
import 'package:hisaab/features/portfolio/presentation/investment_tx_section.dart';
import 'package:hisaab/features/portfolio/presentation/maturity_calendar.dart';
import 'package:hisaab/features/portfolio/presentation/net_worth_card.dart';
import 'package:hisaab/features/portfolio/presentation/networth_split_section.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_loans_section.dart';
import 'package:hisaab/features/portfolio/presentation/portfolio_settings_sheet.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
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
    final all = _history(
      points,
      ref.watch(netWorthEstimateProvider).value ?? const [],
    );
    final latest = all.isEmpty ? null : all.last.day;
    var inRange = [
      for (final p in all)
        if (days == null || latest == null || p.day >= latest - days) p,
    ];
    if (inRange.length < 2 && all.length >= 2) {
      inRange = all.sublist(all.length - 2);
    }
    final cash = nw == null
        ? 0
        : nw.parts
            .where((p) => p.kind == PartKind.bank && !p.liability)
            .fold<int>(0, (a, p) => a + p.amountMinor);
    final loanDebt = nw == null
        ? 0
        : nw.parts
            .where((p) => p.kind == PartKind.loan)
            .fold<int>(0, (a, p) => a + p.amountMinor.abs());
    final summary = summarisePortfolio(holdings, cashMinor: cash);
    final groups = groupByClass(holdings);
    final focus = groups.any((g) => g.cls == _focus) ? _focus : null;

    final visible = ref.watch(visibleSectionsProvider(ScreenIds.portfolio));
    final loans = ref.watch(loansStateProvider).value?.loans ?? const [];
    final sections = <String, Widget?>{
      'value': NetWorthCard(
        net: nw?.netMinor ?? 0,
        points: inRange,
        range: _range,
        onRange: (i) => setState(() => _range = i),
        investments: summary.valueMinor,
        bank: cash,
        loans: loanDebt,
        money: money,
        masked: masked,
        asOf: asOfLabel(DateTime.now().millisecondsSinceEpoch),
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
              compact: (m) => masked ? '••••' : compactMoney(m),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 10),
              child: Text(
                'Holdings',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
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
          if (widget.sipSection != null) ...[
            widget.sipSection!,
            const SizedBox(height: 12),
          ],
          if (holdings.isNotEmpty || invTxs.isNotEmpty) ...[
            InvestmentTxSection(items: invTxs, money: money),
            const SizedBox(height: 12),
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
        title: const Row(
          children: [
            Flexible(child: Text('Portfolio', overflow: TextOverflow.ellipsis)),
            BookTag(),
          ],
        ),
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
          PopupMenuButton<String>(
            key: const Key('portfolio-more'),
            onSelected: (v) {
              switch (v) {
                case 'import':
                  unawaited(context.push('/statements'));
                case 'holding':
                  _sheet(const HoldingSheet());
                case 'sip':
                  _sheet(widget.sipSheet!(context));
                case 'settings':
                  _sheet(const PortfolioSettingsSheet());
                case 'sections':
                  _sheet(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: widget.layoutEditor,
                    ),
                  );
                default:
                  _sheet(const ExclusionsSheet());
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                key: Key('shortcut-import'),
                value: 'import',
                child: Text('Import statement'),
              ),
              const PopupMenuItem(
                key: Key('shortcut-holding'),
                value: 'holding',
                child: Text('Add holding'),
              ),
              PopupMenuItem(
                key: const Key('shortcut-sip'),
                value: 'sip',
                enabled: widget.sipSheet != null,
                child: const Text('Add SIP'),
              ),
              const PopupMenuItem(
                key: Key('portfolio-settings'),
                value: 'settings',
                child: Text('Portfolio settings'),
              ),
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
      floatingActionButton: FloatingActionButton(
        key: const Key('holding-add'),
        heroTag: null,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tooltip: 'Add holding',
        onPressed: () => _sheet(const HoldingSheet()),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
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

/// `d MMM yyyy` of [ms] in IST.
String asOfLabel(int ms) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final d = DateTime.fromMillisecondsSinceEpoch(ms + 19800000, isUtc: true);
  return '${d.day} ${m[d.month - 1]} ${d.year}';
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
    final scheme = Theme.of(context).colorScheme;
    Widget chip(Key key, String label, VoidCallback tap, {required bool on}) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(16),
            onTap: tap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: on ? scheme.primaryContainer : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: on
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
          ),
        );
    return SingleChildScrollView(
      key: const Key('class-chips'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            const Key('class-chip-all'),
            'All',
            () => onFocus(null),
            on: focus == null,
          ),
          for (final c in classes)
            chip(
              Key('class-chip-${c.name}'),
              c.label,
              () => onFocus(c),
              on: focus == c,
            ),
        ],
      ),
    );
  }
}

/// Estimated month-ends before the first recorded day, then the recorded
/// points, so the line is never blank when there is data (FR-16-05).
List<WorthPoint> _history(
  List<WorthPoint> recorded,
  List<EstimatedPoint> estimate,
) {
  final firstRecorded = recorded.isEmpty ? null : recorded.first.day;
  return [
    for (final e in estimate)
      if (firstRecorded == null || e.point.day < firstRecorded) e.point,
    ...recorded,
  ];
}
