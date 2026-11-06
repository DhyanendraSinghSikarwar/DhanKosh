import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/statement_import/domain/column_layout_store.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/statement_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart' as pc;

/// Why a spreadsheet could not be opened for mapping.
class SheetOpenException implements Exception {
  /// Creates the exception.
  const SheetOpenException(this.reason);

  /// What is wrong with the file.
  final UnsupportedReason reason;
}

/// The result of importing a spreadsheet through a column mapping and
/// checking it against the account (FR-05-28, FR-05-29).
class MappedImportResult {
  /// Creates a result.
  const MappedImportResult({
    required this.statementId,
    required this.added,
    required this.merged,
    required this.review,
    required this.skipped,
    required this.droppedIsolated,
    this.accountId,
    this.comparison,
    this.addsUp = false,
  });

  /// The stored statement row.
  final int statementId;

  /// Rows that became new transactions.
  final int added;

  /// Rows merged into transactions that already existed.
  final int merged;

  /// Rows sent to review.
  final int review;

  /// Rows with no readable date or amount.
  final int skipped;

  /// Rows dropped as misread dates.
  final int droppedIsolated;

  /// The account the rows were filed under.
  final int? accountId;

  /// Statement balance against the app's; null when there was no account, no
  /// balance column or the account is a card.
  final pc.BalanceComparison? comparison;

  /// The statement's running balances add up, so it can be offered as the
  /// account's balance.
  final bool addsUp;

  /// The difference can be fixed by taking the statement's figure.
  bool get canSetBalance =>
      accountId != null &&
      addsUp &&
      comparison != null &&
      comparison!.differenceMinor != 0;
}

/// Reads a CSV or XLSX statement through a column mapping the user checked,
/// files its rows under the chosen account through the single ledger write
/// path, and compares the closing balance with the app's (FR-05-28,
/// FR-05-29).
class ImportMappedSheet {
  /// Creates the use case.
  ImportMappedSheet({
    required SheetReader sheets,
    required StatementRepository statements,
    required StatementFileStore files,
    required TransactionRepository ledger,
    required AccountRepository accounts,
    required ColumnLayoutStore layouts,
    int Function()? clock,
  })  : _sheets = sheets,
        _statements = statements,
        _files = files,
        _ledger = ledger,
        _accounts = accounts,
        _layouts = layouts,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SheetReader _sheets;
  final StatementRepository _statements;
  final StatementFileStore _files;
  final TransactionRepository _ledger;
  final AccountRepository _accounts;
  final ColumnLayoutStore _layouts;
  final int Function() _clock;

  static const _ist = Duration(hours: 5, minutes: 30);

  /// The sheets of [file]. Throws [SheetOpenException].
  List<SheetData> read(PickedFile file) {
    if (file.bytes.length > maxStatementBytes) {
      throw const SheetOpenException(UnsupportedReason.tooLarge);
    }
    switch (sniffStatement(file.bytes, file.name)) {
      case StatementFileType.csv:
        final rows = pc.SpreadsheetLines.parseCsv(
          utf8.decode(file.bytes, allowMalformed: true),
        );
        if (rows.length > SheetLimits.maxRows) {
          throw const SheetOpenException(UnsupportedReason.tooLarge);
        }
        return [
          SheetData(file.name, [
            for (final r in rows) r.take(SheetLimits.maxColumns).toList(),
          ]),
        ];
      case StatementFileType.xlsx:
        try {
          return _sheets.xlsxSheets(file.bytes);
        } on SheetTooLargeException {
          throw const SheetOpenException(UnsupportedReason.tooLarge);
        } on FormatException {
          throw const SheetOpenException(UnsupportedReason.unreadable);
        }
      case StatementFileType.xls:
        throw const SheetOpenException(UnsupportedReason.xls);
      case StatementFileType.protectedSheet:
        throw const SheetOpenException(UnsupportedReason.protectedSheet);
      case StatementFileType.pdf:
      case StatementFileType.unknown:
        throw const SheetOpenException(UnsupportedReason.unknownType);
    }
  }

  /// A saved mapping for the header of [rows] at [headerRow], if the user
  /// confirmed one for this layout before.
  Future<pc.ColumnMapping?> savedFor(List<List<String>> rows, int headerRow) {
    if (headerRow < 0 || headerRow >= rows.length) return Future.value();
    return _layouts.find(pc.StatementTable.signature(rows[headerRow]));
  }

  /// Forgets every saved layout.
  Future<void> forgetLayouts() => _layouts.clear();

