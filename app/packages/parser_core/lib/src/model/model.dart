/// Where a message came from.
enum Source { sms, email, app, screenshot, manual, statement }

/// Kind of money movement.
enum TransactionType {
  debit,
  credit,
  transfer,
  investment;

  /// Money direction used in the dedup hash instead of the raw type: the SMS
  /// and the email for one transaction can word it differently (one becomes
  /// investment, the other stays debit) but both move money out.
  String get direction => switch (this) {
    TransactionType.debit || TransactionType.investment => 'OUT',
    TransactionType.credit => 'IN',
    TransactionType.transfer => 'XFER',
  };
}

/// Bank account or card.
enum AccountKind { account, card }

/// Payment rail.
enum Channel { upi, imps, neft, rtgs, card, atm, autoDebit, other }

/// Top-level spend/income category (parity with the Kotlin `Category` enum).
enum Category {
  food('Food & Dining'),
  groceries('Groceries'),
  transport('Transport'),
  fuel('Fuel'),
  shopping('Shopping'),
  bills('Bills & Utilities'),
  entertainment('Entertainment'),
  travel('Travel'),
  health('Health'),
  education('Education'),
  rent('Rent'),
  insurance('Insurance'),
  emiLoan('EMI & Loans'),
  investment('Investment'),
  cash('Cash Withdrawal'),
  subscriptions('Subscriptions'),
  personalCare('Personal Care'),
  household('Household'),
  gifts('Gifts'),
  donations('Donations'),
  taxes('Taxes'),
  fees('Bank Fees & Charges'),
  salary('Salary'),
  income('Income'),
  refund('Refund'),
  transfer('Transfer'),
  other('Other');

  const Category(this.label);

  /// Display name.
  final String label;
}

/// One bank transaction pulled out of a message.
///
/// Amounts are integer minor units (paise). Times are epoch milliseconds.
/// [hasExplicitTime] is false when the message gave only a date and the time
/// of day came from [messageTimestamp].
class ParsedTransaction {
  /// Creates a parsed transaction.
  const ParsedTransaction({
    required this.amountMinor,
    required this.currency,
    required this.type,
    required this.bankName,
    required this.accountLast4,
    required this.accountKind,
    required this.merchant,
    required this.upiId,
    required this.referenceNumber,
    required this.channel,
    required this.balanceMinor,
    required this.availableLimitMinor,
    required this.transactionTime,
    required this.hasExplicitTime,
    required this.category,
    required this.source,
    required this.sender,
    required this.messageTimestamp,
    required this.confidence,
    required this.transactionHash,
    this.isDebitCard = false,
  });

  /// Amount in paise.
  final int amountMinor;

  /// ISO currency code.
  final String currency;

  /// Debit, credit, transfer or investment.
  final TransactionType type;

  /// Bank or lender display name.
  final String bankName;

  /// Last four digits of the account or card, if stated.
  final String? accountLast4;

  /// Account or card.
  final AccountKind accountKind;

  /// Normalised merchant or payee.
  final String? merchant;

  /// UPI id, if stated.
  final String? upiId;

  /// Bank reference (UTR, RRN), if stated.
  final String? referenceNumber;

  /// Payment rail.
  final Channel channel;

  /// Balance after the transaction, paise.
  final int? balanceMinor;

  /// Available card limit, paise.
  final int? availableLimitMinor;

  /// Transaction time, epoch ms.
  final int transactionTime;

  /// Whether the message stated a time of day.
  final bool hasExplicitTime;

  /// Guessed category.
  final Category category;

  /// Origin of the message.
  final Source source;

  /// Sender id of the message.
  final String sender;

  /// Message received time, epoch ms.
  final int messageTimestamp;

  /// Parser confidence, 0 to 1.
  final double confidence;

  /// Dedup hash (see `TransactionHasher`).
  final String transactionHash;

  /// A debit card: balance is the linked bank account's.
  final bool isDebitCard;
}
