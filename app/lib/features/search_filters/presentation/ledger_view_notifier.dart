import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ledger_view_notifier.g.dart';

/// Filter state of the Transactions tab (FR-20-11..16).
@Riverpod(keepAlive: true)
class LedgerViewNotifier extends _$LedgerViewNotifier {
  @override
  LedgerViewState build() => const LedgerViewState();

  void setQuery(String q) => state = state.copyWith(query: q);
  void setKind(TxKind k) => state = state.copyWith(kind: k);
  void setPeriod(PeriodKind p) => state = state.copyWith(period: p);
  void setCustom(DateTime start, DateTime? end) => state = LedgerViewState(
        kind: state.kind,
        period: PeriodKind.custom,
        customStart: start,
        customEnd: end,
        query: state.query,
        accountId: state.accountId,
        category: state.category,
        sources: state.sources,
        minMinor: state.minMinor,
        maxMinor: state.maxMinor,
      );
  void setAccount(int? id) => state = state.copyWith(accountId: () => id);
  void setCategory(Category? c) => state = state.copyWith(category: () => c);

  /// Toggles [s] in the source filter (FR-20-15).
  void toggleSource(Source s) {
    final next = {...state.sources};
    if (!next.remove(s)) next.add(s);
    state = state.copyWith(sources: next);
  }

  /// Sets the amount range in paise; null is open (FR-20-21).
  void setAmountRange(int? minMinor, int? maxMinor) => state =
      state.copyWith(minMinor: () => minMinor, maxMinor: () => maxMinor);

  /// Resets type, account and category (FR-20-16).
  void clear() => state = state.cleared();
}