  /// End of [epochDay] in India, epoch ms.
  static int endOfDay(int epochDay) =>
      (epochDay + 1) * Duration.millisecondsPerDay - 1 - _ist.inMilliseconds;

  /// Files the rows of [rows] read through [mapping] under [accountId] and
  /// checks the balance.
  Future<MappedImportResult> commit({
    required PickedFile file,
    required List<List<String>> rows,
    required pc.ColumnMapping mapping,
    int? accountId,
  }) async {
    final parsed = pc.StatementTable.parse(rows, mapping);
    final now = _clock();
    final account = accountId == null ? null : await _accounts.byId(accountId);
    final bank = account?.bankName ?? 'Statement';
    final tx = pc.StatementTable.toTransactions(
      parsed.rows,
      bankName: bank,
      last4: account?.last4,
      accountKind: account?.kind ?? pc.AccountKind.account,
      stampedAt: now,
    );

    final digest = sha256.convert(file.bytes).toString();
    final key = 'file:$digest';
    final items = <IngestItem>[
      for (var i = 0; i < tx.length; i++)
        IngestItem(
          parsed: tx[i],
          sourceMessageId: 'stmt:$key:map$i',
          rawText: parsed.rows[i].description,
          accountId: accountId,
        ),
    ];
    final report = items.isEmpty
        ? const IngestReport([])
        : await _ledger.ingestBatch(items);

    final closing = pc.StatementBalanceCheck.closing(parsed);
    final totals = StatementTotals(
      closingMinor: closing?.minor,
      statementEpochDay: closing?.epochDay,
    );
    final path =
        await _files.save('${digest.substring(0, 16)}.bin', file.bytes);
    final existing = await _statements.byKey(key);
    final int id;
    if (existing != null) {
      id = existing.id;
      await _statements.markProcessed(
        id,
        status: items.isEmpty ? StatementStatus.empty : StatementStatus.parsed,
        at: now,
        kind: StatementKind.bank,
        bankName: account?.bankName,
        last4: account?.last4,
        transactionCount: items.length,
        holdingCount: 0,
        totals: totals,
        filePath: path,
      );
    } else {
      final r = await _statements.insert(
        NewStatement(
          key: key,
          source: StatementSource.file,
          sender: file.name,
          fileName: file.name,
          receivedAt: now,
          processedAt: now,
          status:
              items.isEmpty ? StatementStatus.empty : StatementStatus.parsed,
          filePath: path,
          bankName: account?.bankName,
          last4: account?.last4,
          kind: StatementKind.bank,
          transactionCount: items.length,
          totals: totals,
        ),
      );
      id = switch (r) {
        StatementInserted(:final statement) ||
        StatementAlreadyImported(:final statement) ||
        StatementRetryLocked(:final statement) =>
          statement.id,
      };
    }
    if (parsed.rows.isNotEmpty) {
      await _layouts.save(
        pc.StatementTable.signature(rows[mapping.headerRow]),
        mapping,
      );
    }

    pc.BalanceComparison? comparison;
    if (accountId != null &&
        closing != null &&
        account?.kind == pc.AccountKind.account) {
      final app =
          await _accounts.balanceAsOf(accountId, endOfDay(closing.epochDay));
      comparison = pc.StatementBalanceCheck.compare(closing, app);
    }
    return MappedImportResult(
      statementId: id,
      added: report.inserted,
      merged: report.merged,
      review: report.flagged,
      skipped: parsed.skipped,
      droppedIsolated: parsed.droppedIsolated,
      accountId: accountId,
      comparison: comparison,
      addsUp: pc.StatementBalanceCheck.trustworthy(parsed),
    );
  }

  /// Takes the statement's balance as the account's, dated the end of the
  /// statement's last day. Returns false, changing nothing, when the account
  /// already has a newer figure: a newer bank balance is never overwritten.
  Future<bool> useStatementBalance(
    int accountId,
    pc.BalanceComparison comparison,
  ) async {
    final account = await _accounts.byId(accountId);
    if (account == null) return false;
    final at = endOfDay(comparison.asOfEpochDay);
    final reportedAt = account.balanceUpdatedAt;
    final typedAt = account.manualBalanceAt;
    if ((reportedAt != null && reportedAt > at) ||
        (typedAt != null && typedAt > at)) {
      return false;
    }
    await _accounts.updateBalance(
      accountId,
      at: at,
      balanceMinor: comparison.statementMinor,
    );
    return true;
  }
}
