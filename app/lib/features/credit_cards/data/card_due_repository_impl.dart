import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/domain/card_notice_keys.dart';

/// [CardDueRepository] over `card_due_notices` and `card_overrides`.
class CardDueRepositoryImpl implements CardDueRepository {
  /// Creates the repository.
  CardDueRepositoryImpl(this._db);

  final AppDatabase _db;

  static CardRow _row(CardDueNoticeRow r) => CardRow(
        source: enumFromDb(CardDueSource.values, r.source, CardDueSource.sms),
        isPayment: r.kind == 'PAYMENT',
        bankName: r.bankName,
        last4: r.last4,
        receivedAt: r.receivedAt,
        processedAt: r.processedAt,
        totalDueMinor: r.totalDueMinor,
        minDueMinor: r.minDueMinor,
        dueEpochDay: r.dueEpochDay,
        creditLimitMinor: r.creditLimitMinor,
        statementEpochDay: r.statementEpochDay,
        availableMinor: r.availableMinor,
        paymentMinor: r.paymentMinor,
      );

  static CardOverride _override(CardOverrideRow r) => CardOverride(
        cardKey: r.cardKey,
        setAt: r.setAt,
        billedMinor: r.billedMinor,
        minDueMinor: r.minDueMinor,
        dueEpochDay: r.dueEpochDay,
        unbilledMinor: r.unbilledMinor,
        outstandingMinor: r.outstandingMinor,
      );

  static String _key(NewCardNotice n) {
    final day = n.statementEpochDay ?? n.dueEpochDay ?? 0;
    return n.isPayment
        ? CardNoticeKeys.payment(
            bank: n.bankName,
            last4: n.last4,
            day: day,
            amountMinor: n.paymentMinor ?? 0,
          )
        : CardNoticeKeys.due(
            bank: n.bankName,
            last4: n.last4,
            totalMinor: n.totalDueMinor,
            day: day,
          );
  }

  @override
  Future<bool> recordNotice(NewCardNotice n) => _db.transaction(() async {
        final key = _key(n);
        final existing = await (_db.select(_db.cardDueNotices)
              ..where((t) => t.key.equals(key)))
            .getSingleOrNull();
        if (existing != null &&
            (n.isPayment ||
                existing.totalDueMinor != null ||
                n.totalDueMinor == null)) {
          return false;
        }
        final c = CardDueNoticesCompanion.insert(
          key: key,
          kind: n.isPayment ? 'PAYMENT' : 'DUE',
          source: enumToDb(n.source),
          bankName: Value(n.bankName),
          last4: Value(n.last4),
          totalDueMinor: Value(n.totalDueMinor),
          minDueMinor: Value(n.minDueMinor),
          dueEpochDay: Value(n.dueEpochDay),
          creditLimitMinor: Value(n.creditLimitMinor),
          statementEpochDay: Value(n.statementEpochDay),
          availableMinor: Value(n.availableMinor),
          paymentMinor: Value(n.paymentMinor),
          receivedAt: n.receivedAt,
          processedAt: n.processedAt,
        );
        await _db.into(_db.cardDueNotices).insertOnConflictUpdate(
              existing == null ? c : c.copyWith(id: Value(existing.id)),
            );
        return true;
      });

  @override
  Future<List<CardRow>> notices() async =>
      (await _db.select(_db.cardDueNotices).get()).map(_row).toList();

  @override
  Stream<List<CardRow>> watchNotices() => _db
      .select(_db.cardDueNotices)
      .watch()
      .map((rows) => rows.map(_row).toList());

  @override
  Future<CardOverride?> overrideFor(String cardKey) async {
    final r = await (_db.select(_db.cardOverrides)
          ..where((t) => t.cardKey.equals(cardKey)))
        .getSingleOrNull();
    return r == null ? null : _override(r);
  }

  @override
  Stream<Map<String, CardOverride>> watchOverrides() =>
      _db.select(_db.cardOverrides).watch().map(
            (rows) => {for (final r in rows) r.cardKey: _override(r)},
          );

  @override
  Future<void> saveOverride(CardOverride o) =>
      _db.into(_db.cardOverrides).insertOnConflictUpdate(
            CardOverridesCompanion.insert(
              cardKey: o.cardKey,
              setAt: o.setAt,
              billedMinor: Value(o.billedMinor),
              minDueMinor: Value(o.minDueMinor),
              dueEpochDay: Value(o.dueEpochDay),
              unbilledMinor: Value(o.unbilledMinor),
              outstandingMinor: Value(o.outstandingMinor),
            ),
          );

  @override
  Future<void> clearOverride(String cardKey) =>
      (_db.delete(_db.cardOverrides)..where((t) => t.cardKey.equals(cardKey)))
          .go();

  @override
  Future<int> pruneNotices(int beforeMs) => (_db.delete(_db.cardDueNotices)
        ..where((t) => t.receivedAt.isSmallerThanValue(beforeMs)))
      .go();
}
