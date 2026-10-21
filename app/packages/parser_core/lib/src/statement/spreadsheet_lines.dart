import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/statement/holding_columns.dart';
import 'package:parser_core/src/statement/holding_sheet.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

enum _Role { date, debit, credit, amount, balance, other }

/// Turns the rows of a statement spreadsheet (.xls, .xlsx or .csv) into the
/// text lines `StatementParser` reads from a PDF: one line per row, cells
/// joined by two spaces.
///
/// Spreadsheets lose what a PDF shows: amounts are bare numbers ("500" rather
/// than "500.00") and dates may be Excel day serials. So the header row is
/// found (Date, Narration, Withdrawal, Deposit, Balance...), the amount columns
/// are written with two decimals, a separate debit or credit column gets "Dr"
/// or "Cr" after its amount, and serial numbers in a date column become
/// dd/MM/yyyy (FR-05-05).
abstract final class SpreadsheetLines {
  /// [toLines] joined with newlines.
  static String toText(List<List<String>> rows) => toLines(rows).join('\n');

  /// The text lines of [rows].
  static List<String> toLines(List<List<String>> rows) {
    // A holdings sheet (Scheme Name, Units, Invested Value, Current Value...)
    // keeps its cells as written: its columns are not bank amounts.
    final holdings = rows.any(HoldingColumns.isHeader);
    final headerIndex = holdings || rows.any(isHoldingsHeader)
        ? -1
        : rows.indexWhere(_isHeader);
    final header = headerIndex >= 0
        ? rows[headerIndex].map((c) => c.trim().toLowerCase()).toList()
        : <String>[];
    final roles = header.map(_roleOf).toList();
    final out = <String>[];
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (holdings) {
        // Cells stay apart, blanks included, so HoldingSheet can read the
        // columns; a blank row ends a table.
        final cells = row.map((c) => c.trim()).toList();
        while (cells.isNotEmpty && cells.last.isEmpty) {
          cells.removeLast();
        }
        if (cells.isNotEmpty || out.isEmpty || out.last != HoldingSheet.sep) {
          out.add(
            cells.isEmpty ? HoldingSheet.sep : cells.join(HoldingSheet.sep),
          );
        }
        continue;
      }
      final List<String> cells;
      if (headerIndex < 0 || r <= headerIndex) {
        cells = row.map((c) => c.trim()).toList();
      } else {
        cells = [
          for (var c = 0; c < row.length; c++)
            _format(row[c].trim(), c < roles.length ? roles[c] : _Role.other),
        ];
      }
      final line = cells.where((c) => c.isNotEmpty).join('  ');
      if (line.trim().isNotEmpty) out.add(line);
    }
    return out;
  }

  static final RegExp _dateHead = RegExp(r'\b(?:date|dt)\b');
  static final RegExp _debitHead = RegExp(
    r'\b(?:debit|debits|withdrawal|withdrawals|withdrawal amt|dr|paid out|money out)\b',
  );
  static final RegExp _creditHead = RegExp(
    r'\b(?:credit|credits|deposit|deposits|deposit amt|cr|paid in|money in)\b',
  );
  static final RegExp _amountHead =
      RegExp(r'\b(?:amount|amt|transaction amount|inr|value)\b');
  static final RegExp _balanceHead = RegExp(r'\bbalance\b|\bbal\b');
  static final RegExp _headerWords = RegExp(
    r'\b(?:date|narration|description|particulars|details|remarks|withdrawal|deposit|debit|credit|amount|balance|chq|cheque|ref)\b',
  );
  static final RegExp _holdingNameHead = RegExp(
    r'^(?:scheme(?:\s+name)?|fund(?:\s+name)?|instrument|symbol|security(?:\s+name)?|stock(?:\s+name)?|company(?:\s+name)?)\b',
  );
  static final RegExp _holdingFigureHead = RegExp(
    r'\b(?:current\s+(?:value|amount)|cur\.?\s*val|market\s+value|invested|units|qty|quantity|ltp)',
  );

  /// A holdings table's header: a scheme / instrument name column beside a
  /// value, invested or units column.
  static bool isHoldingsHeader(List<String> row) {
    final cells = row.map((c) => c.trim().toLowerCase()).toList();
    return cells.any((c) => _holdingNameHead.hasMatch(c) && c.length < 30) &&
        cells
                .where((c) => _holdingFigureHead.hasMatch(c) && c.length < 30)
                .length >=
            2;
  }

  static bool _isHeader(List<String> row) =>
      row
          .where((c) => _headerWords.hasMatch(c.toLowerCase()) && c.length < 40)
          .length >=
      3;

  static _Role _roleOf(String h) {
    if (_balanceHead.hasMatch(h)) return _Role.balance;
    if (_dateHead.hasMatch(h)) return _Role.date;
    final d = _debitHead.hasMatch(h);
    final c = _creditHead.hasMatch(h);
    if (d && !c) return _Role.debit;
    if (c && !d) return _Role.credit;
    if (_amountHead.hasMatch(h)) return _Role.amount;
    return _Role.other;
  }

  static final RegExp _plainNumber = RegExp(r'^-?[\d,]*\d(?:\.\d+)?$');
  static final RegExp _suffixed =
      RegExp(r'^(-?[\d,]*\d(?:\.\d+)?)\s*(Cr|Dr|CR|DR|cr|dr)\.?$');

  static String _format(String cell, _Role role) {
    if (cell.isEmpty) return cell;
    switch (role) {
      case _Role.date:
        return serialDate(cell) ?? cell;
      case _Role.debit:
      case _Role.credit:
      case _Role.amount:
      case _Role.balance:
        final suffixed = _suffixed.firstMatch(cell);
        final String number;
        if (suffixed != null) {
          number = grp(suffixed, 1);
        } else if (_plainNumber.hasMatch(cell)) {
          number = cell;
        } else {
          return cell;
        }
        final plain = number.replaceAll(',', '');
        final negative = plain.startsWith('-');
        final abs = negative ? plain.substring(1) : plain;
        final isZero = abs.replaceAll(RegExp('[0.]'), '').isEmpty;
        if (isZero && role != _Role.balance) return '';
        final String mark;
        if (suffixed != null) {
          mark = grp(suffixed, 2).toLowerCase().startsWith('c') ? ' Cr' : ' Dr';
        } else if (role == _Role.debit) {
          mark = ' Dr';
        } else if (role == _Role.credit) {
          mark = ' Cr';
        } else if (role == _Role.amount && negative && !isZero) {
          mark = ' Dr';
        } else {
          mark = '';
        }
        return _twoDecimals(abs) + mark;
      case _Role.other:
        return cell;
    }
  }

  /// "500" -> "500.00", "1234.567" -> "1234.57" (half up, exact).
  static String _twoDecimals(String abs) {
    final dot = abs.indexOf('.');
    final whole = dot < 0 ? abs : abs.substring(0, dot);
    final frac = (dot < 0 ? '' : abs.substring(dot + 1)).padRight(3, '0');
    var n = BigInt.parse('$whole${frac.substring(0, 2)}');
    if (frac.codeUnitAt(2) >= 0x35) n += BigInt.one;
    final s = n.toString().padLeft(3, '0');
    return '${s.substring(0, s.length - 2)}.${s.substring(s.length - 2)}';
  }

  /// Excel stores a date as days since 30 Dec 1899: 46000 is 9 Dec 2025.
  static String? serialDate(String cell) {
    final v = parseDouble(cell);
    if (v == null || v < 20000 || v > 80000) return null;
    final d = const CivilDate(1899, 12, 30).plusDays(v.truncate());
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year.toString().padLeft(4, '0')}';
  }

  /// Splits CSV text into rows: quoted cells, doubled quotes, and a comma,
  /// semicolon, tab or pipe delimiter.
  static List<List<String>> parseCsv(String text) {
    final body = text.startsWith('﻿') ? text.substring(1) : text;
    final firstLines = body.split(RegExp(r'\r\n|\n|\r')).take(20).toList();
    var delimiter = ',';
    var bestCount = -1;
    for (final d in [',', ';', '\t', '|']) {
      var count = 0;
      for (final l in firstLines) {
        count += d.allMatches(l).length;
      }
      if (count > bestCount) {
        bestCount = count;
        delimiter = d;
      }
    }
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    var i = 0;
    String at(int k) => k < body.length ? body[k] : '';
    while (i < body.length) {
      final ch = body[i];
      if (quoted && ch == '"' && at(i + 1) == '"') {
        cell.write('"');
        i++;
      } else if (ch == '"' && (quoted || cell.toString().trim().isEmpty)) {
        quoted = !quoted;
        if (quoted) cell.clear();
      } else if (!quoted && ch == delimiter) {
        row.add(cell.toString());
        cell.clear();
      } else if (!quoted && (ch == '\n' || ch == '\r')) {
        if (ch == '\r' && at(i + 1) == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        if (row.any((c) => c.trim().isNotEmpty)) {
          rows.add(row);
        } else if (rows.isNotEmpty && rows.last.isNotEmpty) {
          rows.add(const []);
        }
        row = <String>[];
      } else {
        cell.write(ch);
      }
      i++;
    }
    row.add(cell.toString());
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    return rows;
  }
}
