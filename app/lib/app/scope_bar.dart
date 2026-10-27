import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';

const Map<Book, String> _bookLabels = {
  Book.all: 'All books',
  Book.personal: 'Personal',
  Book.business: 'Business',
};

/// Book chips: All books, Personal, Business (FR-20-23). Wired to
/// [bookProvider], so every screen reading it follows.
class BookChips extends ConsumerWidget {
  /// Creates the chips.
  const BookChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookProvider);
    return Wrap(
      spacing: 8,
      children: [
        for (final e in _bookLabels.entries)
          ChoiceChip(
            key: Key('book_${e.key.name}'),
            label: Text(e.value),
            selected: book == e.key,
            onSelected: (_) => ref.read(bookProvider.notifier).set(e.key),
          ),
      ],
    );
  }
}

/// Period chips (FR-20-22), wired to [periodProvider].
class PeriodChips extends ConsumerWidget {
  /// Creates the chips; [kinds] limits the presets shown.
  const PeriodChips({this.kinds, super.key});

  /// Presets to show; all when null.
  final List<PeriodKind>? kinds;

  static String _custom(PeriodSelection p) {
    final s = p.customStart;
    if (p.kind != PeriodKind.custom || s == null) return 'Custom';
    final e = p.customEnd ?? s;
    return '${s.day}/${s.month} – ${e.day}/${e.month}';
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      helpText: 'Choose dates',
    );
    if (r != null) ref.read(periodProvider.notifier).setCustom(r.start, r.end);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(periodProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final k in kinds ?? PeriodKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('period_${k.name}'),
                label:
                    Text(k == PeriodKind.custom ? _custom(p) : periodLabel(k)),
                selected: p.kind == k,
                onSelected: (_) {
                  if (k == PeriodKind.custom) {
                    unawaited(_pick(context, ref));
                  } else {
                    ref.read(periodProvider.notifier).set(k);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
