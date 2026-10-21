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
      );
  void setAccount(int? id) => state = state.copyWith(accountId: () => id);
  void setCategory(Category? c) => state = state.copyWith(category: () => c);

  /// Resets type, account and category (FR-20-16).
  void clear() => state = state.cleared();
}
