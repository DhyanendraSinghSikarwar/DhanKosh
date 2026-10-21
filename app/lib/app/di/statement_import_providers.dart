import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/platform_channels/pdf_channel.dart';
import 'package:hisaab/features/statement_import/data/file_source_impl.dart';
import 'package:hisaab/features/statement_import/data/pdf_text_reader_impl.dart';
import 'package:hisaab/features/statement_import/data/sheet_reader_impl.dart';
import 'package:hisaab/features/statement_import/data/statement_file_store_impl.dart';
import 'package:hisaab/features/statement_import/domain/password_source.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_statement.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'statement_import_providers.g.dart';

/// System document picker (F-05).
@Riverpod(keepAlive: true)
FileSource statementFileSource(Ref ref) => const FileSourceImpl();

/// Statement import use case (F-05).
@Riverpod(keepAlive: true)
ImportStatement importStatement(Ref ref) => ImportStatement(
      statements: ref.watch(statementRepositoryProvider),
      savedPasswords: ref.watch(savedPasswordRepositoryProvider),
      pdf: const PdfTextReaderImpl(PdfChannel()),
      sheets: const SheetReaderImpl(),
      files: const StatementFileStoreImpl(),
      ledger: ref.watch(transactionRepositoryProvider),
      holdings: ref.watch(holdingRepositoryProvider),
      cardDues: ref.watch(cardDueRepositoryProvider),
      passwordSource: () async => assemblePasswordSource(
        identity: await ref.read(identityRepositoryProvider).read(),
        profile: await ref.read(profileRepositoryProvider).read(),
        cardLast4s: [
          for (final a
              in await ref.read(accountRepositoryProvider).watchVisible().first)
            a.last4,
        ],
        banks: await ref.read(bankIdentityRepositoryProvider).readAll(),
        saved: [
          for (final s
              in await ref.read(savedPasswordRepositoryProvider).list())
            s.secret,
        ],
      ),
    );

/// Stored statements, newest first (F-05).
@riverpod
Stream<List<Statement>> statements(Ref ref) =>
    ref.watch(statementRepositoryProvider).watchAll();

/// Number of LOCKED statements (F-05).
@riverpod
Stream<int> lockedStatementCount(Ref ref) =>
    ref.watch(statementRepositoryProvider).watchLockedCount();
