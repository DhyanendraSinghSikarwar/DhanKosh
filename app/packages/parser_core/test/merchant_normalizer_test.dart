// Port of MerchantNormalizerTest (FR-06-09, TC-06-15).
import 'package:parser_core/parser_core.dart';
import 'package:parser_core/src/merchant/merchant_data.dart';
import 'package:test/test.dart';

NormalizedMerchant debit(String? name, [String? vpa]) =>
    MerchantNormalizer.normalize(
      RawMerchant(name, vpa),
      TransactionType.debit,
      Channel.upi,
      '',
    );

void main() {
  group('names are cleaned and categorised', () {
    const rows = [
      ('ACH D- TP ACH ZERODHA-1234567', 'Zerodha', Category.investment),
      ('NEFT-CITIN52026090112345-ACME CORP', 'Acme Corp', Category.other),
      ('UPI-525512345678-AMIT KUMAR', 'Amit Kumar', Category.other),
      ('ACH/ICCL MUTUAL FUND/12345678', 'ICCL', Category.investment),
      ('AMAZON PAY INDIA PVT LTD', 'Amazon', Category.shopping),
      ('BUNDL TECHNOLOGIES', 'Swiggy', Category.food),
      ('SWIGGY INSTAMART', 'Swiggy Instamart', Category.groceries),
      ('UBER INDIA', 'Uber', Category.transport),
      ('NETFLIX COM', 'Netflix', Category.entertainment),
      ('IRCTC', 'IRCTC', Category.travel),
      ('SHARMA MEDICALS', 'Sharma Medicals', Category.health),
      ('COCA COLA STORE', 'Coca Cola Store', Category.other),
      ('TATA MUTUAL FUND SIP', 'Tata Mutual Fund', Category.investment),
      ('TATA AIA LIFE', 'Tata AIA', Category.insurance),
      (
        'TATA CAPITAL FINANCIAL SERVICES',
        'Tata Capital',
        Category.emiLoan,
      ),
    ];
    for (final (raw, name, category) in rows) {
      test(raw, () {
        final m = debit(raw);
        expect(m.name, name);
        expect(m.category, category);
      });
    }
  });

  test('UBERIND13513699 is Uber, OLA does not match COCA COLA (TC-06-15)', () {
    expect(debit('UBERIND13513699').name, 'Uber');
    expect(debit('OLA CABS').name, 'Ola');
    expect(debit('COCA COLA').name, 'Coca Cola');
  });

  group('names come from the UPI id when the message has none', () {
    const rows = [
      ('swiggy.upi@axisbank', 'Swiggy'),
      ('zomato-order@ptybl', 'Zomato'),
      ('rahul.sharma@oksbi', 'Rahul Sharma'),
      ('paytm.s1abc2@paytm', 'S1abc'),
    ];
    for (final (vpa, name) in rows) {
      test(vpa, () => expect(debit(null, vpa).name, name));
    }
  });

  test('a personal vpa of digits gives no name', () {
    expect(debit(null, '9876543210@ybl').name, isNull);
  });

  test('atm withdrawals are cash', () {
    final m = MerchantNormalizer.normalize(
      const RawMerchant('HDFC0001234', null),
      TransactionType.debit,
      Channel.atm,
      '',
    );
    expect(m.name, 'ATM');
    expect(m.category, Category.cash);
  });

  test('credits are income, salary, or refund by wording', () {
    Category cat(String text) => MerchantNormalizer.normalize(
          const RawMerchant('ACME', null),
          TransactionType.credit,
          Channel.neft,
          text,
        ).category;
    expect(cat('NEFT credit SALARY SEP 2026'), Category.salary);
    expect(cat('Refund of INR 499 credited'), Category.refund);
    expect(cat('INR 500 credited'), Category.income);
  });

  test('the directory counts as the Kotlin one (115 rows, 17 lenders)', () {
    expect(directoryRows.length, 115);
    expect(Lenders.all.length, 17);
    expect(IndianBanks.all.length, 51);
  });
}
