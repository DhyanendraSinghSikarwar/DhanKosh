import 'package:parser_core/parser_core.dart';

import '../corpus/au_corpus.dart';
import '../corpus/axis_corpus.dart';
import '../corpus/bob_corpus.dart';
import '../corpus/hdfc_corpus.dart';
import '../corpus/icici_corpus.dart';
import '../corpus/idfc_corpus.dart';
import '../corpus/kotak_corpus.dart';
import '../corpus/pnb_corpus.dart';
import '../corpus/sbi_corpus.dart';
import '../corpus/yes_corpus.dart';

/// What a sample must parse to. Amount, type, account and reference are always
/// checked, so a null account or reference means "must be absent". Merchant,
/// balance, date and kind are checked only when given.
class Expect {
  const Expect(
    this.amount,
    this.type,
    this.last4, {
    this.ref,
    this.merchant,
    this.balance,
    this.date,
    this.kind,
    this.currency = 'INR',
  });

  final String amount;
  final TransactionType type;
  final String? last4;
  final String? ref;
  final String? merchant;
  final String? balance;
  final String? date;
  final AccountKind? kind;
  final String currency;
}

/// One anonymized message. [expect] null means the parser must reject it.
class Sample {
  const Sample(this.source, this.sender, this.body, this.expect);

  final Source source;
  final String sender;
  final String body;
  final Expect? expect;

  String get label {
    final e = expect;
    final what = e == null ? 'reject' : e.type.name;
    final text = body.replaceAll('\n', ' ');
    return '${source.name} $what: ${text.length > 70 ? text.substring(0, 70) : text}';
  }
}

/// Every sample was "received" at 25 Sep 2026, 12:00 IST.
final int receivedAt = epochOf(
  const CivilDate(2026, 9, 25),
  const CivilTime(12, 0),
  const Duration(hours: 5, minutes: 30),
);

const Duration ist = Duration(hours: 5, minutes: 30);

Sample sms(String sender, String body, [Expect? expect]) =>
    Sample(Source.sms, sender, body, expect);

Sample email(String sender, String body, [Expect? expect]) =>
    Sample(Source.email, sender, body, expect);

Expect debit(
  String amount,
  String? last4, {
  String? ref,
  String? merchant,
  String? balance,
  String? date,
  AccountKind? kind,
}) =>
    Expect(
      amount,
      TransactionType.debit,
      last4,
      ref: ref,
      merchant: merchant,
      balance: balance,
      date: date,
      kind: kind,
    );

Expect credit(
  String amount,
  String? last4, {
  String? ref,
  String? merchant,
  String? balance,
  String? date,
  AccountKind? kind,
}) =>
    Expect(
      amount,
      TransactionType.credit,
      last4,
      ref: ref,
      merchant: merchant,
      balance: balance,
      date: date,
      kind: kind,
    );

Expect transfer(String amount, String? last4, {String? ref, String? date}) =>
    Expect(
      amount,
      TransactionType.transfer,
      last4,
      ref: ref,
      date: date,
      kind: AccountKind.card,
    );

Expect invest(
  String amount,
  String? last4, {
  String? ref,
  String? merchant,
  String? balance,
  String? date,
}) =>
    Expect(
      amount,
      TransactionType.investment,
      last4,
      ref: ref,
      merchant: merchant,
      balance: balance,
      date: date,
    );

const AccountKind card = AccountKind.card;

/// Every bank's corpus, in the Kotlin order.
final Map<String, List<Sample>> allCorpora = {
  'HDFC': hdfcSamples,
  'ICICI': iciciSamples,
  'SBI': sbiSamples,
  'Axis': axisSamples,
  'Kotak': kotakSamples,
  'IDFC': idfcSamples,
  'Yes': yesSamples,
  'BoB': bobSamples,
  'PNB': pnbSamples,
  'AU': auSamples,
};

List<Sample> get allSamples => [for (final l in allCorpora.values) ...l];

/// The date of epoch [ms] in IST as `yyyy-MM-dd`.
String istDate(int ms) => civilDateOf(ms, ist).toString();
