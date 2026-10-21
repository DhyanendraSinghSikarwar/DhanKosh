import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/alerts_reminders/domain/alerted_key_store.dart';
import 'package:hisaab/features/alerts_reminders/domain/balance_notice_store.dart';
import 'package:hisaab/features/alerts_reminders/domain/card_reminder_state_store.dart';

/// [AlertedKeyStore] over `alerted_keys`.
class AlertedKeyStoreImpl implements AlertedKeyStore {
  /// Creates the store.
  AlertedKeyStoreImpl(this._db);

  final AppDatabase _db;

  @override
  Future<bool> has(String key) async =>
      await (_db.select(_db.alertedKeys)..where((t) => t.key.equals(key)))
          .getSingleOrNull() !=
      null;

  @override
  Future<Set<String>> all() async =>
      {for (final r in await _db.select(_db.alertedKeys).get()) r.key};

  @override
  Future<void> add(String key, int sentAtMs) => _db.transaction(() async {
        await _db.into(_db.alertedKeys).insertOnConflictUpdate(
              AlertedKeysCompanion.insert(key: key, sentAt: sentAtMs),
            );
        await _db.customUpdate(
          'DELETE FROM alerted_keys WHERE "key" NOT IN '
          '(SELECT "key" FROM alerted_keys ORDER BY sent_at DESC, rowid DESC '
          'LIMIT ${AlertedKeyStore.cap})',
          updates: {_db.alertedKeys},
          updateKind: UpdateKind.delete,
        );
      });

  @override
  Future<void> clear() => _db.delete(_db.alertedKeys).go();
}

/// [CardReminderStateStore] over `card_due_reminder_state`.
class CardReminderStateStoreImpl implements CardReminderStateStore {
  /// Creates the store.
  CardReminderStateStoreImpl(this._db);

  final AppDatabase _db;

  static CardReminderRecord _map(CardDueReminderRow r) => CardReminderRecord(
        cardId: r.cardId,
        dueEpochDay: r.dueEpochDay,
        stagesSent: r.stagesSent.isEmpty ? {} : r.stagesSent.split(',').toSet(),
        paid: r.paid,
        snoozedUntilEpochDay: r.snoozedUntilEpochDay,
      );

  @override
  Future<CardReminderRecord?> read(int cardId, int dueEpochDay) async {
    final r = await (_db.select(_db.cardDueReminderState)
          ..where(
            (t) => t.cardId.equals(cardId) & t.dueEpochDay.equals(dueEpochDay),
          ))
        .getSingleOrNull();
    return r == null ? null : _map(r);
  }

  Future<void> _prune(int todayEpochDay) =>
      (_db.delete(_db.cardDueReminderState)
            ..where(
              (t) => t.dueEpochDay.isSmallerThanValue(
                todayEpochDay - CardReminderStateStore.pruneDays,
              ),
            ))
          .go();

  @override
  Future<void> save(CardReminderRecord r, {required int todayEpochDay}) =>
      _db.transaction(() async {
        final names = r.stagesSent.toList()..sort();
        await _db.into(_db.cardDueReminderState).insertOnConflictUpdate(
              CardDueReminderStateCompanion.insert(
                cardId: r.cardId,
                dueEpochDay: r.dueEpochDay,
                stagesSent: Value(names.join(',')),
                paid: Value(r.paid),
                snoozedUntilEpochDay: Value(r.snoozedUntilEpochDay),
              ),
            );
        await _prune(todayEpochDay);
      });

  Future<CardReminderRecord> _cur(int c, int d) async =>
      await read(c, d) ?? CardReminderRecord(cardId: c, dueEpochDay: d);

  @override
  Future<void> markSent(
    int cardId,
    int dueEpochDay,
    String stage, {
    required int todayEpochDay,
  }) async {
    final c = await _cur(cardId, dueEpochDay);
    await save(
      CardReminderRecord(
        cardId: cardId,
        dueEpochDay: dueEpochDay,
        stagesSent: {...c.stagesSent, stage},
        paid: c.paid,
        snoozedUntilEpochDay: c.snoozedUntilEpochDay,
      ),
      todayEpochDay: todayEpochDay,
    );
  }

  @override
  Future<void> markPaid(
    int cardId,
    int dueEpochDay, {
    required int todayEpochDay,
  }) async {
    final c = await _cur(cardId, dueEpochDay);
    await save(
      CardReminderRecord(
        cardId: cardId,
        dueEpochDay: dueEpochDay,
        stagesSent: c.stagesSent,
        paid: true,
        snoozedUntilEpochDay: c.snoozedUntilEpochDay,
      ),
      todayEpochDay: todayEpochDay,
    );
  }

  @override
  Future<void> snooze(
    int cardId,
    int dueEpochDay,
    int untilEpochDay, {
    required int todayEpochDay,
  }) async {
    final c = await _cur(cardId, dueEpochDay);
    await save(
      CardReminderRecord(
        cardId: cardId,
        dueEpochDay: dueEpochDay,
        stagesSent: c.stagesSent,
        paid: c.paid,
        snoozedUntilEpochDay: untilEpochDay,
      ),
      todayEpochDay: todayEpochDay,
    );
  }
}

/// [BalanceNoticeStore] over `balance_notice_days`.
class BalanceNoticeStoreImpl implements BalanceNoticeStore {
  /// Creates the store.
  BalanceNoticeStoreImpl(this._db);

  final AppDatabase _db;

  @override
  Future<int?> lastDay(String accountKey) async =>
      (await (_db.select(_db.balanceNoticeDays)
                ..where((t) => t.accountKey.equals(accountKey)))
              .getSingleOrNull())
          ?.lastEpochDay;

  @override
  Future<bool> shouldNotify(String accountKey, int epochDay) async {
    final d = await lastDay(accountKey);
    return d == null || d < epochDay;
  }

  @override
  Future<void> record(String accountKey, int epochDay) =>
      _db.into(_db.balanceNoticeDays).insertOnConflictUpdate(
            BalanceNoticeDaysCompanion.insert(
              accountKey: accountKey,
              lastEpochDay: epochDay,
            ),
          );
}
