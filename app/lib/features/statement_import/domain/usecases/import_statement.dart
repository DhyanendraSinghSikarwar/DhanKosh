import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart' as pf;
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/password_candidates.dart';
import 'package:hisaab/features/statement_import/domain/password_source.dart';
import 'package:hisaab/features/statement_import/domain/saved_password.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_outcome.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/statement_repository.dart';
import 'package:hisaab/features/statement_import/domain/usecases/apply_statement_accounts.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';
import 'package:parser_core/parser_core.dart' as pc;

StatementKind _kind(pc.StatementKind k) => switch (k) {
      pc.StatementKind.creditCard => StatementKind.creditCard,
      pc.StatementKind.bank => StatementKind.bank,
      pc.StatementKind.investment => StatementKind.investment,
      pc.StatementKind.other => StatementKind.other,
    };

/// Top level so a worker isolate can run it (memory 05 section 6).
pc.StatementResult _parseOnWorker((String, String, int) a) =>
    pc.parseStatement(a.$1, a.$2, a.$3);

/// Reads one statement file and applies it: sniff, open (no password, derived,
/// saved), parse, ingest rows through the ledger, record holdings and card
/// bill figures, store the statement row (FR-05-01..15).
///
/// Never writes `transactions` itself; rows go through
/// [TransactionRepository.ingestBatch] with ids `stmt:<key>:<i>` (FR-05-04).
class ImportStatement {
  /// Creates the use case.
  ImportStatement({
    required StatementRepository statements,
    required SavedPasswordRepository savedPasswords,
    required PdfTextReader pdf,
    required SheetReader sheets,
    required StatementFileStore files,
    required TransactionRepository ledger,
    required HoldingRepository holdings,
    required CardDueRepository cardDues,
    required Future<PasswordSource> Function() passwordSource,
    ApplyStatementAccounts? accounts,
    StatementOutcomeStore? outcomes,
    StatementLockedNotifier? lockedNotifier,
    int Function()? clock,
  })  : _statements = statements,
        _saved = savedPasswords,
        _pdf = pdf,
        _sheets = sheets,
        _files = files,
        _ledger = ledger,
        _holdings = holdings,
        _cardDues = cardDues,
        _source = passwordSource,
        _accounts = accounts,
        _outcomes = outcomes,
        _notifier = lockedNotifier,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final StatementRepository _statements;
  final SavedPasswordRepository _saved;
  final PdfTextReader _pdf;
  final SheetReader _sheets;
  final StatementFileStore _files;
  final TransactionRepository _ledger;
  final HoldingRepository _holdings;
  final CardDueRepository _cardDues;
  final Future<PasswordSource> Function() _source;
  final ApplyStatementAccounts? _accounts;
  final StatementOutcomeStore? _outcomes;
  final StatementLockedNotifier? _notifier;
  final int Function() _clock;

  /// Imports [file] picked by the user (FR-05-01). An already imported file
  /// answers [ImportAlreadyDone] unless its row is LOCKED, which is retried.
  Future<ImportResult> call(PickedFile file) => _import(file, null);

  /// Imports a statement attached to an email (FR-05-16, FR-03-16). The row
  /// key is `email:<messageId>#<index>`, so a re-sync never imports it twice.
  Future<ImportResult> importEmailAttachment(
    PickedFile file,
    EmailOrigin origin,
  ) =>
      _import(file, origin);

  Future<ImportResult> _import(PickedFile file, EmailOrigin? origin) async {
    final r = await _importInner(file, origin);
    // FR-35-22: outcome kind and counts only, never statement text.
    final f = <String, Object?>{
      'result': r.runtimeType.toString(),
      'email': origin != null,
    };
    if (r is ImportDone) {
      f.addAll({
        'added': r.added,
        'merged': r.merged,
        'review': r.review,
        'holdings': r.holdings,
        'empty': r.empty,
      });
    } else if (r is ImportUnsupported) {
      f['reason'] = r.reason.name;
    }
    AppLog.instance.info(LogCategory.statement, 'import.result', fields: f);
    return r;
  }

  Future<ImportResult> _importInner(
    PickedFile file,
    EmailOrigin? origin,
  ) async {
    if (file.bytes.length > maxStatementBytes) {
      return const ImportUnsupported(UnsupportedReason.tooLarge);
    }
    final type = sniffStatement(file.bytes, file.name);
    if (type == StatementFileType.xls) {
      return const ImportUnsupported(UnsupportedReason.xls);
    }
    if (type == StatementFileType.unknown) {
      return const ImportUnsupported(UnsupportedReason.unknownType);
    }
    final digest = sha256.convert(file.bytes).toString();
    final key = origin?.key ?? 'file:$digest';
    final existing = await _statements.byKey(key);
    if (existing != null && !existing.isLocked) {
      return ImportAlreadyDone(existing.id);
    }
    if (type == StatementFileType.protectedSheet) {
      return await _unreadable(
        existing,
        key,
        file,
        kind: StatementKind.protected,
        reason: UnsupportedReason.protectedSheet,
        origin: origin,
      );
    }
    return await _run(
      file.bytes,
      file.name,
      key,
      digest.substring(0, 16),
      type,
      existing,
      origin: origin,
    );
  }

