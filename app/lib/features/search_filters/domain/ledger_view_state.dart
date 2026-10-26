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

/// Whole rupees with up to two decimals (`1,250.5`) to paise by integer
/// math (FR-20-21); null when empty or not a plain amount.
int? rupeesToMinor(String text) {
  final t = text.replaceAll(',', '').replaceAll('₹', '').trim();
  final m = RegExp(r'^(\d{1,12})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final frac = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + int.parse(frac.isEmpty ? '0' : frac);
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
    this.sources = const {},
    this.minMinor,
    this.maxMinor,
  });

  final TxKind kind;
  final PeriodKind period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String query;
  final int? accountId;
  final Category? category;

  /// Origins to include; empty means all (FR-20-15).
  final Set<Source> sources;

  /// Amount bounds in paise (FR-20-21).
  final int? minMinor;
  final int? maxMinor;

  /// True when a chip filter (type, account, category, source, amount) is
  /// set (FR-20-16).
  bool get hasChipFilters =>
      kind != TxKind.all ||
      accountId != null ||
      category != null ||
      sources.isNotEmpty ||
      minMinor != null ||
      maxMinor != null;

  LedgerViewState copyWith({
    TxKind? kind,
    PeriodKind? period,
    DateTime? customStart,
    DateTime? customEnd,
    String? query,
    int? Function()? accountId,
    Category? Function()? category,
    Set<Source>? sources,
    int? Function()? minMinor,
    int? Function()? maxMinor,
  }) =>
      LedgerViewState(
        kind: kind ?? this.kind,
        period: period ?? this.period,
        customStart: customStart ?? this.customStart,
        customEnd: customEnd ?? this.customEnd,
        query: query ?? this.query,
        accountId: accountId != null ? accountId() : this.accountId,
        category: category != null ? category() : this.category,
        sources: sources ?? this.sources,
        minMinor: minMinor != null ? minMinor() : this.minMinor,
        maxMinor: maxMinor != null ? maxMinor() : this.maxMinor,
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
      sources: sources,
      minMinor: minMinor,
      maxMinor: maxMinor,
    );
  }
}
