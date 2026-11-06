import 'package:parser_core/src/extract/channel_detector.dart';
import 'package:parser_core/src/extract/merchant_extractor.dart';
import 'package:parser_core/src/hash/transaction_hasher.dart';
import 'package:parser_core/src/merchant/merchant_normalizer.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/statement/table/column_mapping.dart';
import 'package:parser_core/src/statement/table/statement_cells.dart';
import 'package:parser_core/src/util/civil.dart';

/// One parsed spreadsheet row (FR-05-28).
class MappedRow {
  /// Creates a row.
  const MappedRow({
    required this.epochDay,
    required this.description,
    required this.amountMinor,
    required this.isDebit,
    required this.occurrence,
    required this.sourceRow,
    this.balanceMinor,
    this.reference,
  });

  /// Transaction day, days since 1970-01-01.
  final int epochDay;

  /// Narration with whitespace collapsed.
  final String description;

  /// Absolute amount, paise.
  final int amountMinor;

  /// True for money out.
  final bool isDebit;

  /// Signed amount: credit positive, debit negative.
  int get signedMinor => isDebit ? -amountMinor : amountMinor;

  /// Running balance after the row, when the sheet has one.
  final int? balanceMinor;

  /// Reference, UTR or cheque number.
  final String? reference;

  /// 0 for the first of identical rows in a file, 1 for the second and so on,
  /// so two ₹20 teas on one day both import (FR-05-28).
  final int occurrence;

  /// Index of the row in the sheet, for pointing the user at it.
  final int sourceRow;
}

/// A statement read through a [ColumnMapping].
class MappedStatement {
  /// Creates a result.
  const MappedStatement({
    required this.rows,
    required this.skipped,
    required this.droppedIsolated,
    required this.dateFormat,
    required this.continuity,
  });

  /// The rows, in file order.
  final List<MappedRow> rows;

  /// Rows with no readable date or amount (opening balance, totals, footers).
  final int skipped;

  /// Rows whose date was far from every other and were taken as misread.
  final int droppedIsolated;

  /// The date pattern used, or null when no row had a date.
  final String? dateFormat;

  /// Whether the running balances add up.
  final Continuity continuity;
}

/// How the running balances of a statement line up (FR-05-29).
class Continuity {
  /// Creates a continuity result.
  const Continuity({
    required this.checked,
    required this.breaks,
    required this.oldestFirst,
    this.firstBreakRow,
  });

  /// Nothing to check: fewer than two rows carry a balance.
  static const none = Continuity(checked: 0, breaks: 0, oldestFirst: true);

  /// Pairs of consecutive rows both carrying a balance.
  final int checked;

  /// Pairs where `previous balance + row = balance` does not hold.
  final int breaks;

  /// Whether the file runs oldest first.
  final bool oldestFirst;

  /// The first row, in file order, that does not add up.
  final int? firstBreakRow;

  /// There were balances to compare and every pair held.
  bool get addsUp => checked > 0 && breaks == 0;
}

/// Reads a bank spreadsheet through a user-checked column mapping (FR-05-28).
abstract final class StatementTable {
  static const _scanRows = 50;
  static const _maxSampleCells = 200;

  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _blank(List<String> r) => r.every((c) => c.trim().isEmpty);

  /// The row holding the column names: the first of the first 50 rows with at
  /// least three filled cells, one of them containing "date"; else the widest
  /// row, the earliest on a tie.
  static int guessHeaderRow(List<List<String>> rows) {
    final n = rows.length < _scanRows ? rows.length : _scanRows;
    var widest = 0;
    var widestCount = 0;
    for (var i = 0; i < n; i++) {
      final filled = rows[i].where((c) => c.trim().isNotEmpty).toList();
      if (filled.length >= 3 &&
          filled.any((c) => c.toLowerCase().contains('date'))) {
        return i;
      }
      if (filled.length > widestCount) {
        widest = i;
        widestCount = filled.length;
      }
    }
    return widest;
  }

  /// The header cells as a key a saved layout is stored under: trimmed,
  /// lower-cased, spaces collapsed, joined with `|`, trailing empties dropped.
  static String signature(List<String> header) {
    final cells = [for (final c in header) _norm(c)];
    while (cells.isNotEmpty && cells.last.isEmpty) {
      cells.removeLast();
    }
    return cells.join('|');
  }

  static int? _find(
    List<String> h,
    List<String> keywords, {
    Set<int> not = const {},
  }) {
    for (final k in keywords) {
      for (var i = 0; i < h.length; i++) {
        if (!not.contains(i) && h[i].contains(k)) return i;
      }
    }
    return null;
  }

