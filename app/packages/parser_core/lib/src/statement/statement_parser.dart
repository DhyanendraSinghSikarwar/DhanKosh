// Parity with the Kotlin string concatenation of long regexes.
// ignore_for_file: use_string_buffers
import 'package:parser_core/src/bank/deposits.dart';
import 'package:parser_core/src/bank/loan_status.dart';
import 'package:parser_core/src/extract/account_extractor.dart';
import 'package:parser_core/src/extract/channel_detector.dart';
import 'package:parser_core/src/extract/merchant_extractor.dart';
import 'package:parser_core/src/extract/money.dart';
import 'package:parser_core/src/hash/transaction_hasher.dart';
import 'package:parser_core/src/merchant/merchant_normalizer.dart';
import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/statement/epf_passbook.dart';
import 'package:parser_core/src/statement/figures.dart';
import 'package:parser_core/src/statement/holding_lines.dart';
import 'package:parser_core/src/statement/holding_profiles.dart';
import 'package:parser_core/src/statement/holding_sheet.dart';
import 'package:parser_core/src/statement/holding_table.dart';
import 'package:parser_core/src/statement/holdings_check.dart';
import 'package:parser_core/src/statement/nps_statement.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/text/text_normalizer.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// What a statement is about.
enum StatementKind {
  creditCard('Credit card'),
  bank('Bank account'),
  investment('Investments'),
  other('Other');

  const StatementKind(this.label);

  /// Display name.
  final String label;
}

/// The figures printed at the top of a statement. Card statements have dues;
/// any field may be missing. Money is paise.
class StatementSummary {
  /// Creates a summary.
  const StatementSummary({
    this.totalDueMinor,
    this.minDueMinor,
    this.dueDate,
    this.creditLimitMinor,
    this.statementDate,
    this.openingMinor,
    this.closingMinor,
    this.debitsMinor,
    this.creditsMinor,
    this.availableMinor,
  });

  /// Total amount due.
  final int? totalDueMinor;

  /// Minimum amount due.
  final int? minDueMinor;

  /// Payment due date.
  final CivilDate? dueDate;

  /// Credit limit.
  final int? creditLimitMinor;

  /// Statement date.
  final CivilDate? statementDate;

  /// Opening balance.
  final int? openingMinor;

  /// Closing balance.
  final int? closingMinor;

  /// Total debits.
  final int? debitsMinor;

  /// Total credits.
  final int? creditsMinor;

  /// Available credit limit.
  final int? availableMinor;
}

/// What a statement PDF held: transaction rows (card or bank statement),
/// holdings (CAS, broker), or nothing usable.
class StatementResult {
  /// Creates a result.
  const StatementResult({
    required this.bankName,
    required this.last4,
    required this.kind,
    required this.transactions,
    required this.holdings,
    this.lines = const [],
    this.statementKind = StatementKind.other,
    this.summary = const StatementSummary(),
    this.deposits = const [],
    this.holdingsCheck,
  });

  /// Bank or issuer.
  final String? bankName;

  /// Last four digits of the account or card.
  final String? last4;

  /// Account or card.
  final AccountKind kind;

  /// Rows as transactions.
  final List<ParsedTransaction> transactions;

  /// Holdings.
  final List<HoldingSnapshot> holdings;

  /// The statement line each transaction came from, in the same order.
  final List<String> lines;

  /// What the statement is.
  final StatementKind statementKind;

  /// Printed totals.
  final StatementSummary summary;

  /// FD, RD or PPF accounts the statement or advice describes; their rows are
  /// not transactions.
  final List<LoanStatus> deposits;

  /// A holdings sheet's stated totals against its rows' sums; null when the
  /// sheet states none.
  final HoldingsCheck? holdingsCheck;
}

class _Pool {
  _Pool(this.amounts, this.dates);
  final List<CardAmount> amounts;
  final List<String> dates;
}

class _Label {
  _Label(this.key, this.m);
  final String key;
  final RegExpMatch m;
}

/// Reads the text of a statement PDF (FR-05-03, FR-05-04, FR-05-06,
/// FR-05-14).
///
/// Transaction statements: every line that starts with a date and ends with an
/// amount is a row. A credit card row is a spend unless it says Cr, payment,
/// refund or reversal. A bank row usually ends with the running balance, so the
/// direction comes from whether the balance went up or down.
///
/// Holdings statements (CAMS/KFintech/NSDL/CDSL CAS, broker statements): a line
/// with an ISIN and its units and value, or a CAMS "Closing Unit Balance ...
/// Market Value" line under an "ISIN:" scheme header.
class StatementParser {
  /// Creates a parser.
  const StatementParser([this.config = const ParserConfig()]);

  /// Zone and settings.
  final ParserConfig config;

