/// Wipes ledger data (FR-26-28). Settings and the sealed identity stay.
abstract interface class DataResetRepository {
  /// Deletes transactions, sources, tombstones, accounts and learned rules,
  /// and resets the SMS cursor so the next scan re-reads the inbox.
  Future<void> clearLedger();

  /// Deletes every row of every table (FR-25-26 Erase all data). With
  /// [keepSettings] the settings table survives (replace-restore, FR-24-27).
  Future<void> eraseAll({bool keepSettings = false});
}
