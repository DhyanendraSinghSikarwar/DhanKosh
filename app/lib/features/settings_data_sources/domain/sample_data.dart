import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';

/// Clearly dummy bank SMS for a tester (FR-26-30). Fake account tails
/// (XX1234 bank, XX5678 card), fake merchants prefixed DEMO, fake refs.
abstract final class SampleData {
  /// Number of messages [build] returns.
  static const count = 25;

  /// 25 messages spread over the 60 days before [now], oldest first.
  static List<InboxSms> build(DateTime now) {
    final out = <InboxSms>[];
    var ref = 0;
    String r() => (++ref).toString().padLeft(12, '0');
    String d(DateTime t) => '${t.day.toString().padLeft(2, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${(t.year % 100).toString().padLeft(2, '0')}';
    const mon = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String dm(DateTime t) =>
        '${t.day.toString().padLeft(2, '0')}-${mon[t.month - 1]}-'
        '${(t.year % 100).toString().padLeft(2, '0')}';
    void add(
      int daysAgo,
      int hour,
      String sender,
      String Function(DateTime) f,
    ) {
      final t = DateTime(now.year, now.month, now.day, hour, 15)
          .subtract(Duration(days: daysAgo));
      out.add(
        InboxSms(
          sender: sender,
          body: f(t),
          receivedAt: t.millisecondsSinceEpoch,
          sentAt: t.millisecondsSinceEpoch,
        ),
      );
    }

    void upi(int ago, String amt, String to) => add(
          ago,
          11,
          'VM-HDFCBK',
          (t) => 'Rs.$amt debited from A/c XX1234 on ${d(t)} '
              'UPI Ref ${r()} to $to',
        );
    void card(int ago, String amt, String at) => add(
          ago,
          19,
          'VM-ICICIB',
          (t) => 'Rs.$amt spent on ICICI Bank Card XX5678 on ${dm(t)} at $at. '
              'Avl Limit: Rs.84,000.00',
        );

    add(
      58,
      9,
      'VM-HDFCBK',
      (t) => 'Rs.65,000.00 credited to A/c XX1234 on ${d(t)} by NEFT '
          'DEMO EMPLOYER SALARY. Ref ${r()}',
    );
    upi(57, '1,250.00', 'DEMO STORE');
    card(55, '899.00', 'DEMO FOOD COURT');
    upi(53, '320.00', 'DEMO CAFE');
    upi(51, '2,400.00', 'DEMO SUPERMART');
    card(49, '1,599.00', 'DEMO ELECTRONICS');
    upi(47, '180.00', 'DEMO AUTO');
    upi(45, '12,500.00', 'DEMO LANDLORD');
    card(43, '649.00', 'DEMO STREAMING');
    upi(41, '540.00', 'DEMO PHARMACY');
    card(39, '2,150.00', 'DEMO FUEL STATION');
    upi(37, '275.00', 'DEMO CAFE');
    add(
      30,
      9,
      'VM-HDFCBK',
      (t) => 'Rs.65,000.00 credited to A/c XX1234 on ${d(t)} by NEFT '
          'DEMO EMPLOYER SALARY. Ref ${r()}',
    );
    upi(29, '1,980.00', 'DEMO SUPERMART');
    card(27, '3,499.00', 'DEMO APPAREL');
    upi(25, '12,500.00', 'DEMO LANDLORD');
    upi(22, '410.00', 'DEMO FOOD DELIVERY');
    card(20, '749.00', 'DEMO BOOKSTORE');
    upi(17, '230.00', 'DEMO AUTO');
    card(14, '1,200.00', 'DEMO FUEL STATION');
    upi(11, '860.00', 'DEMO SUPERMART');
    card(8, '525.00', 'DEMO FOOD COURT');
    upi(5, '350.00', 'DEMO CAFE');
    upi(3, '1,150.00', 'DEMO ELECTRICITY');
    add(
      1,
      9,
      'VM-HDFCBK',
      (t) => 'Rs.65,000.00 credited to A/c XX1234 on ${d(t)} by NEFT '
          'DEMO EMPLOYER SALARY. Ref ${r()}',
    );
    return out;
  }
}
