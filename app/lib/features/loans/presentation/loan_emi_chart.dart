import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hisaab/features/loans/domain/amortization.dart';

/// Stacked bars of principal and interest per EMI (yearly sums beyond 24
/// instalments), with the paid share highlighted by the legend (B13).
class LoanEmiChart extends StatelessWidget {
  /// Creates the chart for [schedule].
  const LoanEmiChart({required this.schedule, super.key});

  /// Instalments, first to last.
  final List<Instalment> schedule;

  /// Groups [schedule] into bars: one per EMI, or one per 12 EMIs when long.
  static List<({int principal, int interest})> bars(List<Instalment> schedule) {
    final step = schedule.length > 24 ? 12 : 1;
    final out = <({int principal, int interest})>[];
    for (var i = 0; i < schedule.length; i += step) {
      var p = 0;
      var n = 0;
      for (final s in schedule.skip(i).take(step)) {
        p += s.principalMinor;
        n += s.interestMinor;
      }
      out.add((principal: p, interest: n));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = bars(schedule);
    if (data.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          schedule.length > 24
              ? 'Principal and interest by year'
              : 'Principal and interest per EMI',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: BarChart(
            key: const Key('loan-emi-chart'),
            BarChartData(
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barTouchData: const BarTouchData(enabled: false),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (data[i].principal + data[i].interest) / 100,
                        width: 8,
                        borderRadius: BorderRadius.zero,
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            data[i].principal / 100,
                            scheme.primary,
                          ),
                          BarChartRodStackItem(
                            data[i].principal / 100,
                            (data[i].principal + data[i].interest) / 100,
                            scheme.tertiary,
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            _Dot(scheme.primary),
            const Text(' Principal   '),
            _Dot(scheme.tertiary),
            const Text(' Interest'),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
