import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/home_composition_providers.dart';
import 'package:hisaab/app/theme/semantic_colors.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Net worth at the top of Home; opens Portfolio (FR-17-26).
class HomeNetWorthCard extends ConsumerWidget {
  /// Creates the card.
  const HomeNetWorthCard({required this.masked, super.key});

  final bool masked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nw = ref.watch(homeNetWorthProvider);
    if (nw == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.extension<SemanticColors>();
    final change = nw.change;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: const Key('home_networth'),
        onTap: () => context.go('/portfolio'),
        child: nw.empty
            ? Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Add accounts to see net worth')),
                  TextButton(
                    key: const Key('home_networth_add'),
                    onPressed: () => context.push('/accounts'),
                    child: const Text('Add account'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net worth', style: theme.textTheme.bodySmall),
                  CountUpAmount(
                    key: const Key('home_networth_value'),
                    minor: nw.netMinor,
                    masked: masked,
                    style: theme.textTheme.headlineMedium,
                  ),
                  if (change != null && change.deltaMinor != 0)
                    Text(
                      '${change.deltaMinor > 0 ? '+' : '−'}'
                      '${formatAmount(change.deltaMinor.abs(), masked: masked, paise: false)}'
                      '${change.percentTenths == null || masked ? '' : ' (${_pct(change.percentTenths!)})'}'
                      ' since last point',
                      key: const Key('home_networth_change'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: change.deltaMinor > 0
                            ? colors?.income
                            : colors?.warning,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  static String _pct(int tenths) {
    final a = tenths.abs();
    return '${tenths < 0 ? '−' : '+'}${a ~/ 10}.${a % 10}%';
  }
}

/// Amount that counts up from zero once when shown. Static when masked, when
/// the platform asks for reduced motion, and under `flutter test`.
class CountUpAmount extends StatelessWidget {
  /// Creates the amount.
  const CountUpAmount({
    required this.minor,
    required this.masked,
    this.style,
    super.key,
  });

  /// Paise.
  final int minor;
  final bool masked;
  final TextStyle? style;

  static bool get _inTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final still = masked || _inTest || MediaQuery.disableAnimationsOf(context);
    if (still) {
      return Text(
        formatAmount(minor, masked: masked, paise: false),
        style: style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (_, t, __) => Text(
        formatAmount((minor * t).round(), masked: false, paise: false),
        style: style,
      ),
    );
  }
}
