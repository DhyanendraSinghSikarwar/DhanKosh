/// A person the user shares costs with, and where they stand (FR-40-01).
class Person {
  /// Creates a person.
  const Person({
    required this.id,
    required this.name,
    required this.balanceMinor,
    required this.entryCount,
  });

  final int id;
  final String name;

  /// Positive: they owe the user. Negative: the user owes them. Paise.
  final int balanceMinor;
  final int entryCount;
}

/// One line between the user and a person (FR-40-02).
class PersonEntry {
  /// Creates an entry.
  const PersonEntry({
    required this.id,
    required this.personId,
    required this.amountMinor,
    required this.createdAt,
    this.note,
    this.transactionId,
  });

  final int id;
  final int personId;

  /// Positive: they owe the user more. Negative: a repayment or a debt.
  final int amountMinor;
  final String? note;

  /// The shared payment it came from.
  final int? transactionId;

  /// Epoch ms.
  final int createdAt;
}

/// Split arithmetic (FR-40-03). Pure; paise.
abstract final class SplitMath {
  /// Equal shares of [totalMinor] between the user and [others] people: each
  /// person gets the same whole-paise share and the user keeps the rest.
  static List<int> equalShares(int totalMinor, int others) {
    if (others <= 0 || totalMinor <= 0) return const [];
    final each = totalMinor ~/ (others + 1);
    return List.filled(others, each);
  }

  /// What is left for the user after [shares]; negative when the shares add
  /// up to more than the total.
  static int yourPart(int totalMinor, Iterable<int> shares) =>
      totalMinor - shares.fold<int>(0, (a, b) => a + b);
}

/// People and what they owe (F-40). Never writes `transactions`.
abstract interface class PeopleRepository {
  /// Everyone with their balance, by name.
  Stream<List<Person>> watchAll();

  /// Everyone once, by name.
  Future<List<Person>> all();

  /// Adds [name] (trimmed, 40 characters at most); an existing name in any
  /// case gives its id. A blank name throws [ArgumentError].
  Future<int> addPerson(String name);

  Future<void> rename(int id, String name);

  /// Deletes the person and their entries.
  Future<void> deletePerson(int id);

  /// A person's entries, newest first.
  Stream<List<PersonEntry>> watchEntries(int personId);

  /// Adds one entry; a zero amount is ignored.
  Future<void> addEntry(
    int personId,
    int amountMinor, {
    String? note,
    int? transactionId,
  });

  Future<void> deleteEntry(int id);

  /// Records how [transactionId] was shared: [shares] maps person id to the
  /// paise that person owes. Earlier shares of the same payment are replaced.
  Future<void> split({
    required int transactionId,
    required String label,
    required Map<int, int> shares,
  });

  /// Shares recorded for [transactionId]: person id to paise.
  Future<Map<int, int>> sharesOf(int transactionId);
}
