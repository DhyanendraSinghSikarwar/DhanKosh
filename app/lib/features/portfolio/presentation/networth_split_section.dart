import 'package:flutter/material.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_charts.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Net worth by account: stacked bar with legend, assets and liabilities
/// breakdown, and the "choose which money counts" action (FR-16-06, B7).
class NetWorthSplitSection extends StatelessWidget {
  /// Creates the section.
  const NetWorthSplitSection({
    required this.worth,
    required this.money,
    required this.onChoose,
    super.key,
  });

  final NetWorth worth;
  final String Function(int) money;

  /// Opens the exclusions sheet.
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final assets = splitByAccount(worth.parts);
    final debts = liabilityShares(worth.parts);
    final total = assets.fold<int>(0, (s, e) => s + e.amountMinor);
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      const Color(0xFFC9A227),
      const Color(0xFF26A69A),
      const Color(0xFF7986CB),
      scheme.outline,
    ];
    return AppCard(
      key: const Key('networth-split'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net worth by account', style: theme.textTheme.titleSmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('networth-choose'),
              onPressed: onChoose,
              child: const Text('Choose which money counts'),
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 4),
            ClipRRect(
              key: const Key('networth-split-bar'),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  for (final (i, e) in assets.indexed)
                    Expanded(
                      flex: (e.amountMinor * 1000 ~/ total).clamp(1, 1000),
                      child: Container(
                        height: 12,
                        color: colors[i % colors.length],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, e) in assets.indexed)
              _Row(
                label: e.label,
                value: money(e.amountMinor),
                dot: colors[i % colors.length],
                pct: '${e.amountMinor * 100 ~/ total}%',
              ),
          ],
          const Divider(),
          _Row(label: 'Assets', value: money(worth.assetsMinor), bold: true),
          _Row(
            label: 'Liabilities',
            value: money(worth.liabilitiesMinor),
            bold: true,
          ),
          for (final d in debts)
            _Row(label: d.label, value: money(d.amountMinor)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.dot,
    this.pct,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? dot;
  final String? pct;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? Theme.of(context).textTheme.titleSmall : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (dot != null) ...[
            Icon(Icons.circle, size: 10, color: dot),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(label, style: style)),
          if (pct != null) ...[Text(pct!), const SizedBox(width: 12)],
          Text(value, style: style),
        ],
      ),
    );
  }
}
