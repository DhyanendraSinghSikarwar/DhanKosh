import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';

/// [CardFlowSource] reading the ledger through [TransactionRepository]
/// (read only, FR-14-17).
class CardFlowSourceImpl implements CardFlowSource {
  /// Creates the source.
  const CardFlowSourceImpl(this._txs);

  final TransactionRepository _txs;

  @override
  Future<List<CardFlow>> flowSince(int accountId, int fromMs) async {
    final rows = await _txs
        .watch(LedgerFilter(accountId: accountId, fromMs: fromMs))
        .first;
    return [
      for (final t in rows.reversed)
        if (t.inrMinor != null && t.duplicateOfId == null)
          CardFlow(t.timestamp, t.type, t.inrMinor!),
    ];
  }
}
