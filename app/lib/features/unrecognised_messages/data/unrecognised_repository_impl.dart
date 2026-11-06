import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ids.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_repository.dart';

/// [UnrecognisedRepository] over the encrypted database (FR-38-04..10).
class UnrecognisedRepositoryImpl implements UnrecognisedRepository {
  /// Creates the repository. [now] is injectable for tests.
  UnrecognisedRepositoryImpl(this._db, {int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final int Function() _now;

  /// A repeat of a handled message this close is the same alert delivered
  /// twice (FR-38-05).
  static const int redeliveryMs = 2 * 60 * 1000;

  /// How long a message's text is kept (FR-38-10).
  static const int retentionMs = 30 * Duration.millisecondsPerDay;

  /// After this long an emptied row is deleted.
  static const int tombstoneMs = 400 * Duration.millisecondsPerDay;

  static String _hash(String body) => SmsIds.sha256Hex(body);

  UnrecognisedMessage _toDomain(UnrecognisedRow r) => UnrecognisedMessage(
        id: r.id,
        source: UnrecognisedSource.fromKey(r.source),
        sender: r.sender,
        senderKey: r.senderKey,
        sourceMessageId: r.sourceMessageId,
        body: r.body,
        receivedAt: r.receivedAt,
        status: UnrecognisedStatus.fromKey(r.status),
        transactionId: r.transactionId,
      );

  SenderPref _toPref(SenderPrefRow r) => SenderPref(
        senderKey: r.senderKey,
        ignored: r.state == 'IGNORED',
        learnedAt: r.updatedAt,
        bankName: r.bankName,
        last4: r.last4,
        currency: r.currency,
      );

  SimpleSelectStatement<$UnrecognisedMessagesTable, UnrecognisedRow> _fresh() =>
      _db.select(_db.unrecognisedMessages)
        ..where((t) => t.status.equals(UnrecognisedStatus.fresh.key));

  @override
  Stream<List<UnrecognisedMessage>> watchFresh() => (_fresh()
        ..orderBy([
          (t) => OrderingTerm.desc(t.receivedAt),
          (t) => OrderingTerm.desc(t.id),
        ]))
      .watch()
      .map((rows) => [for (final r in rows) _toDomain(r)]);

  @override
  Stream<int> watchFreshCount() {
    final count = _db.unrecognisedMessages.id.count();
    final q = _db.selectOnly(_db.unrecognisedMessages)
      ..addColumns([count])
      ..where(
        _db.unrecognisedMessages.status.equals(UnrecognisedStatus.fresh.key),
      );
    return q.watchSingle().map((r) => r.read(count) ?? 0);
  }

  @override
  Future<UnrecognisedMessage?> byId(int id) async {
    final r = await (_db.select(_db.unrecognisedMessages)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _toDomain(r);
  }

  @override
  Future<int?> offer(NewUnrecognised m) => _db.transaction(() async {
        final key = SenderKey.of(m.source, m.sender);
        final p = await pref(key);
        if (p != null && p.ignored) return null;
        final hash = _hash(m.body);
        final existing = await (_db.select(_db.unrecognisedMessages)
              ..where((t) => t.senderKey.equals(key) & t.bodyHash.equals(hash)))
            .getSingleOrNull();
        final now = _now();
        if (existing == null) {
          return await _db.into(_db.unrecognisedMessages).insert(
                UnrecognisedMessagesCompanion.insert(
                  source: m.source.key,
                  sender: m.sender,
                  senderKey: key,
                  sourceMessageId: m.sourceMessageId,
                  bodyHash: hash,
                  body: m.body,
                  receivedAt: m.receivedAt,
                  status: UnrecognisedStatus.fresh.key,
                  createdAt: now,
                ),
              );
        }
        if (existing.sourceMessageId == m.sourceMessageId) return null;
        if (existing.status == UnrecognisedStatus.fresh.key) return null;
        if ((existing.receivedAt - m.receivedAt).abs() < redeliveryMs) {
          return null;
        }
        // The same words again, later: another payment. Revive the row.
        await (_db.update(_db.unrecognisedMessages)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          UnrecognisedMessagesCompanion(
            sourceMessageId: Value(m.sourceMessageId),
            body: Value(m.body),
            receivedAt: Value(m.receivedAt),
            status: Value(UnrecognisedStatus.fresh.key),
            transactionId: const Value(null),
            handledAt: const Value(null),
          ),
        );
        return existing.id;
      });

  Future<void> _setStatus(
    int id,
    UnrecognisedStatus status, {
    int? transactionId,
  }) =>
      (_db.update(_db.unrecognisedMessages)..where((t) => t.id.equals(id)))
          .write(
        UnrecognisedMessagesCompanion(
          status: Value(status.key),
          transactionId: Value(transactionId),
          handledAt: Value(status == UnrecognisedStatus.fresh ? null : _now()),
        ),
      );

  @override
  Future<void> markAdded(int id, {int? transactionId}) =>
      _setStatus(id, UnrecognisedStatus.added, transactionId: transactionId);

  @override
  Future<void> dismiss(int id) => _setStatus(id, UnrecognisedStatus.dismissed);

  @override
  Future<void> restore(int id) async {
    final r = await byId(id);
    // Only while the text is still there; an emptied row is a tombstone.
    if (r == null || r.body.isEmpty) return;
    await _setStatus(id, UnrecognisedStatus.fresh);
  }

  @override
  Future<int> ignoreSender(String senderKey) => _db.transaction(() async {
        await _putPref(senderKey, 'IGNORED');
        return await (_db.update(_db.unrecognisedMessages)
              ..where(
                (t) =>
                    t.senderKey.equals(senderKey) &
                    t.status.equals(UnrecognisedStatus.fresh.key),
              ))
            .write(
          UnrecognisedMessagesCompanion(
            status: Value(UnrecognisedStatus.ignored.key),
            handledAt: Value(_now()),
          ),
        );
      });

  Future<void> _putPref(
    String key,
    String state, {
    String? bankName,
    String? last4,
    String? currency,
  }) =>
      _db.into(_db.senderPrefs).insertOnConflictUpdate(
            SenderPrefsCompanion.insert(
              senderKey: key,
              state: state,
              bankName: Value(bankName),
              last4: Value(last4),
              currency: Value(currency),
              updatedAt: _now(),
            ),
          );

  @override
  Future<void> learn(
    String senderKey, {
    String? bankName,
    String? last4,
    String? currency,
  }) =>
      _putPref(
        senderKey,
        'LEARNED',
        bankName: bankName,
        last4: last4,
        currency: currency,
      );

  @override
  Future<void> forget(String senderKey) =>
      (_db.delete(_db.senderPrefs)..where((t) => t.senderKey.equals(senderKey)))
          .go();

  @override
  Future<SenderPref?> pref(String senderKey) async {
    final r = await (_db.select(_db.senderPrefs)
          ..where((t) => t.senderKey.equals(senderKey)))
        .getSingleOrNull();
    return r == null ? null : _toPref(r);
  }

  @override
  Stream<List<SenderPref>> watchPrefs() => (_db.select(_db.senderPrefs)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch()
      .map((rows) => [for (final r in rows) _toPref(r)]);

  @override
  Future<int> purge() => _db.transaction(() async {
        final now = _now();
        final cutoff = now - retentionMs;
        var changed = 0;
        // Waiting too long: expire and drop the text.
        changed += await (_db.update(_db.unrecognisedMessages)
              ..where(
                (t) =>
                    t.status.equals(UnrecognisedStatus.fresh.key) &
                    t.createdAt.isSmallerThanValue(cutoff),
              ))
            .write(
          UnrecognisedMessagesCompanion(
            status: Value(UnrecognisedStatus.expired.key),
            body: const Value(''),
            handledAt: Value(now),
          ),
        );
        // Handled long ago: drop the text, keep the tombstone.
        changed += await (_db.update(_db.unrecognisedMessages)
              ..where(
                (t) =>
                    t.status.equals(UnrecognisedStatus.fresh.key).not() &
                    t.body.equals('').not() &
                    t.handledAt.isSmallerThanValue(cutoff),
              ))
            .write(const UnrecognisedMessagesCompanion(body: Value('')));
        // Tombstones nobody can match any more.
        await (_db.delete(_db.unrecognisedMessages)
              ..where(
                (t) =>
                    t.body.equals('') &
                    t.handledAt.isSmallerThanValue(now - tombstoneMs),
              ))
            .go();
        return changed;
      });
}
