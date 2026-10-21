/// Wipes ledger data (FR-26-31). Settings and the sealed identity stay.
abstract interface class DataResetRepository {
  /// Deletes transactions, sources, tombstones, accounts and learned rules,
  /// and resets the SMS cursor so the next scan re-reads the inbox.
  Future<void> clearLedger();
}
