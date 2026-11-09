/// A named bundle of transactions with its totals (FR-39-01).
class TxGroup {
  /// Creates a group.
  const TxGroup({
    required this.id,
    required this.name,
    required this.count,
    required this.spentMinor,
    required this.incomeMinor,
  });

  final int id;
  final String name;

  /// Transactions in it.
  final int count;

  /// Debits in it, paise (transfers, review rows and left-out rows excluded).
  final int spentMinor;

  /// Credits in it, paise (same exclusions).
  final int incomeMinor;
}

/// Groups of transactions (F-39). Never writes `transactions`.
abstract interface class TxGroupRepository {
  /// Every group, newest first, with totals.
  Stream<List<TxGroup>> watchAll();

  /// Makes a group; a blank name is refused with [ArgumentError].
  Future<int> create(String name);

  Future<void> rename(int id, String name);

  /// Deletes the group; its transactions stay.
  Future<void> delete(int id);

  /// Puts [txIds] in the group.
  Future<void> add(int groupId, List<int> txIds);

  /// Takes one transaction out of the group.
  Future<void> remove(int groupId, int txId);

  /// Ids of the groups [txId] is in.
  Future<Set<int>> groupIdsOf(int txId);

  /// Puts [txId] in exactly [groupIds].
  Future<void> setGroupsOf(int txId, Set<int> groupIds);
}
