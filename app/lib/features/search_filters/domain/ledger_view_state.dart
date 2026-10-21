import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';

/// Period choices of the Transactions tab (FR-20-03; Phase 1 subset).
enum PeriodKind { thisMonth, lastMonth, custom, all }

/// `[fromMs, toMs)` in epoch ms; null bounds are open.
typedef PeriodRange = ({int? fromMs, int? toMs});

/// Resolves [kind] to a local-time range (FR-20-04, FR-20-05).
///
/// [customStart] / [customEnd] are inclusive dates; a missing end equals the
/// start.
PeriodRange periodRange(
  PeriodKind kind,
  DateTime now, {
  DateTime? customStart,
  DateTime? customEnd,
}) {
  int ms(DateTime d) => d.millisecondsSinceEpoch;
  switch (kind) {
    case PeriodKind.all:
      return (fromMs: null, toMs: null);
    case PeriodKind.thisMonth:
      return (
        fromMs: ms(DateTime(now.year, now.month)),
        toMs: ms(DateTime(now.year, now.month + 1)),
      );
    case PeriodKind.lastMonth:
      return (
        fromMs: ms(DateTime(now.year, now.month - 1)),
        toMs: ms(DateTime(now.year, now.month)),
      );
    case PeriodKind.custom:
      if (customStart == null) return (fromMs: null, toMs: null);
      final end = customEnd ?? customStart;
      return (
        fromMs:
            ms(DateTime(customStart.year, customStart.month, customStart.day)),
        toMs: ms(DateTime(end.year, end.month, end.day + 1)),
      );
  }
}

/// Everything the Transactions tab filters on (FR-20-11..16).
class LedgerViewState {
  const LedgerViewState({
    this.kind = TxKind.all,
    this.period = PeriodKind.thisMonth,
    this.customStart,
    this.customEnd,
    this.query = '',
    this.accountId,
    this.category,
  });

  final TxKind kind;
  final PeriodKind period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String query;
  final int? accountId;
  final Category? category;

  /// True when a chip filter (type, account, category) is set (FR-20-16).
  bool get hasChipFilters =>
      kind != TxKind.all || accountId != null || category != null;

  LedgerViewState copyWith({
    TxKind? kind,
    PeriodKind? period,
    DateTime? customStart,
    DateTime? customEnd,
    String? query,
    int? Function()? accountId,
    Category? Function()? category,
  }) =>
      LedgerViewState(
        kind: kind ?? this.kind,
        period: period ?? this.period,
        customStart: customStart ?? this.customStart,
        customEnd: customEnd ?? this.customEnd,
        query: query ?? this.query,
        accountId: accountId != null ? accountId() : this.accountId,
        category: category != null ? category() : this.category,
      );

  /// Resets type, account and category; keeps search and period (FR-20-16).
  LedgerViewState cleared() => LedgerViewState(
        period: period,
        customStart: customStart,
        customEnd: customEnd,
        query: query,
      );

  /// The repository filter for [now].
  LedgerFilter toFilter(DateTime now) {
    final r = periodRange(
      period,
      now,
      customStart: customStart,
      customEnd: customEnd,
    );
    return LedgerFilter(
      kind: kind,
      fromMs: r.fromMs,
      toMs: r.toMs,
      query: query.trim(),
      accountId: accountId,
      category: category,
    );
  }
}
