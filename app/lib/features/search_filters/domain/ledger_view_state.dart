import 'package:hisaab/features/portfolio/domain/net_worth.dart' show Book;
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';

/// Shared period choices (FR-20-03, FR-20-22): this month, last month, this
/// week, this and last financial year (Apr-Mar), 12 months, all time, custom.
enum PeriodKind {
  thisMonth,
  lastMonth,
  thisWeek,
  thisFy,
  lastFy,
  last12Months,
  all,
  custom,
}

/// Short chip label of [k].
String periodLabel(PeriodKind k) => switch (k) {
      PeriodKind.thisMonth => 'This month',
      PeriodKind.lastMonth => 'Last month',
      PeriodKind.thisWeek => 'This week',
      PeriodKind.thisFy => 'This FY',
      PeriodKind.lastFy => 'Last FY',
      PeriodKind.last12Months => '12 months',
      PeriodKind.all => 'All time',
      PeriodKind.custom => 'Custom',
    };

/// The app-wide period (FR-20-22): a kind plus inclusive custom dates.
class PeriodSelection {
  const PeriodSelection(this.kind, {this.customStart, this.customEnd});

  final PeriodKind kind;
  final DateTime? customStart;
  final DateTime? customEnd;

  /// `[fromMs, toMs)` for [now].
  PeriodRange range(DateTime now) => periodRange(
        kind,
        now,
        customStart: customStart,
        customEnd: customEnd,
      );
}

/// `PERSONAL` / `BUSINESS` for the book scope; null for all books.
String? bookUsage(Book b) => switch (b) {
      Book.all => null,
      Book.personal => 'PERSONAL',
      Book.business => 'BUSINESS',
    };

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
    case PeriodKind.thisWeek:
      final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      return (
        fromMs: ms(start),
        toMs: ms(DateTime(start.year, start.month, start.day + 7)),
      );
    case PeriodKind.thisFy:
    case PeriodKind.lastFy:
      final fy = now.month >= 4 ? now.year : now.year - 1;
      final y = kind == PeriodKind.thisFy ? fy : fy - 1;
      return (fromMs: ms(DateTime(y, 4)), toMs: ms(DateTime(y + 1, 4)));
    case PeriodKind.last12Months:
      return (
        fromMs: ms(DateTime(now.year, now.month - 11)),
        toMs: ms(DateTime(now.year, now.month + 1)),
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
    this.book = Book.all,
    this.accountKind,
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

  /// Book scope (FR-20-23), mirrored from the shared book store.
  final Book book;

  /// Accounts only or cards only (FR-08-23); null shows both.
  final AccountKind? accountKind;

  /// True when a chip filter (type, account, category, source, amount) is
  /// set (FR-20-16).
  bool get hasChipFilters =>
      kind != TxKind.all ||
      accountId != null ||
      category != null ||
      sources.isNotEmpty ||
      minMinor != null ||
      maxMinor != null ||
      accountKind != null;

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
    Book? book,
    AccountKind? Function()? accountKind,
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
        book: book ?? this.book,
        accountKind: accountKind != null ? accountKind() : this.accountKind,
      );

  /// Resets type, account and category; keeps search and period (FR-20-16).
  LedgerViewState cleared() => LedgerViewState(
        period: period,
        customStart: customStart,
        customEnd: customEnd,
        query: query,
        book: book,
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
      accountKind: accountKind,
      usage: bookUsage(book),
    );
  }
}