  /// Retries a LOCKED statement with [password] (FR-05-12). On success the
  /// password is remembered when [remember] and other locked statements are
  /// retried.
  Future<ImportResult> unlock(
    int id,
    String password, {
    bool remember = false,
    String? label,
  }) async {
    final row = await _statements.byId(id);
    final path = row?.filePath;
    if (row == null || path == null) return const ImportFileMissing();
    final bytes = await _files.read(path);
    if (bytes == null) return const ImportFileMissing();
    final r = await _run(
      bytes,
      row.fileName,
      row.key,
      null,
      sniffStatement(bytes, row.fileName),
      row,
      explicit: password,
    );
    if (r is ImportDone) {
      if (remember) {
        await _saved.add(
          SavedPassword(
            label: label ?? row.bankName ?? row.fileName,
            secret: password,
          ),
        );
      }
      await retryLocked();
    }
    return r;
  }

  /// Retries every LOCKED statement with the current passwords (FR-05-13).
  /// Returns how many opened.
  Future<int> retryLocked() async {
    var opened = 0;
    for (final row in await _statements.locked()) {
      final path = row.filePath;
      final bytes = path == null ? null : await _files.read(path);
      if (bytes == null) continue;
      final r = await _run(
        bytes,
        row.fileName,
        row.key,
        null,
        sniffStatement(bytes, row.fileName),
        row,
      );
      if (r is ImportDone) opened++;
    }
    return opened;
  }

  /// Reads the stored file of statement [id] again (FR-05-20). Rows already
  /// in the ledger merge, so nothing is added twice.
  Future<ImportResult> readAgain(int id) async {
    final row = await _statements.byId(id);
    final path = row?.filePath;
    if (row == null || path == null) return const ImportFileMissing();
    final bytes = await _files.read(path);
    if (bytes == null) return const ImportFileMissing();
    return await _run(
      bytes,
      row.fileName,
      row.key,
      null,
      sniffStatement(bytes, row.fileName),
      row,
    );
  }

  /// Email body without a file: an INDmoney-style portfolio summary records
  /// its aggregate holdings (FR-05-16, FR-05-23 step 1). True when handled.
  Future<bool> readEmailBody({
    required String body,
    required String sender,
    required int receivedAt,
    String? subject,
  }) async {
    final snaps = [
      for (final h in pc.parsePortfolioSummary(
        body,
        subject,
        sender,
        receivedAt,
      ))
        if ((h.valueMinor ?? 0) > 0)
          pf.HoldingSnapshot(
            kind: HoldingKind.values.byName(h.kind.name),
            name: h.name,
            identifier: h.identifier,
            asOf: h.asOf,
            units: h.units,
            valueMinor: h.valueMinor,
            investedMinor: h.investedMinor,
            contributionMinor: h.contributionMinor,
            platform: h.platform,
          ),
    ];
    if (snaps.isEmpty) return false;
    await _holdings.record(snaps, HoldingSource.email);
    return true;
  }

  /// Deletes the row and its stored file (FR-05-19).
  Future<void> delete(int id) async {
    final path = await _statements.delete(id);
    if (path != null) await _files.delete(path);
    await _outcomes?.delete(id);
  }

  Future<ImportResult> _unreadable(
    Statement? existing,
    String key,
    PickedFile file, {
    required UnsupportedReason reason,
    StatementKind? kind,
    EmailOrigin? origin,
  }) async {
    final now = _clock();
    if (existing == null) {
      await _statements.insert(
        NewStatement(
          key: key,
          source: origin == null ? StatementSource.file : StatementSource.email,
          sender: origin?.sender ?? file.name,
          fileName: file.name,
          receivedAt: origin?.receivedAt ?? now,
          processedAt: now,
          status: StatementStatus.unreadable,
          subject: origin?.subject,
          kind: kind,
        ),
      );
    } else {
      await _statements.markProcessed(
        existing.id,
        status: StatementStatus.unreadable,
        at: now,
        kind: kind,
      );
    }
    return ImportUnsupported(reason);
  }

