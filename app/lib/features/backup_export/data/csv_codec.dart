import 'package:csv/csv.dart';
import 'package:hisaab/features/backup_export/domain/backup_models.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// IST offset, the zone the parsers hash dates in (memory 24 section 10).
const int istOffsetMs = 19800000;

final _bareNewline = Csv(lineDelimiter: '\n', quoteMode: QuoteMode.necessary);
final _instant = RegExp(r'^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:?\d{2})$');

/// "2450.50" from paise by integer math; no sign, no grouping (FR-24-04).
String dec2(int minor) {
  final a = minor.abs();
  return '${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

/// `AUTO_DEBIT` for [Channel.autoDebit].
String enumName(Enum e) => e.name
    .replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m[0]}',
    )
    .toUpperCase();

/// Java `Instant.toString`: fractional seconds only when non-zero.
String isoInstant(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  final s = d.toIso8601String();
  final base = s.substring(0, 19);
  final frac =
      ms % 1000 == 0 ? '' : '.${(ms % 1000).toString().padLeft(3, '0')}';
  return '$base${frac}Z';
}

/// Header and one row per transaction, oldest first (FR-24-03/04).
String exportCsv(List<LedgerTx> rows) {
  final sorted = [...rows]..sort((a, b) {
      final c = a.timestamp.compareTo(b.timestamp);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final out = <List<String>>[
    csvHeader,
    for (final t in sorted)
      [
        isoInstant(t.timestamp),
        dec2(t.amountMinor),
        t.currency,
        enumName(t.type),
        t.bankName,
        t.accountLast4 ?? '',
        enumName(t.accountKind),
        t.merchant ?? '',
        enumName(t.category),
        enumName(t.channel),
        t.referenceNumber ?? '',
        if (t.balanceMinor == null) '' else dec2(t.balanceMinor!),
        t.upiId ?? '',
        t.note ?? '',
        t.transactionHash,
      ],
  ];
  return _bareNewline.encode(out);
}

/// Parses [text]; throws [FormatException] when date/amount/type are missing
/// (FR-24-07). Unreadable lines are counted, never fatal (FR-24-09).
CsvImportResult importCsv(String text, {int zoneOffsetMs = istOffsetMs}) {
  final body = text.startsWith('﻿') ? text.substring(1) : text;
  final lines = Csv(dynamicTyping: false).decode(body);
  if (lines.isEmpty) return const CsvImportResult(rows: [], badLines: 0);
  final header = [
    for (final h in lines.first) h.toString().trim().toLowerCase(),
  ];
  final iDate = header.indexOf('date');
  final iAmount = header.indexOf('amount');
  final iType = header.indexOf('type');
  if (iDate < 0 || iAmount < 0 || iType < 0) {
    throw const FormatException(csvNotExport);
  }
  final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
  final rows = <ParsedTransaction>[];
  var bad = 0;
  for (final line in lines.skip(1)) {
    if (line.length == 1 && line.first.toString().trim().isEmpty) continue;
    final p = _parseLine(line, idx, iDate, iAmount, iType, zoneOffsetMs);
    if (p == null) {
      bad++;
    } else {
      rows.add(p);
    }
  }
  return CsvImportResult(rows: rows, badLines: bad);
}

ParsedTransaction? _parseLine(
  List<dynamic> line,
  Map<String, int> idx,
  int iDate,
  int iAmount,
  int iType,
  int zoneOffsetMs,
) {
  String? col(String name) {
    final i = idx[name];
    if (i == null || i >= line.length) return null;
    final v = line[i].toString().trim();
    return v.isEmpty ? null : v;
  }

  if (line.length <= iDate || line.length <= iAmount || line.length <= iType) {
    return null;
  }
  final dateText = line[iDate].toString().trim();
  if (!_instant.hasMatch(dateText)) return null;
  final time = DateTime.tryParse(dateText)?.millisecondsSinceEpoch;
  final amount = _minor(line[iAmount].toString().trim().replaceAll(',', ''));
  final type = _byName(TransactionType.values, line[iType].toString());
  if (time == null || amount == null || type == null) return null;
  final balText = col('balance');
  final balance = balText == null ? null : _minor(balText, signed: true);
  if (balText != null && balance == null) return null;

  final last4 = col('account_last4');
  final ref = col('reference');
  final hash = col('hash') ??
      TransactionHasher.hash(
        amount,
        type,
        last4,
        _civil(time + zoneOffsetMs),
        ref,
      );
  return ParsedTransaction(
    amountMinor: amount,
    currency: col('currency') ?? 'INR',
    type: type,
    bankName: col('bank') ?? 'Imported',
    accountLast4: last4,
    accountKind: _byName(AccountKind.values, col('account_kind') ?? '') ??
        AccountKind.account,
    merchant: col('merchant'),
    upiId: col('upi_id'),
    referenceNumber: ref,
    channel: _byName(Channel.values, col('channel') ?? '') ?? Channel.other,
    balanceMinor: balance,
    availableLimitMinor: null,
    transactionTime: time,
    hasExplicitTime: true,
    category: _byName(Category.values, col('category') ?? '') ?? Category.other,
    source: Source.manual,
    sender: 'csv',
    messageTimestamp: time,
    confidence: 1,
    transactionHash: hash,
  );
}

CivilDate _civil(int shiftedMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(shiftedMs, isUtc: true);
  return CivilDate(d.year, d.month, d.day);
}

T? _byName<T extends Enum>(List<T> values, String raw) {
  final k = raw.trim().replaceAll('_', '').toLowerCase();
  for (final v in values) {
    if (v.name.toLowerCase() == k) return v;
  }
  return null;
}

/// Decimal text to paise; null for more than 2 significant decimals.
int? _minor(String s, {bool signed = false}) {
  final m = RegExp(r'^(-?)(\d*)(?:\.(\d*))?$').firstMatch(s);
  if (m == null) return null;
  final neg = m[1] == '-';
  final whole = m[2]!;
  final frac = (m[3] ?? '').replaceFirst(RegExp(r'0+$'), '');
  if (whole.isEmpty && frac.isEmpty) return null;
  if (frac.length > 2 || whole.length > 15) return null;
  if (neg && !signed) return null;
  final v = (int.tryParse(whole.isEmpty ? '0' : whole) ?? 0) * 100 +
      (int.tryParse(frac.padRight(2, '0')) ?? 0);
  return neg ? -v : v;
}