  static const _headerLines = 40;
  static const _summaryLines = 120;
  static const _labelBlock = 8;
  static const _dateKeys = {'due_date', 'stmt_date', 'period'};

  /// Reads [text] (the statement's text lines) from [sender]; [receivedAt] is
  /// epoch milliseconds.
  StatementResult parse(String text, String sender, int receivedAt) {
    final lines = text
        .split(RegExp(r'\r\n|\n|\r'))
        .map((l) => l.replaceAll(' ', ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final header = lines.take(_headerLines).join(' ');
    final isCard = _cardStatement.hasMatch(header);
    final mm = _maskedNumber.firstMatch(header);
    final last4 = (mm == null ? null : firstGroup(mm)) ??
        AccountExtractor.extract(header)?.last4;
    String? bank;
    for (final (re, name) in _banks) {
      if (re.hasMatch(header)) {
        bank = name;
        break;
      }
    }
    if (bank == null) {
      final lt = sender.indexOf('<');
      final n = (lt < 0 ? sender : sender.substring(0, lt)).trim();
      bank = n.isEmpty ? 'Statement' : n;
    }
    final dk = _depositKind(header);
    if (dk != null) {
      return _deposit(lines, header, dk, bank, last4, sender, receivedAt);
    }
    final holdings = _holdings(lines, receivedAt, sender);
    final rows = holdings.isNotEmpty || EpfPassbook.isEpf(lines)
        ? const <(ParsedTransaction, String)>[]
        : _rows(lines, bank, last4, isCard, sender, receivedAt);
    final StatementKind kind;
    if (holdings.isNotEmpty ||
        _investmentStatement.hasMatch(header) ||
        _investmentSender.hasMatch(sender)) {
      kind = StatementKind.investment;
    } else if (isCard) {
      kind = StatementKind.creditCard;
    } else if (rows.isNotEmpty || _bankStatement.hasMatch(header)) {
      kind = StatementKind.bank;
    } else {
      kind = StatementKind.other;
    }
    return StatementResult(
      bankName: bank,
      last4: last4,
      kind: isCard ? AccountKind.card : AccountKind.account,
      transactions: [for (final r in rows) r.$1],
      holdings: holdings,
      lines: [for (final r in rows) r.$2],
      statementKind: kind,
      summary: summary(lines, localDate(receivedAt, config.utcOffset)),
      holdingsCheck: holdings.isEmpty && rows.isNotEmpty
          ? null
          : HoldingsCheckReader.check(lines, holdings),
    );
  }

  // Summary figures: "Total Amount Due: 12,345.00", labels with their values
  // below (a header row, or one label per line).

  _Pool _poolOf(String line) => _Pool(
        CardFigures.amounts(line),
        CardFigures.date.allMatches(line).map((m) => m.group(0)!).toList(),
      );

  List<_Label> _labelsOf(String line) {
    final all = <_Label>[];
    for (final (key, re) in _summaryLabels) {
      final m = re.firstMatch(line);
      if (m != null) all.add(_Label(key, m));
    }
    // Stable sort by start.
    final indexed = [for (var i = 0; i < all.length; i++) (i, all[i])]
      ..sort((a, b) {
        final c = a.$2.m.start.compareTo(b.$2.m.start);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    final out = <_Label>[];
    for (final (_, l) in indexed) {
      if (out.isEmpty || l.m.start > out.last.m.end - 1) out.add(l);
    }
    return out;
  }

  /// The summary figures in the first 120 [lines]; [ref] is the local date the
  /// statement was received (for dates without a year).
  StatementSummary summary(List<String> lines, [CivilDate? ref]) {
    int? total;
    int? min;
    String? due;
    int? limit;
    String? stmt;
    String? period;
    final found = <String, int>{};
    final top = lines.take(_summaryLines).toList();
    void give(String key, CardAmount? amount, String? date) {
      switch (key) {
        case 'total':
          if (total == null && amount != null) {
            total = amount.credit ? 0 : amount.minor;
          }
        case 'min':
          if (min == null && amount != null) {
            min = amount.credit ? 0 : amount.minor;
          }
        case 'limit':
          if (limit == null && amount != null) limit = amount.minor;
        case 'due_date':
          due ??= date;
        case 'stmt_date':
          stmt ??= date;
        case 'period':
          period ??= date;
        default:
          if (amount != null) found.putIfAbsent(key, () => amount.minor);
      }
    }

    var i = 0;
    while (i < top.length) {
      final line = top[i];
      // The header of the transactions table ("Narration ... Closing Balance")
      // is not a summary.
      final labels = _tableHeader.hasMatch(line) ? <_Label>[] : _labelsOf(line);
      if (labels.isEmpty) {
        i++;
        continue;
      }
      final pending = <String>[];
      for (var idx = 0; idx < labels.length; idx++) {
        final l = labels[idx];
        // The value is between this label and the next one on the same line.
        final end =
            idx + 1 < labels.length ? labels[idx + 1].m.start : line.length;
        final same = _poolOf(line.substring(l.m.end, end));
        if (_dateKeys.contains(l.key)) {
          final d = l.key == 'period'
              ? (same.dates.isEmpty ? null : same.dates.last)
              : (same.dates.isEmpty ? null : same.dates.first);
          if (d != null) {
            give(l.key, null, d);
          } else {
            pending.add(l.key);
          }
        } else {
          final a = same.amounts.isEmpty ? null : same.amounts.first;
          if (a != null) {
            give(l.key, a, null);
          } else {
            pending.add(l.key);
          }
        }
      }
      var next = i + 1;
      if (pending.isNotEmpty) {
        // More labels on the lines below (one per line), then the values: in
        // the same order.
        var k = i + 1;
        while (k < top.length && k <= i + _labelBlock) {
          final l = _labelsOf(top[k]);
          if (l.isEmpty || _tableHeader.hasMatch(top[k])) break;
          var withValue = false;
          for (var idx = 0; idx < l.length; idx++) {
            final e = idx + 1 < l.length ? l[idx + 1].m.start : top[k].length;
            final p = _poolOf(top[k].substring(l[idx].m.end, e));
            if (p.amounts.isNotEmpty || p.dates.isNotEmpty) {
              withValue = true;
              break;
            }
          }
          if (withValue) break;
          pending.addAll(l.map((x) => x.key));
          k++;
        }
        final pool = _Pool([], []);
        var taken = 0;
        final needDates = pending.where(_dateKeys.contains).length;
        final needAmounts = pending.length - needDates;
        while (k < top.length &&
            taken < pending.length &&
            _labelsOf(top[k]).isEmpty &&
            (pool.amounts.length < needAmounts ||
                pool.dates.length < needDates)) {
          final p = _poolOf(top[k]);
          if (p.amounts.isEmpty && p.dates.isEmpty) break;
          pool.amounts.addAll(p.amounts);
          pool.dates.addAll(p.dates);
          taken++;
          k++;
        }
        for (final key in pending) {
          if (_dateKeys.contains(key)) {
            // "Statement Period 12/09/2026 to 11/10/2026": the end of the
            // period.
            String? d;
            if (key == 'period') {
              if (pool.dates.length >= 2) {
                d = pool.dates[1];
                pool.dates
                  ..removeAt(1)
                  ..removeAt(0);
              } else if (pool.dates.isNotEmpty) {
                d = pool.dates.removeAt(0);
              }
            } else if (pool.dates.isNotEmpty) {
              d = pool.dates.removeAt(0);
            }
            give(key, null, d);
          } else {
            give(
              key,
              pool.amounts.isEmpty ? null : pool.amounts.removeAt(0),
              null,
            );
          }
        }
        next = k > i + 1 ? k : i + 1;
      }
      i = next;
    }
    final sd = stmt ?? period;
    final stmtDate =
        sd == null ? null : CardFigures.parse(sd, ref: ref, forward: false);
    final dueDate =
        due == null ? null : CardFigures.parse(due!, ref: stmtDate ?? ref);
    return StatementSummary(
      totalDueMinor: total,
      minDueMinor: min,
      dueDate: dueDate,
      creditLimitMinor: limit,
      statementDate: stmtDate,
      openingMinor: found['opening'],
      closingMinor: found['closing'],
      debitsMinor: found['debits'],
      creditsMinor: found['credits'],
      availableMinor: found['available'],
    );
  }

  // Deposits: a PPF or RD account statement, or an FD advice/receipt.

  DepositKind? _depositKind(String header) {
    if (_cardStatement.hasMatch(header) || _savingsStatement.hasMatch(header)) {
      return null;
    }
    if (_ppfStatement.hasMatch(header)) return DepositKind.ppf;
    if (_rdStatement.hasMatch(header)) return DepositKind.rd;
    if (_fdAdvice.hasMatch(header)) return DepositKind.fd;
    return null;
  }

  /// The deposit's balance (the summary's closing balance, else the last
  /// running balance, else an FD's principal), its maturity and what happens
  /// then. Deposits into a PPF or RD came from a savings account, which has its
  /// own record of them, so the rows are not returned as transactions.
  StatementResult _deposit(
    List<String> lines,
    String header,
    DepositKind kind,
    String bank,
    String? last4,
    String sender,
    int receivedAt,
  ) {
    final sum = summary(lines, localDate(receivedAt, config.utcOffset));
    final top = lines.take(_summaryLines).join('\n');
    final number =
        DepositParser.numbered(TextNormalizer.normalize(header))?.$2 ?? last4;
    final rows = _rows(lines, bank, number, false, sender, receivedAt);
    final sdate = sum.statementDate;
    final at = sdate != null
        ? noonOf(sdate, config.utcOffset)
        : _asOfDate(lines, receivedAt);
    final stated = DepositParser.status(top, bank, at);
    final info = DepositParser.info(TextNormalizer.normalize(top), kind);
    final dm = _depositAmount.firstMatch(top);
    final stated0 = dm == null ? null : Money.parse(grp(dm, 1))?.minor;
    int? lastRowBalance;
    for (final r in rows.reversed) {
      if (r.$1.balanceMinor != null) {
        lastRowBalance = r.$1.balanceMinor;
        break;
      }
    }
    final balance = sum.closingMinor ??
        lastRowBalance ??
        stated0 ??
        stated?.outstandingMinor;
    final principal = stated0 ?? stated?.principalMinor;
    final deposits = number == null
        ? const <LoanStatus>[]
        : [
            LoanStatus(
              stated?.lender ?? bank,
              number,
              principal,
              balance,
              at,
              deposit: info,
            ),
          ];
    return StatementResult(
      bankName: bank,
      last4: number,
      kind: AccountKind.account,
      transactions: const [],
      holdings: const [],
      statementKind: StatementKind.investment,
      summary: sum,
      deposits: deposits,
    );
  }

  // Transaction rows.

  List<(ParsedTransaction, String)> _rows(
    List<String> lines,
    String bank,
    String? last4,
    bool isCard,
    String sender,
    int receivedAt,
  ) {
    final received = localDate(receivedAt, config.utcOffset);
    final out = <(ParsedTransaction, String)>[];
    int? previousBalance;
    for (final line in lines) {
      if (_skipRow.hasMatch(line)) {
        // An opening balance row seeds the running balance for the first
        // transaction.
        if (_opening.hasMatch(line)) {
          final all = _amount.allMatches(line).toList();
          if (all.isNotEmpty) {
            previousBalance = Money.parse(grp(all.last, 1))?.minor;
          }
        }
        continue;
      }
      final dateMatch = _leadingDate.firstMatch(line);
      if (dateMatch == null) continue;
      final date = _parseDate(dateMatch.group(0)!);
      if (date == null) continue;
      if (date.isAfter(received.plusDays(1)) ||
          date.isBefore(received.minusYears(2))) {
        continue;
      }
      final rest = line.substring(dateMatch.end);
      final amounts = _amount.allMatches(rest).toList();
      if (amounts.isEmpty) continue;
      final description = trimChars(
        rest
            .substring(0, amounts.first.start)
            .replaceAll(_secondDate, ' ')
            .trim(),
        '-| ',
      );
      if (description.length < 2) continue;

      final RegExpMatch amountStr;
      final int? balance;
      if (!isCard && amounts.length >= 2) {
        amountStr = amounts[amounts.length - 2];
        balance = Money.parse(grp(amounts.last, 1))?.minor;
      } else {
        amountStr = amounts.last;
        balance = null;
      }
      final amount = Money.parse(grp(amountStr, 1))?.minor;
      if (amount == null || amount <= 0) continue;
      final crDr = grp(amountStr, 2).toUpperCase();

      final TransactionType type;
      if (isCard && _cardPayment.hasMatch(description)) {
        type = TransactionType.transfer;
      } else if (crDr.startsWith('C')) {
        type = TransactionType.credit;
      } else if (crDr.startsWith('D')) {
        type = TransactionType.debit;
      } else if (balance != null && previousBalance != null) {
        type = balance > previousBalance
            ? TransactionType.credit
            : TransactionType.debit;
      } else if (_creditWords.hasMatch(description)) {
        type = TransactionType.credit;
      } else {
        type = TransactionType.debit;
      }
      if (balance != null) previousBalance = balance;

      final channel = ChannelDetector.detect(description);
      final merchant = MerchantNormalizer.normalize(
        RawMerchant(
          description.length > 60 ? description.substring(0, 60) : description,
          null,
        ),
        type,
        channel,
        description,
      );
      final at = noonOf(date, config.utcOffset);
      out.add(
        (
          ParsedTransaction(
            amountMinor: amount,
            currency: 'INR',
            type: type,
            bankName: bank,
            accountLast4: last4,
            accountKind: isCard ? AccountKind.card : AccountKind.account,
            merchant: merchant.name ??
                (description.length > 40
                    ? description.substring(0, 40)
                    : description),
            upiId: null,
            referenceNumber: null,
            channel: channel,
            balanceMinor: balance,
            availableLimitMinor: null,
            transactionTime: at,
            hasExplicitTime: false,
            category: merchant.category,
            source: Source.statement,
            sender: sender,
            messageTimestamp: receivedAt,
            confidence: 0.7,
            transactionHash:
                TransactionHasher.hash(amount, type, last4, date, null),
          ),
          line,
        ),
      );
    }
    return out;
  }

  CivilDate? _parseDate(String s) {
    if (s.trim().isEmpty) return null;
    return DepositParser.parseDate(s);
  }

  // Holdings.

  List<HoldingSnapshot> _holdings(
    List<String> lines,
    int receivedAt,
    String sender,
  ) {
    final asOf = _asOfDate(lines, receivedAt);
    // A spreadsheet of holdings: read by column, whichever platform exported
    // it.
    final sheet =
        HoldingSheet.read(lines, asOf, HoldingProfiles.platformOf(sender));
    if (sheet != null) return sheet;
    // EPFO member passbook: no ISINs, its rows are contributions, not bank
    // transactions.
    if (EpfPassbook.isEpf(lines)) return EpfPassbook.read(lines, asOf);
    final usd = _usdRate(lines);
    final out = <String, HoldingSnapshot>{};
    // Rows whose figures were cross-checked (units x price = value); a later
    // checked row beats an earlier unchecked one.
    final checked = <String>{};
    final fromClosing = <String>{};
    String? schemeName;
    String? schemeIsin;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // CAMS/KFintech CAS: "<scheme> - ISIN: INF...(Advisor: DIRECT)" then
      // "Closing Unit Balance: x ... Market Value on ...: INR y".
      final lm = _isinLabel.firstMatch(line);
      if (lm != null) {
        schemeIsin = grp(lm, 1);
        final n = trimChars(
          line.substring(0, lm.start).replaceFirst(_schemeCode, '').trim(),
          '- :',
        );
        schemeName = n.isNotEmpty ? n : (i > 0 ? lines[i - 1].trim() : null);
      }
      if (_closingLabel.hasMatch(line)) {
        final isin = schemeIsin;
        if (isin == null) continue;
        // The figures can wrap onto the next lines when the PDF is read.
        final joined = [
          for (var k = 0; k < 3; k++)
            if (i + k < lines.length) lines[i + k],
        ].join(' ');
        final um = _closingUnits.firstMatch(joined);
        final units =
            um == null ? null : parseDouble(grp(um, 1).replaceAll(',', ''));
        if (units == null) continue;
        final nm = _navOn.firstMatch(joined);
        final nav =
            nm == null ? null : parseDouble(grp(nm, 1).replaceAll(',', ''));
        final mv = _marketValue.firstMatch(joined);
        final value = (mv == null ? null : Money.parse(grp(mv, 1))?.minor) ??
            (nav == null ? null : paise(units * nav));
        final cm = _cost.firstMatch(joined);
        final cost = cm == null ? null : Money.parse(grp(cm, 1))?.minor;
        final name = schemeName ?? isin;
        final prev = out[isin];
        // One scheme in two folios: the folios add up.
        if (prev != null && fromClosing.contains(isin)) {
          out[isin] = prev.withFigures(
            units: (prev.units ?? 0.0) + units,
            valueMinor: (prev.valueMinor ?? 0) + (value ?? 0),
            investedMinor: prev.investedMinor == null && cost == null
                ? null
                : (prev.investedMinor ?? 0) + (cost ?? 0),
          );
        } else {
          out[isin] = HoldingSnapshot(
            kind: _kindOf(isin, name),
            name: name,
            identifier: isin,
            units: units,
            valueMinor: value,
            investedMinor: cost,
            asOf: asOf,
          );
        }
        fromClosing.add(isin);
        checked.add(isin);
        schemeIsin = null;
        continue;
      }
      if (_isinLabel.hasMatch(line)) continue;
      // NSDL/CDSL CAS and broker statements: "INE009A01021 INFOSYS LIMITED 10
      // 1,500.00 15,000.00", or the CDSL mutual-fund table "<scheme> INF...
      // <folio> <units> <NAV> <invested> <value> <gain>".
      final isin = _isin.firstMatch(line);
      if (isin == null) continue;
      if (_leadingDate.hasMatch(line)) continue; // a transaction row
      final before = line.substring(0, isin.start).trim();
      var after = line.substring(isin.end);
      var row = HoldingLines.read(before, after);
      // The figures wrapped onto the next line or two.
      var extra = 1;
      while (!(row?.consistent ?? false) && extra <= 2) {
        if (i + extra >= lines.length) break;
        final next = lines[i + extra];
        if (_isin.hasMatch(next) || _leadingDate.hasMatch(next)) break;
        after += ' $next';
        final longer = HoldingLines.read(before, after);
        if (longer != null && (row == null || longer.consistent)) row = longer;
        extra++;
      }
      final r = row;
      if (r == null) continue;
      var name = r.name;
      final key = isin.group(0)!;
      // A scheme name split over two lines ("Parag Parikh Flexi Cap Fund -
      // Direct" / "Plan Growth INF879O01027 ...").
      final prevLine = i > 0 ? lines[i - 1].trim() : '';
      if ((key.startsWith('INF') || before.isNotEmpty) &&
          (name.length < 3 || name.split(' ').length <= 2) &&
          prevLine.isNotEmpty &&
          !_isin.hasMatch(prevLine) &&
          !_tableWords.hasMatch(prevLine) &&
          _number.allMatches(prevLine).length <= 1 &&
          prevLine.split('').any(isLetter)) {
        name = HoldingLines.cleanName('$prevLine $name');
      }
      if (name.length < 2) continue;
      if (fromClosing.contains(key)) continue;
      if (out.containsKey(key) && (checked.contains(key) || !r.consistent)) {
        continue;
      }
      // A foreign ISIN (a US stock) is priced in dollars: converted at the
      // statement's rate, or left out.
      final double fx;
      if (key.startsWith('IN')) {
        fx = 1.0;
      } else if (usd == null) {
        continue;
      } else {
        fx = usd;
      }
      out[key] = HoldingSnapshot(
        kind: fx == 1.0 ? _kindOf(key, name) : HoldingKind.stock,
        name: name,
        identifier: key,
        units: r.units,
        valueMinor:
            r.valueMinor == null ? null : roundHalfUp(r.valueMinor! * fx),
        investedMinor:
            r.investedMinor == null ? null : roundHalfUp(r.investedMinor! * fx),
        asOf: asOf,
      );
      if (r.consistent) checked.add(key);
    }
    final found = out.values.where((h) => (h.valueMinor ?? 0) > 0).toList();
    // NPS Statement of Transaction: per-tier value and contributions, no ISINs.
    if (NpsStatement.isNps(lines)) {
      return [...found, ...NpsStatement.read(lines, asOf)];
    }
    // App statements without ISINs (Groww "Holdings statement"): a table of
    // units, invested and current value.
    if (found.isEmpty) {
      return HoldingTable.read(
        lines,
        asOf,
        usdRate: usd,
        platform: HoldingProfiles.platformOf(sender),
        hasIsin: _isin.hasMatch,
      );
    }
    return found;
  }

  /// Rupees per US dollar printed on the statement ("USD/INR: 83.50",
  /// "Exchange rate 1 USD = INR 83.50"), or null.
  double? _usdRate(List<String> lines) {
    for (final l in lines) {
      final m = _usdRateRx.firstMatch(l);
      final v = m == null ? null : parseDouble(grp(m, 1));
      if (v != null && v >= 40.0 && v <= 200.0) return v;
    }
    return null;
  }

  /// "Holdings as on 31-May-2026" / "Statement for the period ... to
  /// 31-05-2026": when the values were true.
  int _asOfDate(List<String> lines, int receivedAt) {
    final received = localDate(receivedAt, config.utcOffset);
    CivilDate? date;
    for (final l in lines.take(_summaryLines)) {
      final m = _asOn.firstMatch(l);
      final d = m == null ? null : _parseDate(grp(m, 1));
      if (d != null) {
        date = d;
        break;
      }
    }
    if (date == null) return receivedAt;
    if (date.isAfter(received.plusDays(1)) ||
        date.isBefore(received.minusMonths(6))) {
      return receivedAt;
    }
    return noonOf(date, config.utcOffset);
  }

  HoldingKind _kindOf(String isin, String? name) {
    if (name != null && _etfName.hasMatch(name)) return HoldingKind.etf;
    if (isin.startsWith('INF')) return HoldingKind.mutualFund;
    if (name != null && _bondName.hasMatch(name)) return HoldingKind.bond;
    if (name != null && _goldName.hasMatch(name)) return HoldingKind.gold;
    return HoldingKind.stock;
  }

  static final List<(String, RegExp)> _summaryLabels = [
    (
      'total',
      rx(r'total\s+(?:(?:amount|amt|payment)\.?\s+)?(?:due|payable|outstanding)\b|total\s+dues?\b|closing\s+balance\s+due|new\s+balance\b|'
          r'(?<!minimum\s)(?<!min\s)(?<!min\.\s)(?<!past\s)(?<!overdue\s)\bamount\s+(?:due|payable)\b'),
    ),
    (
      'min',
      rx(r'min(?:imum)?\.?(?:\s+(?:amount|amt|payment))?\.?\s+dues?\b|minimum\s+payable\b'),
    ),
    ('due_date', rx(r'(?:payment\s+)?due\s+date\b')),
    (
      'limit',
      rx(r'(?<!available\s)(?<!avl\.\s)(?:total\s+)?credit\s+limit\b'),
    ),
    (
      'stmt_date',
      rx(r'statement\s+(?:generation\s+|closing\s+)?date\b|statement\s+dated\b|bill(?:ing)?\s+date\b'),
    ),
    ('period', rx(r'(?:statement|billing)\s+period\b')),
    ('cash_limit', rx(r'(?:available\s+)?cash\s+(?:advance\s+)?limit\b')),
    (
      'available',
      rx(r'avail(?:able|\.)?\s+(?:credit\s+)?limit|avl\.?\s+(?:credit\s+|cr\.?\s+)?limit|available\s+credit\b'),
    ),
    ('opening', rx(r'(?:opening|previous)\s+(?:statement\s+)?bal(?:ance)?\b')),
    ('closing', rx(r'closing\s+bal(?:ance)?\b(?!\s+due)')),
    (
      'debits',
      rx(r'total\s+(?:debits?|withdrawals?)\b|(?<!no\.\s)(?<!no\s)\bdebits\b|\bwithdrawals\b'),
    ),
    (
      'credits',
      rx(r'total\s+(?:credits?|deposits?)\b|(?<!no\.\s)(?<!no\s)\bcredits\b|\bdeposits\b'),
    ),
  ];
  static final RegExp _savingsStatement = rx(
    r'(?:savings|current)\s+(?:bank\s+)?account\s+statement|statement\s+of\s+(?:your\s+)?(?:savings|current)\s+account',
  );
  static final RegExp _ppfStatement = rx(
    r'public\s+provident\s+fund|\bPPF\s+(?:account|a/c|statement|passbook)\b|\bPPF\b.{0,30}\bstatement\b',
  );
  static final RegExp _rdStatement = rx(
    r'recurring\s+deposit|\bRD\s+(?:account|a/c|statement|passbook|advice)\b',
  );
  static final RegExp _fdAdvice = rx(
    r'(?:fixed|term)\s+deposit\s+(?:advice|receipt|confirmation|certificate|statement|account\s+statement)|deposit\s+(?:advice|receipt|confirmation)'
    r'|\bFD\s+(?:advice|receipt|confirmation|certificate)|\bTDR\b|\bFDR\b',
  );
  static final RegExp _depositAmount = rx(
    r'\b(?:deposit|principal)\s+amount\s*(?:\(\s*(?:INR|Rs\.?|₹)\s*\))?\s*[:\-]?\s*(?:INR|Rs\.?|₹)?\s*(\d[\d,]*(?:\.\d{1,2})?)',
  );
  static final RegExp _usdRateRx = rx(
    r'(?:USD\s*/\s*INR|USD\s*-\s*INR|\bUSDINR\b|exchange\s+rate|conversion\s+rate|FX\s+rate|1\s*(?:USD|US\$|\$)\s*=)'
    r'\s*(?:\(\s*\w+\s*\))?\s*[:=@]?\s*(?:1\s*USD\s*=\s*)?(?:INR|Rs\.?|₹)?\s*(\d{2,3}(?:\.\d{1,4})?)',
  );
  static final RegExp _tableHeader = rx(
    r'\b(?:narration|particulars|description|chq|cheque|value\s+dt|txn\s+date|tran\s+date)\b',
  );
  static final RegExp _investmentStatement = rx(
    r'consolidated\s+account\s+statement|\bCAS\b|demat|holding\s+statement|portfolio|mutual\s+fund|\bfolio\b|US\s+stocks|statement\s+of\s+transaction|\bPRAN\b|\bNPS\b',
  );
  static final RegExp _investmentSender = rx(
    r'camsonline|kfintech|karvy|nsdl|cdsl|indmoney|zerodha|groww|upstox|angelone|dhan\.co|kuvera|icicidirect|icicisecurities|hdfcsec|kotaksecurities|paytmmoney|etmoney|mfcentral|proteantech|npscra|kfintech-cra|camsnps|npstrust',
  );
  static final RegExp _bankStatement = rx(
    r'account\s+statement|statement\s+of\s+account|savings\s+account|current\s+account',
  );
  static final RegExp _cardStatement = rx(
    r'\bcredit\s+cards?\b|\bcard\s+statement\b|\bminimum\s+(?:amount|payment)\s+due\b|\btotal\s+(?:amount|payment)\s+due\b|\bcredit\s+limit\b|\bnew\s+balance\b',
  );
  static final RegExp _maskedNumber = rx(
    r'(?:\d{4}|[x*]{4})[\s-]?[x*]{4}[\s-]?[x*]{4}[\s-]?(\d{4})\b|\b\d{4}[\s-]?\d{2}[x*]{2}[\s-]?[x*]{4}[\s-]?(\d{4})\b|'
    r'\b\d{4,6}[x*]{4,}[\s-]?(\d{4})\b|\b[x*]{2,}[\s-]?(\d{4})\b',
  );
  static final RegExp _leadingDate = rx(
    r'^\s*(?:\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{1,2}[\s-][A-Za-z]{3}[a-z]*[\s,-]+\d{2,4})',
  );
  static final RegExp _secondDate = rx(r'\b\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}\b');
  static final RegExp _amount =
      rx(r'(\d{1,3}(?:,\d{2,3})*\.\d{2}|\d+\.\d{2})\s*(Cr|CR|Dr|DR|C|D)?\b');
  static final RegExp _number = rx(r'\d[\d,]*(?:\.\d+)?');
  static final RegExp _skipRow = rx(
    r'\b(?:opening\s+balance|closing\s+balance|balance\s+(?:b/f|c/f|brought|carried)|total|minimum\s+amount|amount\s+due|'
    r'payment\s+due|credit\s+limit|statement\s+date|reward|points?\s+(?:earned|balance))\b',
  );
  static final RegExp _opening =
      rx(r'\bopening\s+balance\b|\bbalance\s+(?:b/f|brought)\b');
  static final RegExp _cardPayment = rx(
    r'\b(?:payment\s+received|thank\s+you|bbps\s+payment|autopay|auto\s+debit\s+payment|neft\s+payment|payment\s*-)\b',
  );
  static final RegExp _creditWords = rx(
    r'\b(?:refund|reversal|reversed|cashback|credit|interest\s+credit|salary|neft\s+cr|imps\s+cr|by\s+transfer|deposit)\b',
  );
  // ISINs are upper case: case-sensitive on purpose.
  static final RegExp _isin = RegExp(r'\b([A-Z]{2}[A-Z0-9]{9}\d)\b');
  static final RegExp _isinLabel =
      RegExp(r'ISIN\s*:\s*([A-Z]{2}[A-Z0-9]{9}\d)');
  static final RegExp _schemeCode = RegExp('^[A-Z0-9]{2,12}-');
  static final RegExp _closingLabel = rx(r'closing\s+unit\s+balance');
  static final RegExp _closingUnits =
      rx(r'closing\s+unit\s+balance\s*:?\s*([\d,]+\.?\d*)');
  static final RegExp _navOn =
      rx(r'\bNAV\s+on\s+[^:]{4,20}:\s*(?:INR|Rs\.?|₹)?\s*([\d,]+\.?\d*)');
  static final RegExp _marketValue = rx(
    r'(?:market\s+value|valuation)\s+on\s+[^:]{4,20}:\s*(?:INR|Rs\.?|₹)?\s*([\d,]+\.?\d*)',
  );
  static final RegExp _cost = rx(
    r'(?:total\s+)?cost\s+value\s*(?:\(\s*(?:INR|Rs\.?|₹)\s*\))?\s*:?\s*(?:INR|Rs\.?|₹)?\s*([\d,]+\.?\d*)',
  );
  static final RegExp _asOn = rx(
    r'\b(?:holdings?|statement|valuation|portfolio|balances?)\b.{0,40}?\bas\s+(?:on|of|at)\s*:?\s*(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}-\d{2}-\d{2}|\d{1,2}[\s-][A-Za-z]{3}[a-z]*[\s,-]+\d{4})',
  );
  static final RegExp _tableWords = rx(
    r'\b(?:ISIN|scheme\s+name|folio|security|closing\s+bal|NAV|valuation|market\s+(?:price|value)|units?)\b',
  );
  static final RegExp _etfName = rx(r'\bETF\b|\bBEES\b');
  static final RegExp _bondName = rx(r'\b(?:bond|debenture|NCD|SGB)\b');
  static final RegExp _goldName = rx(r'\bgold\b');
  static final List<(RegExp, String)> _banks = [
    (rx(r'\bHDFC\b'), 'HDFC Bank'),
    (rx(r'\bICICI\b'), 'ICICI Bank'),
    (rx(r'\bSBI\b|state\s+bank|SBI\s+Card'), 'SBI'),
    (rx(r'\bAxis\b'), 'Axis Bank'),
    (rx(r'\bKotak\b'), 'Kotak Mahindra Bank'),
    (rx(r'\bIDFC\b'), 'IDFC FIRST Bank'),
    (rx(r'\bYes\s+Bank\b'), 'Yes Bank'),
    (rx(r'\bIndusInd\b'), 'IndusInd Bank'),
    (rx(r'\bAmerican\s+Express\b'), 'American Express'),
    (rx(r'\bHSBC\b'), 'HSBC'),
    (rx(r'\bRBL\b'), 'RBL Bank'),
    (rx(r'\bAU\s+Small\s+Finance\b'), 'AU Small Finance Bank'),
    (rx(r'\bFederal\s+Bank\b'), 'Federal Bank'),
    (rx(r'\bIndia\s+Post\b|department\s+of\s+posts'), 'India Post'),
    (rx(r'\bStandard\s+Chartered\b'), 'Standard Chartered'),
  ];
}
