/// IST day of the last balance-updated notice per account (FR-21-04).
abstract interface class BalanceNoticeStore {
  /// Last notice day, or null.
  Future<int?> lastDay(String accountKey);

  /// True when no notice was sent on [epochDay] yet for [accountKey].
  Future<bool> shouldNotify(String accountKey, int epochDay);

  /// Records a notice on [epochDay].
  Future<void> record(String accountKey, int epochDay);
}