  static int? _exact(
    List<String> h,
    List<String> words, {
    Set<int> not = const {},
  }) {
    for (var i = 0; i < h.length; i++) {
      if (!not.contains(i) && words.contains(h[i].replaceAll('.', ''))) {
        return i;
      }
    }
    return null;
  }

  static final RegExp _directionHeader = RegExp(
    r'^(dr\s*/\s*cr|cr\s*/\s*dr|debit\s*/\s*credit|credit\s*/\s*debit)$',
  );
  static const _debitWords = {'dr', 'd', 'debit', 'withdrawal'};
  static const _creditWords = {'cr', 'c', 'credit', 'deposit'};

  static bool _isDirection(String c) {
    final t = c.trim().toLowerCase().replaceAll('.', '');
    return _debitWords.contains(t) || _creditWords.contains(t);
  }

  /// A mapping guessed from the names in row [headerRow].
  static ColumnMapping guessMapping(List<List<String>> rows, int headerRow) {
    if (headerRow < 0 || headerRow >= rows.length) {
      return ColumnMapping(headerRow: headerRow < 0 ? 0 : headerRow);
    }
    final h = [for (final c in rows[headerRow]) _norm(c)];

    // A header that names a direction ("Dr/Cr", "Debit/Credit") is the type
    // column, never an amount.
    int? type;
    for (var i = 0; i < h.length; i++) {
      if (_directionHeader.hasMatch(h[i])) {
        type = i;
        break;
      }
    }
    final skip = {if (type != null) type};

    final date = _find(
      h,
      ['transaction date', 'txn date', 'tran date', 'value date', 'date'],
      not: skip,
    );
    // Prefer the transaction date over a value date when both exist.
    final txnDate =
        _find(h, ['transaction date', 'txn date', 'tran date'], not: skip);
    final dateCol = txnDate ?? date;
    final desc = _find(
      h,
      ['narration', 'description', 'particulars', 'details', 'remarks'],
      not: skip,
    );
    final debit = _find(h, ['debit', 'withdrawal', 'paid out'], not: skip) ??
        _exact(h, ['dr'], not: skip);
    final credit = _find(h, ['credit', 'deposit', 'paid in'], not: skip) ??
        _exact(h, ['cr'], not: skip);
    final split = debit != null && credit != null && debit != credit;
    final balance = _find(h, ['balance'], not: skip);
    final reference = _find(
      h,
      ['utr', 'ref no', 'ref.', 'reference', 'chq', 'cheque', 'ref'],
      not: {...skip, if (dateCol != null) dateCol},
    );
    final amount = split
        ? null
        : _find(
            h,
            ['amount', 'amt'],
            not: {...skip, if (balance != null) balance},
          );

    var typeCol = type;
    if (typeCol == null && !split) {
      // A "type" column counts only when nearly every cell is a direction
      // word; a "Transaction Type" of UPI/NEFT/CARD is a channel.
      final t = _find(h, ['type']);
      if (t != null) {
        final cells = <String>[];
        for (var r = headerRow + 1;
            r < rows.length && cells.length < _maxSampleCells;
            r++) {
          if (t < rows[r].length && rows[r][t].trim().isNotEmpty) {
            cells.add(rows[r][t]);
          }
        }
        if (cells.isNotEmpty) {
          final ok = cells.where(_isDirection).length;
          if (ok * 10 >= cells.length * 9) typeCol = t;
        }
      }
    }

    final base = ColumnMapping(
      headerRow: headerRow,
      date: dateCol,
      description: desc,
      amount: split ? null : amount,
      type: split ? null : typeCol,
      debit: split ? debit : null,
      credit: split ? credit : null,
      balance: balance,
      reference: reference,
    );
    return base;
  }

  /// The pattern that reads the date column of [rows] under [m].
  static String? detectDateFormat(List<List<String>> rows, ColumnMapping m) {
    final c = m.date;
    if (c == null) return null;
    return StatementDateFormats.detect(_column(rows, m.headerRow + 1, c));
  }

  static Iterable<String> _column(
    List<List<String>> rows,
    int from,
    int col,
  ) sync* {
    for (var r = from; r < rows.length; r++) {
      yield col < rows[r].length ? rows[r][col] : '';
    }
  }

  static String _cell(List<String> row, int? i) =>
      i == null || i >= row.length ? '' : row[i];

