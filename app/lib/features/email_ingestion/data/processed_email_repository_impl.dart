import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';

/// [ProcessedEmailRepository] over the `processed_emails` table.
class ProcessedEmailRepositoryImpl implements ProcessedEmailRepository {
  /// Creates the repository.
  ProcessedEmailRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<Set<String>> processed(Iterable<String> ids) async {
    final list = ids.toList();
    final out = <String>{};
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, (i + 500).clamp(0, list.length));
      final rows = await (_db.select(_db.processedEmails)
            ..where((t) => t.messageId.isIn(chunk)))
          .get();
      out.addAll(rows.map((r) => r.messageId));
    }
    return out;
  }

  @override
  Future<void> mark(String id, String outcome, {required int at}) =>
      _db.into(_db.processedEmails).insertOnConflictUpdate(
            ProcessedEmailsCompanion.insert(
              messageId: id,
              processedAt: at,
              outcome: outcome,
            ),
          );
}
