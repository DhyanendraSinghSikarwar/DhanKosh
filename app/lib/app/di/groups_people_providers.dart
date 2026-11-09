import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/people_split/data/people_repository_impl.dart';
import 'package:hisaab/features/people_split/domain/people.dart';
import 'package:hisaab/features/transaction_groups/data/tx_group_repository_impl.dart';
import 'package:hisaab/features/transaction_groups/domain/tx_group.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'groups_people_providers.g.dart';

// F-39 and F-40 wiring: groups of transactions and shared costs with people.

/// Groups in the encrypted database.
@Riverpod(keepAlive: true)
TxGroupRepository txGroupRepository(Ref ref) =>
    TxGroupRepositoryImpl(ref.watch(appDatabaseProvider));

/// All groups with totals, live.
@riverpod
Stream<List<TxGroup>> txGroups(Ref ref) =>
    ref.watch(txGroupRepositoryProvider).watchAll();

/// The transactions in one group, newest first, live.
@riverpod
Stream<List<LedgerTx>> groupMembers(Ref ref, int groupId) => ref
    .watch(transactionRepositoryProvider)
    .watch(LedgerFilter(groupId: groupId));

/// Names of the groups a transaction is in (refreshes as groups change).
@riverpod
Future<List<String>> txGroupNames(Ref ref, int txId) async {
  final groups = ref.watch(txGroupsProvider).value ?? const <TxGroup>[];
  final ids = await ref.watch(txGroupRepositoryProvider).groupIdsOf(txId);
  return [
    for (final g in groups)
      if (ids.contains(g.id)) g.name,
  ];
}

/// People and what they owe, in the encrypted database.
@Riverpod(keepAlive: true)
PeopleRepository peopleRepository(Ref ref) =>
    PeopleRepositoryImpl(ref.watch(appDatabaseProvider));

/// Everyone with their balance, live.
@riverpod
Stream<List<Person>> people(Ref ref) =>
    ref.watch(peopleRepositoryProvider).watchAll();

/// One person's entries, newest first, live.
@riverpod
Stream<List<PersonEntry>> personEntries(Ref ref, int personId) =>
    ref.watch(peopleRepositoryProvider).watchEntries(personId);

/// What one transaction was shared for: person id to paise (FR-40-03).
@riverpod
Future<Map<int, int>> txShares(Ref ref, int txId) {
  ref.watch(peopleProvider);
  return ref.watch(peopleRepositoryProvider).sharesOf(txId);
}