  static String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static final RegExp _refToken = RegExp(r'^[A-Za-z0-9]{6,32}$');
  static final RegExp _hasDigit = RegExp(r'\d');
  static final RegExp _twelve = RegExp(r'(?<!\d)\d{12}(?!\d)');
  static final RegExp _channelRef = RegExp(
    r'^(?:UPI|IMPS|NEFT|RTGS)[/\-:\s]+([A-Za-z0-9]{6,})',
    caseSensitive: false,
  );

  static String? _reference(String cell, String narration) {
    final c = cell.trim();
    if (_refToken.hasMatch(c) && _hasDigit.hasMatch(c)) return c;
    final m = _channelRef.firstMatch(narration);
    if (m != null && _hasDigit.hasMatch(m.group(1)!)) return m.group(1);
    final all = _twelve.allMatches(narration).toList();
    return all.isEmpty ? null : all.last.group(0);
  }

  /// Reads the rows below the header of [rows] with [m]. [dateFormat]
  /// overrides `m.dateFormat`; when both are null the format is detected.
  static MappedStatement parse(
    List<List<String>> rows,
    ColumnMapping m, {
    String? dateFormat,
  }) {
    final dateCol = m.date;
    if (!m.isComplete || dateCol == null) {
      return const MappedStatement(
        rows: [],
        skipped: 0,
        droppedIsolated: 0,
        dateFormat: null,
        continuity: Continuity.none,
      );
    }
    final fmt = dateFormat ?? m.dateFormat ?? detectDateFormat(rows, m);
    var skipped = 0;
    final parsed = <MappedRow>[];
    final seen = <String, int>{};
    for (var r = m.headerRow + 1; r < rows.length; r++) {
      final row = rows[r];
      if (_blank(row)) continue;
      final day = fmt == null
          ? null
          : StatementDateFormats.parse(_cell(row, dateCol), fmt);
      var minor = 0;
      var debit = false;
      var ok = false;
      if (m.isSplit) {
        final d = m.debit == null
            ? null
            : StatementAmounts.parse(_cell(row, m.debit));
        final c = m.credit == null
            ? null
            : StatementAmounts.parse(_cell(row, m.credit));
        if (d != null && d.minor > 0) {
          minor = d.minor;
          debit = true;
          ok = true;
        } else if (c != null && c.minor > 0) {
          minor = c.minor;
          debit = false;
          ok = true;
        }
      } else {
        final a = StatementAmounts.parse(_cell(row, m.amount));
        if (a != null && a.minor > 0) {
          minor = a.minor;
          ok = true;
          final word =
              _cell(row, m.type).trim().toLowerCase().replaceAll('.', '');
          if (_debitWords.contains(word)) {
            debit = true;
          } else if (_creditWords.contains(word)) {
            debit = false;
          } else {
            debit = a.sign == AmountSign.debit;
          }
        }
      }
      if (day == null || !ok) {
        skipped++;
        continue;
      }
      final desc = _collapse(_cell(row, m.description));
      final bal = m.balance == null
          ? null
          : StatementAmounts.parseBalance(_cell(row, m.balance));
      final key = '$day|$desc|$minor|$debit|$bal';
      final occ = seen[key] ?? 0;
      seen[key] = occ + 1;
      parsed.add(
        MappedRow(
          epochDay: day,
          description: desc,
          amountMinor: minor,
          isDebit: debit,
          balanceMinor: bal,
          reference: _reference(_cell(row, m.reference), desc),
          occurrence: occ,
          sourceRow: r,
        ),
      );
    }

    // A date more than a year from every other row is a misread cell.
    var dropped = 0;
    var kept = parsed;
    if (parsed.length >= 3) {
      final isolated = <int>{};
      for (var i = 0; i < parsed.length; i++) {
        var near = false;
        for (var j = 0; j < parsed.length && !near; j++) {
          if (j != i &&
              (parsed[j].epochDay - parsed[i].epochDay).abs() <= 366) {
            near = true;
          }
        }
        if (!near) isolated.add(i);
      }
      if (isolated.isNotEmpty && isolated.length * 4 < parsed.length) {
        kept = [
          for (var i = 0; i < parsed.length; i++)
            if (!isolated.contains(i)) parsed[i],
        ];
        dropped = isolated.length;
      }
    }
    return MappedStatement(
      rows: kept,
      skipped: skipped,
      droppedIsolated: dropped,
      dateFormat: fmt,
      continuity: _continuity(kept),
    );
  }

