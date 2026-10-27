import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/features/search_filters/domain/ledger_view_state.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:parser_core/parser_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ledger_view_notifier.g.dart';

/// Filter state of the Transactions tab (FR-20-11..16).
@Riverpod(keepAlive: true)
class LedgerViewNotifier extends _$LedgerViewNotifier {
  @override
  LedgerViewState build() {
    // Period and book are app-wide (FR-20-22, FR-20-23): mirror the stores.
    ref
      ..listen(periodProvider, (_, p) {
        state = state.copyWith(
          period: p.kind,
          customStart: p.customStart,
          customEnd: p.customEnd,
        );
      })
      ..listen(bookProvider, (_, b) => state = state.copyWith(book: b));
    final p = ref.read(periodProvider);
    return LedgerViewState(
      period: p.kind,
      customStart: p.customStart,
      customEnd: p.customEnd,
      book: ref.read(bookProvider),
    );
  }

  void setQuery(String q) => state = state.copyWith(query: q);
  void setKind(TxKind k) => state = state.copyWith(kind: k);
  void setPeriod(PeriodKind p) => ref.read(periodProvider.notifier).set(p);
  void setCustom(DateTime start, DateTime? end) =>
      ref.read(periodProvider.notifier).setCustom(start, end);
  void setAccountKind(AccountKind? k) =>
      state = state.copyWith(accountKind: () => k);
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
