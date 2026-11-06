// Spreadsheet statements read through a column mapping, and the balance check
// (FR-05-28, FR-05-29). Every row is synthetic.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

List<List<String>> _rows(List<String> lines) => [
      for (final l in lines) l.split('|'),
    ];

int _day(int y, int m, int d) =>
    DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ 86400000;

void main() {
  group('header and column guesses', () {
    test('the header sits after a preamble naming the account', () {
      final rows = _rows([
        'Example Bank Ltd||||',
        'Account Statement||||',
        'Account No: XXXXXX4321||||',
        'Date|Narration|Chq/Ref No|Value Dt|Withdrawal Amt.|Deposit Amt.|Closing Balance',
        '05/11/2026|UPI/612345678901/GROCERY MART/okaxis|612345678901|05/11/2026|250.00||9750.00',
      ]);
      final h = StatementTable.guessHeaderRow(rows);
      expect(h, 3);
      final m = StatementTable.guessMapping(rows, h);
      expect(m.date, 0);
      expect(m.description, 1);
      expect(m.reference, 2);
      expect(m.debit, 4);
      expect(m.credit, 5);
      expect(m.balance, 6);
      expect(m.isSplit, isTrue);
      expect(m.amount, isNull);
      expect(m.isComplete, isTrue);
    });

    test('Txn Date, Amount, Dr/Cr, Balance is single mode with a type column',
        () {
      final rows = _rows([
        'Txn Date|Description|Amount|Dr/Cr|Balance',
        '05/11/2026|Tea|20.00|Dr|980.00',
      ]);
      final m = StatementTable.guessMapping(rows, 0);
      expect(m.date, 0);
      expect(m.amount, 2);
      expect(m.type, 3);
      expect(m.balance, 4);
      expect(m.isSplit, isFalse);
    });

    test('a Transaction Type column of UPI/NEFT/CARD is not a direction', () {
      final rows = _rows([
        'Date|Narration|Amount|Transaction Type',
        '05/11/2026|Tea|20.00|UPI',
        '06/11/2026|Rent|9000.00|NEFT',
        '07/11/2026|Shop|400.00|CARD',
      ]);
      expect(StatementTable.guessMapping(rows, 0).type, isNull);
    });

    test('a Transaction Type column of Dr and Cr words is a direction', () {
      final rows = _rows([
        'Date|Narration|Amount|Transaction Type',
        '05/11/2026|Tea|20.00|DR',
        '06/11/2026|Salary|9000.00|CR',
      ]);
      expect(StatementTable.guessMapping(rows, 0).type, 3);
    });

    test('a single Debit/Credit header is a direction, not two amounts', () {
      final rows = _rows([
        'Date|Particulars|Amount|Debit/Credit',
        '05/11/2026|Tea|20.00|Debit',
      ]);
      final m = StatementTable.guessMapping(rows, 0);
      expect(m.isSplit, isFalse);
      expect(m.type, 3);
      expect(m.amount, 2);
    });

    test('with no date word the widest row is the header', () {
      final rows = _rows([
        'Bank||',
        'Day|Narration|Debit|Credit|Bal',
        '1|x|2|3|4',
      ]);
      expect(StatementTable.guessHeaderRow(rows), 1);
    });

    test('the signature is positional and ignores case and spacing', () {
      expect(
        StatementTable.signature([' Date ', 'Narration', '', 'Debit  Amt', '']),
        'date|narration||debit amt',
      );
    });
  });

  group('amounts', () {
    AmountCell? a(String s) => StatementAmounts.parse(s);

    test('Indian and Western grouping, currency marks, no decimals', () {
      expect(a('1,23,456.78'), const AmountCell(12345678, AmountSign.unknown));
      expect(a('₹ 500'), const AmountCell(50000, AmountSign.unknown));
      expect(a('Rs.250'), const AmountCell(25000, AmountSign.unknown));
      expect(a('INR 1,000'), const AmountCell(100000, AmountSign.unknown));
      expect(a('1,234.5'), const AmountCell(123450, AmountSign.unknown));
      expect(a('7'), const AmountCell(700, AmountSign.unknown));
    });

    test('brackets, minus, plus, Dr and Cr set the sign', () {
      expect(a('(250.00)'), const AmountCell(25000, AmountSign.debit));
      expect(a('-99'), const AmountCell(9900, AmountSign.debit));
      expect(a('99-'), const AmountCell(9900, AmountSign.debit));
      expect(a('+500'), const AmountCell(50000, AmountSign.credit));
      expect(a('500.00 Cr'), const AmountCell(50000, AmountSign.credit));
      expect(a('500.00 Dr.'), const AmountCell(50000, AmountSign.debit));
      expect(a('Dr 75'), const AmountCell(7500, AmountSign.debit));
    });

    test('a decimal comma is read, Indian grouping is not mistaken for one',
        () {
      expect(a('1.234,56'), const AmountCell(123456, AmountSign.unknown));
      expect(a('12,5'), const AmountCell(1250, AmountSign.unknown));
      expect(a('1,234'), const AmountCell(123400, AmountSign.unknown));
      expect(a('12,34,567'), const AmountCell(123456700, AmountSign.unknown));
    });

    test('paise are rounded half up, never truncated', () {
      expect(a('10.005'), const AmountCell(1001, AmountSign.unknown));
      expect(a('10.004'), const AmountCell(1000, AmountSign.unknown));
    });

    test('exponents, words and overlong numbers are not amounts', () {
      expect(a('1e1000'), isNull);
      expect(a('abc'), isNull);
      expect(a(''), isNull);
      expect(a('12345678901234.00'), isNull);
      expect(a('REF 526812345678 done'), isNull);
    });

    test('a balance is negative for Dr, brackets and a minus sign', () {
      expect(StatementAmounts.parseBalance('1,000.00'), 100000);
      expect(StatementAmounts.parseBalance('1,000.00 Dr'), -100000);
      expect(StatementAmounts.parseBalance('(50.00)'), -5000);
      expect(StatementAmounts.parseBalance(''), isNull);
    });
  });

  group('dates', () {
    test('day-first wins on an ambiguous file; the 13th proves it', () {
      final cells = [for (var i = 0; i < 30; i++) '05/01/2025', '13/01/2025'];
      expect(StatementDateFormats.detect(cells), 'dd/MM/yyyy');
      expect(
        StatementDateFormats.parse('13/01/2025', 'dd/MM/yyyy'),
        _day(2025, 1, 13),
      );
      expect(StatementDateFormats.parse('13/01/2025', 'MM/dd/yyyy'), isNull);
    });

    test('Excel serial numbers are read as dates', () {
      final cells = [for (var i = 45658; i <= 45688; i++) '$i'];
      expect(StatementDateFormats.detect(cells), StatementDateFormats.serial);
      expect(
        StatementDateFormats.parse('45658', StatementDateFormats.serial),
        _day(2025, 1, 1),
      );
      expect(
        StatementDateFormats.parse('45688', StatementDateFormats.serial),
        _day(2025, 1, 31),
      );
    });

    test('a forced two-digit-year pattern does not read a four-digit year', () {
      expect(StatementDateFormats.parse('05/01/2025', 'dd/MM/yy'), isNull);
    });

    test('month names, times after a date, and impossible dates', () {
      expect(
        StatementDateFormats.parse('05-Nov-2026', 'dd-MMM-yyyy'),
        _day(2026, 11, 5),
      );
      expect(
        StatementDateFormats.parse('5 nov 26', 'dd MMM yy'),
        _day(2026, 11, 5),
      );
      expect(
        StatementDateFormats.parse('2026-11-05 10:30:00', 'yyyy-MM-dd'),
        _day(2026, 11, 5),
      );
      expect(StatementDateFormats.parse('31/02/2026', 'dd/MM/yyyy'), isNull);
      expect(StatementDateFormats.parse('05/11/1850', 'dd/MM/yyyy'), isNull);
    });
  });

  group('reading rows', () {
    final split = _rows([
      'Date|Narration|Chq/Ref No|Withdrawal Amt.|Deposit Amt.|Balance',
      'Opening Balance||||| 10000.00',
      '01/11/2026|UPI/612345678901/GROCERY MART/okaxis|612345678901|250.00||9750.00',
      '02/11/2026|SALARY ACME LTD|||50000.00|59750.00',
      '03/11/2026|ATM WDL|||2000.00||',
      'Total||||',
    ]);

    test('reads debits, credits, references and balances; skips the rest', () {
      final m = StatementTable.guessMapping(split, 0);
      final s = StatementTable.parse(split, m);
      expect(s.dateFormat, 'dd/MM/yyyy');
      expect(s.rows, hasLength(3));
      expect(s.skipped, 2); // the opening balance line and the totals line
      expect(s.rows[0].isDebit, isTrue);
      expect(s.rows[0].amountMinor, 25000);
      expect(s.rows[0].reference, '612345678901');
      expect(s.rows[0].balanceMinor, 975000);
      expect(s.rows[1].isDebit, isFalse);
      expect(s.rows[1].amountMinor, 5000000);
      expect(s.rows[2].balanceMinor, isNull);
    });

    test('a single amount column with a type column', () {
      final rows = _rows([
        'Txn Date|Description|Amount|Dr/Cr|Balance',
        '05/11/2026|Tea|20.00|Dr|980.00',
        '06/11/2026|Refund|15.00|Cr|995.00',
      ]);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.rows.map((r) => r.isDebit), [true, false]);
    });

    test('a signed amount with no type column: minus is money out', () {
      final rows = _rows([
        'Date|Narration|Amount',
        '05/11/2026|Tea|-20.00',
        '06/11/2026|Pay|500.00',
        '07/11/2026|Rent|(9000.00)',
      ]);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.rows.map((r) => r.isDebit), [true, false, true]);
    });

    test('Excel serial dates and a mapping with no date format', () {
      final rows = _rows([
        'Date|Narration|Amount|Dr/Cr',
        '45966|Tea|20.00|Dr',
        '45967|Pay|500.00|Cr',
      ]);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.dateFormat, StatementDateFormats.serial);
      expect(s.rows.first.epochDay, 45966 - 25569);
    });

    test('identical rows in one file both import and keep apart', () {
      final rows = _rows([
        'Date|Narration|Debit|Credit',
        '06/11/2026|UPI/tea stall|20.00|',
        '06/11/2026|UPI/tea stall|20.00|',
        '06/11/2026|UPI/tea stall|20.00|',
      ]);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.rows.map((r) => r.occurrence), [0, 1, 2]);
      final tx = StatementTable.toTransactions(
        s.rows,
        bankName: 'Example Bank',
        last4: '4321',
      );
      expect(tx.map((t) => t.transactionHash).toSet(), hasLength(3));
      expect(tx.every((t) => t.source == Source.statement), isTrue);
      expect(tx.every((t) => t.balanceMinor == null), isTrue);
    });

    test('a row dated years from the rest is dropped as a misread cell', () {
      final lines = [
        'Date|Narration|Debit|Credit',
        for (var i = 1; i <= 28; i++)
          '${i.toString().padLeft(2, '0')}/10/2025|Row $i|10.00|',
        for (var i = 1; i <= 28; i++)
          '${i.toString().padLeft(2, '0')}/11/2025|Row $i|10.00|',
        '01/01/2015|Typo|10.00|',
      ];
      final rows = _rows(lines);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.droppedIsolated, 1);
      expect(s.rows, hasLength(56));
    });

    test('a narration gives a merchant and a reference', () {
      final m = StatementTable.guessMapping(split, 0);
      final s = StatementTable.parse(split, m);
      final tx =
          StatementTable.toTransactions(s.rows, bankName: 'Example Bank');
      expect(tx.first.merchant, isNotNull);
      expect(tx.first.merchant!.toUpperCase(), contains('GROCERY'));
      expect(tx.first.referenceNumber, '612345678901');
      // Noon IST, date only.
      expect(tx.first.hasExplicitTime, isFalse);
    });

    test('an incomplete mapping reads nothing', () {
      final s = StatementTable.parse(split, const ColumnMapping(date: 0));
      expect(s.rows, isEmpty);
    });
  });

  group('running balance and the balance check (FR-05-29)', () {
    List<List<String>> sheet(List<String> body) => _rows([
          'Date|Narration|Debit|Credit|Balance',
          ...body,
        ]);

    test('balances that add up are trusted; the closing row is the last', () {
      final rows = sheet([
        '01/11/2026|A|100.00||900.00',
        '02/11/2026|B||50.00|950.00',
        '03/11/2026|C|25.00||925.00',
      ]);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.continuity.addsUp, isTrue);
      expect(s.continuity.oldestFirst, isTrue);
      expect(StatementBalanceCheck.trustworthy(s), isTrue);
      final c = StatementBalanceCheck.closing(s)!;
      expect(c.minor, 92500);
      expect(c.epochDay, _day(2026, 11, 3));
      expect(StatementBalanceCheck.compare(c, 92500).matches, isTrue);
      final off = StatementBalanceCheck.compare(c, 91000);
      expect(off.matches, isFalse);
      expect(off.differenceMinor, 1500);
      expect(StatementBalanceCheck.compare(c, null).differenceMinor, isNull);
    });

    test('a newest-first file closes on its first row', () {
      final rows = sheet([
        '03/11/2026|C|25.00||925.00',
        '02/11/2026|B||50.00|950.00',
        '01/11/2026|A|100.00||900.00',
      ]);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.continuity.oldestFirst, isFalse);
      expect(s.continuity.addsUp, isTrue);
      expect(StatementBalanceCheck.closing(s)!.minor, 92500);
    });

    test('one day: the arithmetic decides the order', () {
      final oldest = sheet([
        '01/11/2026|A|100.00||900.00',
        '01/11/2026|B|100.00||800.00',
      ]);
      final newest = sheet([
        '01/11/2026|B|100.00||800.00',
        '01/11/2026|A|100.00||900.00',
      ]);
      StatementBalanceCheck? none;
      expect(none, isNull);
      final o =
          StatementTable.parse(oldest, StatementTable.guessMapping(oldest, 0));
      final n =
          StatementTable.parse(newest, StatementTable.guessMapping(newest, 0));
      expect(o.continuity.oldestFirst, isTrue);
      expect(StatementBalanceCheck.closing(o)!.minor, 80000);
      expect(n.continuity.oldestFirst, isFalse);
      expect(StatementBalanceCheck.closing(n)!.minor, 80000);
    });

    test('swapped debit and credit columns break the balances', () {
      final rows = sheet([
        '01/11/2026|A|100.00||900.00',
        '02/11/2026|B||50.00|950.00',
        '03/11/2026|C|25.00||925.00',
      ]);
      final good = StatementTable.guessMapping(rows, 0);
      final swapped = good.copyWith(debit: good.credit, credit: good.debit);
      final s = StatementTable.parse(rows, swapped);
      expect(s.continuity.breaks, greaterThan(0));
      expect(s.continuity.addsUp, isFalse);
      expect(StatementBalanceCheck.trustworthy(s), isFalse);
      expect(s.continuity.firstBreakRow, isNotNull);
    });

    test('no balance column: nothing to check', () {
      final rows = _rows([
        'Date|Narration|Debit|Credit',
        '01/11/2026|A|100.00|',
      ]);
      final s =
          StatementTable.parse(rows, StatementTable.guessMapping(rows, 0));
      expect(s.continuity.checked, 0);
      expect(StatementBalanceCheck.closing(s), isNull);
      expect(StatementBalanceCheck.trustworthy(s), isFalse);
    });
  });

  group('saved layouts', () {
    test('a mapping survives a round trip and tolerates old files', () {
      const m = ColumnMapping(
        headerRow: 3,
        date: 0,
        description: 1,
        debit: 4,
        credit: 5,
        balance: 6,
        dateFormat: 'dd-MM-yyyy',
      );
      expect(ColumnMapping.fromJson(m.toJson()), m);
      expect(ColumnMapping.fromJson({'date': 2}).date, 2);
      expect(ColumnMapping.fromJson(const {}).isComplete, isFalse);
    });
  });
}