  static bool _newestFirst(List<MappedRow> rows) {
    if (rows.length < 2) return false;
    final first = rows.first.epochDay;
    final last = rows.last.epochDay;
    if (first != last) return first > last;
    // One day: the order the arithmetic supports.
    final a = rows[0];
    final b = rows[1];
    if (a.balanceMinor != null && b.balanceMinor != null) {
      final newest = a.balanceMinor! - b.balanceMinor! == a.signedMinor &&
          b.balanceMinor! - a.balanceMinor! != b.signedMinor;
      return newest;
    }
    return false;
  }

  static Continuity _continuity(List<MappedRow> rows) {
    final newest = _newestFirst(rows);
    final ordered = newest ? rows.reversed.toList() : rows;
    var checked = 0;
    var breaks = 0;
    int? firstBreak;
    for (var i = 1; i < ordered.length; i++) {
      final prev = ordered[i - 1].balanceMinor;
      final cur = ordered[i].balanceMinor;
      if (prev == null || cur == null) continue;
      checked++;
      if (prev + ordered[i].signedMinor != cur) {
        breaks++;
        firstBreak ??= ordered[i].sourceRow;
      }
    }
    return Continuity(
      checked: checked,
      breaks: breaks,
      oldestFirst: !newest,
      firstBreakRow: firstBreak,
    );
  }

  /// Turns [rows] into transactions for the ledger. Rows are stamped at noon
  /// IST (a sheet has no time of day); the running balance is not carried onto
  /// the transaction, so a noon-stamped row never moves an account balance.
  static List<ParsedTransaction> toTransactions(
    List<MappedRow> rows, {
    required String bankName,
    String? last4,
    AccountKind accountKind = AccountKind.account,
    String currency = 'INR',
    int stampedAt = 0,
  }) {
    const ist = Duration(hours: 5, minutes: 30);
    return [
      for (final r in rows)
        _toTransaction(
          r,
          bankName: bankName,
          last4: last4,
          accountKind: accountKind,
          currency: currency,
          stampedAt: stampedAt,
          offset: ist,
        ),
    ];
  }

  static ParsedTransaction _toTransaction(
    MappedRow r, {
    required String bankName,
    required String? last4,
    required AccountKind accountKind,
    required String currency,
    required int stampedAt,
    required Duration offset,
  }) {
    final type = r.isDebit ? TransactionType.debit : TransactionType.credit;
    final date = CivilDate.ofEpochDay(r.epochDay);
    final time = epochOf(date, const CivilTime(12, 0), offset);
    final channel =
        ChannelDetector.detect(r.description, r.description.toLowerCase());
    final raw = MerchantExtractor.extract(r.description, type);
    final merchant =
        MerchantNormalizer.normalize(raw, type, channel, r.description);
    final name = merchant.name ?? _channelMerchant(r.description);
    // Identical rows in one file keep apart through their occurrence number.
    final hashRef =
        r.reference ?? (r.occurrence > 0 ? '#${r.occurrence}' : null);
    return ParsedTransaction(
      amountMinor: r.amountMinor,
      currency: currency,
      type: type,
      bankName: bankName,
      accountLast4: last4,
      accountKind: accountKind,
      merchant:
          name == null || name.length <= 60 ? name : name.substring(0, 60),
      upiId: raw.vpa?.toLowerCase(),
      referenceNumber: r.reference,
      channel: channel,
      balanceMinor: null,
      availableLimitMinor: null,
      transactionTime: time,
      hasExplicitTime: false,
      category: merchant.category,
      source: Source.statement,
      sender: bankName,
      messageTimestamp: stampedAt == 0 ? time : stampedAt,
      confidence: 0.8,
      transactionHash: TransactionHasher.hash(
        r.amountMinor,
        type,
        last4,
        date,
        hashRef,
      ),
    );
  }

  static final RegExp _channelTokens = RegExp(
    r'^(?:UPI|IMPS|NEFT|RTGS|POS|ACH|NACH|BIL|VIN|MMT|CMS|INF)$',
    caseSensitive: false,
  );
  static final RegExp _ifsc = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

  /// "UPI/612345678901/GROCERY MART/okaxis" has no named payee the extractor
  /// knows; take the first later segment that reads as a name.
  static String? _channelMerchant(String narration) {
    final parts = narration.split('/').map((s) => s.trim()).toList();
    if (parts.length < 2 || !_channelTokens.hasMatch(parts.first)) return null;
    for (final s in parts.skip(1)) {
      if (s.isEmpty || s.contains('@') || _ifsc.hasMatch(s)) continue;
      if (RegExp('[A-Za-z]').hasMatch(s) && !RegExp(r'^\d').hasMatch(s)) {
        return s;
      }
    }
    return null;
  }
}