  Future<ImportResult> _run(
    Uint8List bytes,
    String name,
    String key,
    String? namePrefix,
    StatementFileType type,
    Statement? existing, {
    String? explicit,
    EmailOrigin? origin,
  }) async {
    final now = _clock();
    final file = PickedFile(name: name, bytes: bytes);
    if (type == StatementFileType.pdf) {
      final opened = await _openPdf(bytes, explicit);
      switch (opened) {
        case _Text(:final text):
          return await _apply(
            text,
            file,
            key,
            namePrefix,
            existing,
            now,
            origin,
          );
        case _Fail(:final failure):
          if (failure == PdfFailure.passwordRequired ||
              failure == PdfFailure.wrongPassword) {
            final id =
                await _lock(file, key, namePrefix, existing, now, origin);
            return explicit != null && failure == PdfFailure.wrongPassword
                ? ImportWrongPassword(id)
                : ImportLocked(id);
          }
          return await _unreadable(
            existing,
            key,
            file,
            reason: failure == PdfFailure.scanned
                ? UnsupportedReason.scanned
                : UnsupportedReason.unreadable,
            origin: origin,
          );
      }
    }
    final String text;
    try {
      final rows = type == StatementFileType.csv
          ? pc.SpreadsheetLines.parseCsv(
              utf8.decode(bytes, allowMalformed: true),
            )
          : _sheets.xlsxRows(bytes);
      text = pc.SpreadsheetLines.toText(rows);
    } on FormatException {
      return await _unreadable(
        existing,
        key,
        file,
        reason: UnsupportedReason.unreadable,
        origin: origin,
      );
    }
    return await _apply(text, file, key, namePrefix, existing, now, origin);
  }

  /// No password, then (explicit | derived then saved); first success wins.
  Future<_PdfOpen> _openPdf(Uint8List bytes, String? explicit) async {
    var last = PdfFailure.passwordRequired;
    Future<_PdfOpen?> attempt(String? pw) async {
      try {
        return _Text(await _pdf.extractText(bytes, password: pw));
      } on PdfReadException catch (e) {
        last = e.failure;
        return switch (e.failure) {
          PdfFailure.scanned || PdfFailure.unreadable => _Fail(e.failure),
          _ => null,
        };
      }
    }

    if (explicit != null) {
      return await attempt(explicit) ?? const _Fail(PdfFailure.wrongPassword);
    }
    final first = await attempt(null);
    if (first != null) return first;
    for (final pw in passwordCandidates(await _source())) {
      final r = await attempt(pw);
      if (r != null) return r;
    }
    return _Fail(
      last == PdfFailure.wrongPassword ? PdfFailure.passwordRequired : last,
    );
  }

  Future<int> _lock(
    PickedFile file,
    String key,
    String? namePrefix,
    Statement? existing,
    int now,
    EmailOrigin? origin,
  ) async {
    final path = existing?.filePath ??
        await _files.save('${namePrefix ?? _short(key)}.bin', file.bytes);
    if (existing != null) {
      await _statements.markLocked(existing.id, at: now);
      return existing.id;
    }
    final text = origin?.emailText;
    final r = await _statements.insert(
      NewStatement(
        key: key,
        source: origin == null ? StatementSource.file : StatementSource.email,
        sender: origin?.sender ?? file.name,
        fileName: file.name,
        receivedAt: origin?.receivedAt ?? now,
        processedAt: now,
        status: StatementStatus.locked,
        subject: origin?.subject,
        emailText: text == null
            ? null
            : (text.length > emailTextCap
                ? text.substring(0, emailTextCap)
                : text),
        filePath: path,
      ),
    );
    final id = switch (r) {
      StatementInserted(:final statement) ||
      StatementAlreadyImported(:final statement) ||
      StatementRetryLocked(:final statement) =>
        statement.id,
    };
    // FR-05-11: an emailed statement can arrive while the app is closed.
    if (origin != null) await _notifier?.notify(id);
    return id;
  }

  static String _short(String key) =>
      key.replaceAll(RegExp('[^A-Za-z0-9]'), '').padRight(16, '0').substring(
            0,
            16,
          );

