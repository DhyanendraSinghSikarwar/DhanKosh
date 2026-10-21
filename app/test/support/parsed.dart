import 'package:parser_core/parser_core.dart';

/// 2026-09-25 10:00 IST.
const int t0 = 1790310600000;
const int minute = 60 * 1000;
const int hour = 60 * minute;

/// Test hash: same five parts as memory 07 3.1 (not SHA-256; any stable
/// string works for the repository).
String testHash(
  int amountMinor,
  TransactionType type,
  String? last4,
  int time,
  String? ref,
) {
  final istDay = (time + 19800000) ~/ 86400000;
  return '$amountMinor|${type.direction}|${last4 ?? ''}|$istDay|${ref ?? ''}';
}

ParsedTransaction parsed({
  int amountMinor = 25000,
  TransactionType type = TransactionType.debit,
  Source source = Source.sms,
  String bank = 'HDFC Bank',
  String? last4 = '1234',
  AccountKind kind = AccountKind.account,
  String? merchant = 'Swiggy',
  String? upiId,
  String? ref = '526812345678',
  int time = t0,
  bool explicit = true,
  int? balance,
  int? limit,
  Category category = Category.food,
  bool debitCard = false,
  String currency = 'INR',
}) =>
    ParsedTransaction(
      amountMinor: amountMinor,
      currency: currency,
      type: type,
      bankName: bank,
      accountLast4: last4,
      accountKind: kind,
      merchant: merchant,
      upiId: upiId,
      referenceNumber: ref,
      channel: Channel.upi,
      balanceMinor: balance,
      availableLimitMinor: limit,
      transactionTime: time,
      hasExplicitTime: explicit,
      category: category,
      source: source,
      sender: 'HDFCBK',
      messageTimestamp: time,
      confidence: 0.9,
      transactionHash: testHash(amountMinor, type, last4, time, ref),
      isDebitCard: debitCard,
    );
