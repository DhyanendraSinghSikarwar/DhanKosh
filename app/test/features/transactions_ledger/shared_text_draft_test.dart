// Text shared into the app becomes a pre-filled form (FR-08-27). Every text
// is synthetic.
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/transactions_ledger/domain/shared_text_draft.dart';
import 'package:parser_core/parser_core.dart';

final _now = DateTime(2026, 11, 6, 14, 30);

void main() {
  group('a bank message or receipt', () {
    test('fills amount, direction, payee and reference', () {
      final d = SharedTextDraft.of(
        'Rs.450.00 debited from A/c XX4821 to VPA swiggy@icici SWIGGY. '
        'UPI Ref 526812345678',
        now: _now,
      )!;
      expect(d.amountMinor, 45000);
      expect(d.type, TransactionType.debit);
      expect(d.merchant, isNotNull);
      expect(d.reference, '526812345678');
      expect(d.note, contains('swiggy@icici'));
      expect(d.sourceText, isNotEmpty);
    });

    test('a credit is Received', () {
      final d = SharedTextDraft.of(
        'INR 5,000.00 credited to A/c XX1122 from ASHA DEVI via UPI',
        now: _now,
      )!;
      expect(d.amountMinor, 500000);
      expect(d.type, TransactionType.credit);
    });

    test('a balance is never the amount', () {
      final d = SharedTextDraft.of(
        'Avl bal Rs 5,000.00. Paid Rs 450 to SWIGGY.',
        now: _now,
      )!;
      expect(d.amountMinor, 45000);
    });

    test('a foreign amount is not put in the rupee field', () {
      final d = SharedTextDraft.of(
        'Sent USD 12.50 to TEST CAFE from card ending 1234.',
        now: _now,
      )!;
      expect(d.amountMinor, isNull);
      expect(d.note, contains('USD 12.50'));
    });
  });

  group('a quick note', () {
    test('"450 swiggy" is 450 to Swiggy', () {
      final d = SharedTextDraft.of('450 swiggy', now: _now)!;
      expect(d.amountMinor, 45000);
      expect(d.merchant, 'Swiggy');
    });

    test('"chai 80.5" keeps the paise', () {
      final d = SharedTextDraft.of('chai 80.5', now: _now)!;
      expect(d.amountMinor, 8050);
      expect(d.merchant, 'Chai');
    });

    test('a long sentence with a stray number is not an amount', () {
      final d = SharedTextDraft.of(
        'Dinner with the whole family last Sunday was number 4 on my list',
        now: _now,
      )!;
      expect(d.amountMinor, isNull);
      expect(d.note, contains('Dinner'));
    });

    for (final text in const [
      'A/c XX1234',
      '03/10',
      'ref 526812345678',
      'hello',
    ]) {
      test('"$text" gives no amount', () {
        expect(SharedTextDraft.of(text, now: _now)!.amountMinor, isNull);
      });
    }

    test('zero is not an amount', () {
      final d = SharedTextDraft.of('Rs 0 cashback', now: _now)!;
      expect(d.amountMinor, isNull);
    });
  });

  group('edges', () {
    test('empty or blank text gives no form', () {
      expect(SharedTextDraft.of(null, now: _now), isNull);
      expect(SharedTextDraft.of('   \n ', now: _now), isNull);
    });

    test('text is capped at 1,000 characters', () {
      final d = SharedTextDraft.of('a' * 2500, now: _now)!;
      expect(d.note!.length, SharedTextDraft.maxChars);
    });

    test('the whole text always stays as the note', () {
      final d = SharedTextDraft.of('450 swiggy', now: _now)!;
      expect(d.note, '450 swiggy');
    });
  });
}