  Future<ImportResult> _apply(
    String text,
    PickedFile file,
    String key,
    String? namePrefix,
    Statement? existing,
    int now,
    EmailOrigin? origin,
  ) async {
    final result = await Isolate.run(
      () => _parseOnWorker((text, file.name, now)),
    );
    final items = <IngestItem>[
      for (var i = 0; i < result.transactions.length; i++)
        IngestItem(
          parsed: result.transactions[i],
          sourceMessageId: 'stmt:$key:$i',
          rawText: i < result.lines.length ? result.lines[i] : null,
        ),
    ];
    final report = items.isEmpty
        ? const IngestReport([])
        : await _ledger.ingestBatch(items);
    final snaps = [
      for (final h in result.holdings)
        if ((h.valueMinor ?? 0) > 0)
          pf.HoldingSnapshot(
            kind: HoldingKind.values.byName(h.kind.name),
            name: h.name,
            identifier: h.identifier,
            asOf: h.asOf,
            units: h.units,
            valueMinor: h.valueMinor,
            investedMinor: h.investedMinor,
            contributionMinor: h.contributionMinor,
            platform: h.platform,
          ),
    ];
    final held = snaps.isEmpty
        ? 0
        : await _holdings.record(snaps, HoldingSource.statement);

    final s = result.summary;
    // FR-05-07: totals set the card limit or account balance, no transaction.
    final effect = await _accounts?.applyTotals(result, receivedAt: now) ??
        AccountEffect.none;
    // FR-05-17: deposit accounts from deposit statements.
    final deposits = await _accounts?.applyDeposits(result.deposits) ?? 0;
    // FR-05-18
    final check = result.holdingsCheck;
    final mismatch = check != null && check.mismatch
        ? HoldingsMismatch(
            statedValueMinor: check.statedValueMinor,
            rowsValueMinor: check.rowsValueMinor,
            statedInvestedMinor: check.statedInvestedMinor,
            rowsInvestedMinor: check.rowsInvestedMinor,
          )
        : null;
    final kind = _kind(result.statementKind);
    var notice = false;
    if (kind == StatementKind.creditCard &&
        (s.totalDueMinor != null || s.dueDate != null)) {
      notice = await _cardDues.recordNotice(
        NewCardNotice(
          isPayment: false,
          source: CardDueSource.statement,
          receivedAt: now,
          processedAt: now,
          bankName: result.bankName,
          last4: result.last4,
          totalDueMinor: s.totalDueMinor,
          minDueMinor: s.minDueMinor,
          dueEpochDay: s.dueDate?.toEpochDay(),
          creditLimitMinor: s.creditLimitMinor,
          statementEpochDay: s.statementDate?.toEpochDay(),
          availableMinor: s.availableMinor,
        ),
      );
    }
    final totals = StatementTotals(
      totalDueMinor: s.totalDueMinor,
      minDueMinor: s.minDueMinor,
      dueEpochDay: s.dueDate?.toEpochDay(),
      creditLimitMinor: s.creditLimitMinor,
      statementEpochDay: s.statementDate?.toEpochDay(),
      openingMinor: s.openingMinor,
      closingMinor: s.closingMinor,
      debitsMinor: s.debitsMinor,
      creditsMinor: s.creditsMinor,
      availableMinor: s.availableMinor,
    );
    final hasTotals = s.totalDueMinor != null ||
        s.closingMinor != null ||
        s.openingMinor != null;
    final empty =
        items.isEmpty && snaps.isEmpty && !hasTotals && result.deposits.isEmpty;
    final status = empty ? StatementStatus.empty : StatementStatus.parsed;
    final path = existing?.filePath ??
        await _files.save('${namePrefix ?? _short(key)}.bin', file.bytes);
    final int id;
    if (existing != null) {
      id = existing.id;
      await _statements.markProcessed(
        id,
        status: status,
        at: now,
        kind: kind,
        bankName: result.bankName,
        last4: result.last4,
        transactionCount: items.length,
        holdingCount: snaps.length,
        totals: totals,
        filePath: path,
      );
    } else {
      final r = await _statements.insert(
        NewStatement(
          key: key,
          source: origin == null ? StatementSource.file : StatementSource.email,
          sender: origin?.sender ?? file.name,
          fileName: file.name,
          receivedAt: origin?.receivedAt ?? now,
          processedAt: now,
          status: status,
          subject: origin?.subject,
          filePath: path,
          bankName: result.bankName,
          last4: result.last4,
          kind: kind,
          transactionCount: items.length,
          holdingCount: snaps.length,
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
    final outcome = StatementOutcome(
      added: report.inserted,
      merged: report.merged,
      review: report.flagged,
      holdingsUpdated: held,
      depositsUpdated: deposits,
      effect: effect,
      mismatch: mismatch,
    );
    await _outcomes?.save(id, outcome);
    return ImportDone(
      statementId: id,
      added: report.inserted,
      merged: report.merged,
      review: report.flagged,
      holdings: held,
      cardNotice: notice,
      empty: empty,
      accountEffect: effect,
      deposits: deposits,
      mismatch: mismatch,
    );
  }
}

sealed class _PdfOpen {
  const _PdfOpen();
}

class _Text extends _PdfOpen {
  const _Text(this.text);
  final String text;
}

class _Fail extends _PdfOpen {
  const _Fail(this.failure);
  final PdfFailure failure;
}
