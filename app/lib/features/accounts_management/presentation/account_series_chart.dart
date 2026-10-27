// Riverpod's autoDispose provider types are not worth spelling out.
// ignore_for_file: specify_nonobvious_property_types
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/accounts_management/domain/account_series.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:intl/intl.dart';

/// Spend and income lines per month with a 6 months / Year / All time switch
/// and the two totals (FR-13-17, memory 37).
class AccountSeriesChart extends ConsumerStatefulWidget {
  /// Creates the chart for [accountId] (merged children included).
  const AccountSeriesChart({required this.accountId, super.key});

  final int accountId;

  @override
  ConsumerState<AccountSeriesChart> createState() => _State();
}

class _State extends ConsumerState<AccountSeriesChart> {
  SeriesRange _range = SeriesRange.sixMonths;
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final txs = ref
            .watch(
              _txProvider(widget.accountId),
            )
            .value ??
        const [];
    final pts = monthSeries(txs, _range, DateTime.now());
    final spent = pts.fold<int>(0, (a, p) => a + p.spentMinor);
    final income = pts.fold<int>(0, (a, p) => a + p.incomeMinor);
    final empty = spent == 0 && income == 0;
    final i = _picked != null && _picked! < pts.length ? _picked : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<SeriesRange>(
          key: const Key('series_range'),
          showSelectedIcon: false,
          segments: [
            for (final r in SeriesRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() {
            _range = s.first;
            _picked = null;
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Spent ${formatAmount(spent, masked: masked)}',
                key: const Key('series_spent'),
              ),
            ),
            Expanded(
              child: Text(
                'Income ${formatAmount(income, masked: masked)}',
                key: const Key('series_income'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (empty)
          const SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Nothing moved in this period.',
                key: Key('series_empty'),
              ),
            ),
          )
        else
          Semantics(
            label: 'Spend and income by month',
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (pts.length / 6).ceilToDouble(),
                        getTitlesWidget: (v, _) {
                          final k = v.toInt();
                          if (k < 0 || k >= pts.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            DateFormat.MMM().format(
                              DateTime(pts[k].year, pts[k].month),
                            ),
                            style: theme.textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchCallback: (e, r) {
                      final s = r?.lineBarSpots;
                      if (e is FlTapUpEvent && s != null && s.isNotEmpty) {
                        setState(() => _picked = s.first.x.toInt());
                      }
                    },
                  ),
                  lineBarsData: [
                    _line(pts.map((p) => p.spentMinor).toList(), scheme.error),
                    _line(
                      pts.map((p) => p.incomeMinor).toList(),
                      scheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (i != null)
          Text(
            '${DateFormat.yMMM().format(DateTime(pts[i].year, pts[i].month))}: '
            'spent ${formatAmount(pts[i].spentMinor, masked: masked)}, '
            'income ${formatAmount(pts[i].incomeMinor, masked: masked)}',
            key: const Key('series_picked'),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  LineChartBarData _line(List<int> v, Color c) => LineChartBarData(
        spots: [
          for (var k = 0; k < v.length; k++) FlSpot(k.toDouble(), v[k] / 100),
        ],
        isCurved: true,
        color: c,
        dotData: const FlDotData(show: false),
      );
}

final _txProvider = StreamProvider.autoDispose.family<List<LedgerTx>, int>(
  (ref, accountId) => ref
      .watch(transactionRepositoryProvider)
      .watch(LedgerFilter(accountId: accountId)),
);
