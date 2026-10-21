import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_repository.dart';

/// [StatementRepository] over the `statements` table (FR-05-01, FR-05-11).
class StatementRepositoryImpl implements StatementRepository {
  /// Creates the repository.
  StatementRepositoryImpl(this._db);

  final AppDatabase _db;

  static Statement _map(StatementRow r) => Statement(
        id: r.id,
        key: r.key,
        source:
            enumFromDb(StatementSource.values, r.source, StatementSource.file),
        sender: r.sender,
        subject: r.subject,
        fileName: r.fileName,
        receivedAt: r.receivedAt,
        status: enumFromDb(
          StatementStatus.values,
          r.status,
          StatementStatus.unreadable,
        ),
        processedAt: r.processedAt,
        transactionCount: r.transactionCount,
        holdingCount: r.holdingCount,
        filePath: r.filePath,
        bankName: r.bankName,
        last4: r.last4,
        kind: enumFromDbOrNull(StatementKind.values, r.kind),
        emailText: r.emailText,
        totals: StatementTotals(
          totalDueMinor: r.totalDueMinor,
          minDueMinor: r.minDueMinor,
          dueEpochDay: r.dueEpochDay,
          creditLimitMinor: r.creditLimitMinor,
          statementEpochDay: r.statementEpochDay,
          openingMinor: r.openingMinor,
          closingMinor: r.closingMinor,
          debitsMinor: r.debitsMinor,
          creditsMinor: r.creditsMinor,
          availableMinor: r.availableMinor,
        ),
      );

  static String? _cap(String? s) =>
      s != null && s.length > emailTextCap ? s.substring(0, emailTextCap) : s;

  SimpleSelectStatement<$StatementsTable, StatementRow> _byKey(String key) =>
      _db.select(_db.statements)..where((t) => t.key.equals(key));

  @override
  Future<StatementInsert> insert(NewStatement s) =>
      _db.transaction<StatementInsert>(() async {
        final existing = await _byKey(s.key).getSingleOrNull();
        if (existing != null) {
          final st = _map(existing);
          return st.isLocked
              ? StatementRetryLocked(st)
              : StatementAlreadyImported(st);
        }
        final t = s.totals;
        final id = await _db.into(_db.statements).insert(
              StatementsCompanion.insert(
                key: s.key,
                source: enumToDb(s.source),
                sender: s.sender,
                subject: Value(s.subject),
                fileName: s.fileName,
                receivedAt: s.receivedAt,
                status: enumToDb(s.status),
                transactionCount: Value(s.transactionCount),
                holdingCount: Value(s.holdingCount),
                filePath: Value(s.filePath),
                bankName: Value(s.bankName),
                last4: Value(s.last4),
                processedAt: s.processedAt,
                kind: Value(s.kind == null ? null : enumToDb(s.kind!)),
                totalDueMinor: Value(t.totalDueMinor),
                minDueMinor: Value(t.minDueMinor),
                dueEpochDay: Value(t.dueEpochDay),
                creditLimitMinor: Value(t.creditLimitMinor),
                statementEpochDay: Value(t.statementEpochDay),
                openingMinor: Value(t.openingMinor),
                closingMinor: Value(t.closingMinor),
                debitsMinor: Value(t.debitsMinor),
                creditsMinor: Value(t.creditsMinor),
                availableMinor: Value(t.availableMinor),
                emailText: Value(_cap(s.emailText)),
              ),
            );
        return StatementInserted((await byId(id))!);
      });

  @override
  Future<bool> exists(String key) async =>
      await _byKey(key).getSingleOrNull() != null;

  @override
  Future<Statement?> byKey(String key) async {
    final r = await _byKey(key).getSingleOrNull();
    return r == null ? null : _map(r);
  }

  @override
  Future<Statement?> byId(int id) async {
    final r = await (_db.select(_db.statements)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return r == null ? null : _map(r);
  }

  @override
  Stream<List<Statement>> watchAll() => (_db.select(_db.statements)
        ..orderBy([
          (t) => OrderingTerm.desc(t.receivedAt),
          (t) => OrderingTerm.desc(t.id),
        ]))
      .watch()
      .map((rows) => rows.map(_map).toList());

  SimpleSelectStatement<$StatementsTable, StatementRow> get _lockedQuery =>
      _db.select(_db.statements)
        ..where((t) => t.status.equals(enumToDb(StatementStatus.locked)))
        ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]);

  @override
  Future<List<Statement>> locked() async =>
      (await _lockedQuery.get()).map(_map).toList();

  @override
  Stream<int> watchLockedCount() =>
      _lockedQuery.watch().map((rows) => rows.length).distinct();

  @override
  Future<void> markProcessed(
    int id, {
    required StatementStatus status,
    required int at,
    StatementKind? kind,
    String? bankName,
    String? last4,
    int? transactionCount,
    int? holdingCount,
    StatementTotals? totals,
    String? filePath,
  }) async {
    final t = totals;
    await (_db.update(_db.statements)..where((x) => x.id.equals(id))).write(
      StatementsCompanion(
        status: Value(enumToDb(status)),
        processedAt: Value(at),
        kind: kind == null ? const Value.absent() : Value(enumToDb(kind)),
        bankName: Value.absentIfNull(bankName),
        last4: Value.absentIfNull(last4),
        transactionCount: Value.absentIfNull(transactionCount),
        holdingCount: Value.absentIfNull(holdingCount),
        filePath: Value.absentIfNull(filePath),
        totalDueMinor: Value.absentIfNull(t?.totalDueMinor),
        minDueMinor: Value.absentIfNull(t?.minDueMinor),
        dueEpochDay: Value.absentIfNull(t?.dueEpochDay),
        creditLimitMinor: Value.absentIfNull(t?.creditLimitMinor),
        statementEpochDay: Value.absentIfNull(t?.statementEpochDay),
        openingMinor: Value.absentIfNull(t?.openingMinor),
        closingMinor: Value.absentIfNull(t?.closingMinor),
        debitsMinor: Value.absentIfNull(t?.debitsMinor),
        creditsMinor: Value.absentIfNull(t?.creditsMinor),
        availableMinor: Value.absentIfNull(t?.availableMinor),
      ),
    );
  }

  @override
  Future<void> markLocked(int id, {required int at, String? emailText}) async {
    await (_db.update(_db.statements)..where((x) => x.id.equals(id))).write(
      StatementsCompanion(
        status: Value(enumToDb(StatementStatus.locked)),
        processedAt: Value(at),
        emailText: Value.absentIfNull(_cap(emailText)),
      ),
    );
  }

  @override
  Future<String?> delete(int id) async {
    final row = await byId(id);
    await (_db.delete(_db.statements)..where((t) => t.id.equals(id))).go();
    return row?.filePath;
  }
}
