// Deterministic dummy data for the screenshot harness. Dummy names only; all
// amounts are paise. Rows go straight into the database (test-only).
import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart';
import 'package:hisaab/features/recurring_transactions/domain/recurring.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/transactions_ledger/domain/transfer_pairing.dart';
import 'package:parser_core/parser_core.dart' as pc;

int _rs(num rupees) => (rupees * 100).round();

int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// Ids of the seeded rows the screenshot test needs.
class SeedIds {
  const SeedIds({required this.cardIds});

  /// Credit card account ids, in seed order.
  final List<int> cardIds;
}

/// Seeds [db] relative to [now]; the same input gives the same rows.
Future<SeedIds> seedDummyData(AppDatabase db, DateTime now) async {
  final nowMs = now.millisecondsSinceEpoch;
  Future<int> account(
    String bank,
    String last4,
    AccountType type, {
    int? balance,
    int? limitAvail,
    pc.AccountKind kind = pc.AccountKind.account,
    int? color,
    String? nickname,
    CardNetwork? network,
    int? maturityDay,
    int? principal,
    int? rateBps,
    int? tenure,
    int? startDay,
  }) =>
      db.into(db.accounts).insert(
            AccountsCompanion.insert(
              bankName: bank,
              last4: last4,
              kind: enumToDb(kind),
              createdAt: nowMs - 400 * 86400000,
              nickname: Value(nickname),
              colorArgb: Value(color),
              accountType: Value(enumToDb(type)),
              latestBalanceMinor:
                  kind == pc.AccountKind.account && type != AccountType.loan
                      ? Value(balance)
                      : const Value.absent(),
              availableLimitMinor: Value(limitAvail),
              balanceUpdatedAt: Value(nowMs - 3600000),
              cardNetwork: Value(network == null ? null : enumToDb(network)),
              maturityDay: Value(maturityDay),
              loanPrincipalMinor: Value(principal),
              loanRateBps: Value(rateBps),
              loanTenureMonths: Value(tenure),
              loanStartDay: Value(startDay),
              manualBalanceMinor: type == AccountType.loan
                  ? Value(balance)
                  : const Value.absent(),
              manualBalanceAt: type == AccountType.loan
                  ? Value(nowMs)
                  : const Value.absent(),
            ),
          );

  final hdfc = await account(
    'HDFC Bank',
    '4321',
    AccountType.salary,
    balance: _rs(248500),
    nickname: 'Salary',
  );
  final sbi = await account(
    'State Bank of India',
    '7788',
    AccountType.savings,
    balance: _rs(54200),
  );
  final icici = await account(
    'ICICI Bank',
    '9012',
    AccountType.savings,
    balance: _rs(112750),
  );
  await account(
    'Cash',
    '0000',
    AccountType.wallet,
    balance: _rs(6500),
    nickname: 'Cash in hand',
  );
  await account(
    'Paytm Wallet',
    '5566',
    AccountType.wallet,
    balance: _rs(1840),
  );
  final cardDefs = [
    ('HDFC Bank', '1111', 'Regalia', _rs(300000), CardNetwork.visa),
    ('ICICI Bank', '2222', 'Amazon Pay', _rs(200000), CardNetwork.visa),
    ('Axis Bank', '3333', 'Flipkart', _rs(150000), CardNetwork.mastercard),
  ];
  final cardIds = <int>[];
  for (final c in cardDefs) {
    cardIds.add(
      await account(
        c.$1,
        c.$2,
        AccountType.creditCard,
        kind: pc.AccountKind.card,
        limitAvail: c.$4 - _rs(42000),
        nickname: c.$3,
        network: c.$5,
      ),
    );
  }
  final today = _epochDay(now);
  await account(
    'HDFC Bank',
    '0042',
    AccountType.loan,
    balance: _rs(2950000),
    nickname: 'Home loan',
    principal: _rs(5000000),
    rateBps: 850,
    tenure: 240,
    startDay: today - 800,
  );
  await account(
    'HDFC Bank',
    '8801',
    AccountType.fd,
    balance: _rs(300000),
    nickname: 'Tax saver FD',
    maturityDay: today + 210,
  );
  await account(
    'SBI',
    '8802',
    AccountType.rd,
    balance: _rs(72000),
    nickname: 'Recurring deposit',
    maturityDay: today + 400,
  );

  // Transactions: 12 monthly blocks, 6 rows each plus fixed monthly items.
  var n = 0;
  Future<void> tx({
    required int daysAgo,
    required int rupees,
    required pc.TransactionType type,
    required pc.Category cat,
    required String merchant,
    required int accountId,
    required String bank,
    required String last4,
    pc.AccountKind kind = pc.AccountKind.account,
    pc.Channel channel = pc.Channel.upi,
    String? note,
  }) async {
    final t = DateTime(now.year, now.month, now.day, 10 + (n % 9), 20)
        .subtract(Duration(days: daysAgo));
    if (t.isAfter(now)) return;
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amountMinor: _rs(rupees),
            currency: 'INR',
            type: enumToDb(type),
            bankName: bank,
            accountLast4: Value(last4),
            accountKind: enumToDb(kind),
            accountId: Value(accountId),
            merchant: Value(merchant),
            referenceNumber: Value('DEMO${(++n).toString().padLeft(8, '0')}'),
            channel: enumToDb(channel),
            timestamp: t.millisecondsSinceEpoch,
            hasExplicitTime: true,
            category: enumToDb(cat),
            transactionHash: 'seed-$n',
            confidence: 1,
            note: Value(note),
            createdAt: nowMs,
            inrMinor: Value(_rs(rupees)),
          ),
        );
  }

  const d = pc.TransactionType.debit;
  const c = pc.TransactionType.credit;
  for (var m = 0; m < 12; m++) {
    final base = m * 30;
    int v(int amt, int k) => amt + ((m * 37 + k * 13) % 9) * amt ~/ 40;
    Future<void> a(
      int off,
      int amt,
      pc.Category cat,
      String merchant, {
      int acc = 0,
      pc.TransactionType type = d,
      pc.Channel ch = pc.Channel.upi,
      int k = 0,
    }) {
      final ids = [hdfc, sbi, icici];
      final banks = [
        ('HDFC Bank', '4321'),
        ('State Bank of India', '7788'),
        ('ICICI Bank', '9012'),
      ];
      return tx(
        daysAgo: base + off,
        rupees: type == c ? amt : v(amt, k),
        type: type,
        cat: cat,
        merchant: merchant,
        accountId: ids[acc],
        bank: banks[acc].$1,
        last4: banks[acc].$2,
        channel: ch,
      );
    }

    Future<void> card(
      int off,
      int amt,
      pc.Category cat,
      String merchant,
      int which,
      int k,
    ) =>
        tx(
          daysAgo: base + off,
          rupees: v(amt, k),
          type: d,
          cat: cat,
          merchant: merchant,
          accountId: cardIds[which],
          bank: cardDefs[which].$1,
          last4: cardDefs[which].$2,
          kind: pc.AccountKind.card,
          channel: pc.Channel.card,
        );

    await a(
      22,
      185000,
      pc.Category.salary,
      'Demo Technologies Payroll',
      type: c,
      ch: pc.Channel.neft,
    );
    await a(20, 32000, pc.Category.rent, 'Demo Landlord', k: 1);
    await a(
      19,
      15000,
      pc.Category.investment,
      'Demo Index Fund SIP',
      type: pc.TransactionType.investment,
      ch: pc.Channel.autoDebit,
    );
    await a(
      17,
      28000,
      pc.Category.emiLoan,
      'HDFC Home Loan EMI',
      ch: pc.Channel.autoDebit,
    );
    await a(15, 2400, pc.Category.bills, 'Demo Power Board', acc: 1, k: 2);
    await a(13, 3800, pc.Category.groceries, 'Demo Fresh Mart', acc: 2, k: 3);
    await a(10, 650, pc.Category.food, 'Demo Dosa Corner', k: 4);
    await a(6, 1200, pc.Category.transport, 'Demo Cabs', acc: 2, k: 5);
    await a(3, 2200, pc.Category.fuel, 'Demo Petrol Pump', k: 6);
    await card(21, 6800, pc.Category.shopping, 'Demo Online Store', 0, 7);
    await card(16, 1850, pc.Category.food, 'Demo Pizza House', 1, 8);
    await card(11, 649, pc.Category.subscriptions, 'Demo Streaming', 1, 9);
    await card(8, 4200, pc.Category.travel, 'Demo Airways', 2, 10);
    await card(4, 1450, pc.Category.entertainment, 'Demo Cinemas', 0, 11);
    await card(2, 2900, pc.Category.health, 'Demo Pharmacy', 2, 12);
    // Card bill payments: account side transfer plus card side credit.
    await tx(
      daysAgo: base + 1,
      rupees: v(32000, 14),
      type: pc.TransactionType.transfer,
      cat: pc.Category.transfer,
      merchant: 'HDFC Bank Credit Card',
      accountId: hdfc,
      bank: 'HDFC Bank',
      last4: '4321',
      channel: pc.Channel.neft,
      note: TransferPairing.cardBillNote,
    );
  }

  await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amountMinor: _rs(1200),
          currency: 'INR',
          type: enumToDb(c),
          bankName: 'ICICI Bank',
          accountLast4: const Value('9012'),
          accountKind: enumToDb(pc.AccountKind.account),
          accountId: Value(icici),
          merchant: const Value('Demo Interest Credit'),
          channel: enumToDb(pc.Channel.other),
          timestamp: nowMs - 86400000 * 5,
          hasExplicitTime: true,
          category: enumToDb(pc.Category.income),
          transactionHash: 'seed-interest',
          confidence: 1,
          createdAt: nowMs,
          inrMinor: Value(_rs(1200)),
        ),
      );

  // Card statements: due in the next days, limit, previous payment.
  var k = 0;
  for (var i = 0; i < cardDefs.length; i++) {
    final cd = cardDefs[i];
    final stmt = today - 10 - i * 3;
    await db.into(db.cardDueNotices).insert(
          CardDueNoticesCompanion.insert(
            key: 'seed-due-${k++}',
            kind: 'DUE',
            source: enumToDb(CardDueSource.sms),
            bankName: Value(cd.$1),
            last4: Value(cd.$2),
            totalDueMinor: Value(_rs([18450, 9320, 22780][i])),
            minDueMinor: Value(_rs([920, 470, 1140][i])),
            dueEpochDay: Value(today + [4, 11, 17][i]),
            creditLimitMinor: Value(cd.$4),
            statementEpochDay: Value(stmt),
            availableMinor: Value(cd.$4 - _rs(42000)),
            receivedAt: nowMs - (10 + i * 3) * 86400000,
            processedAt: nowMs - (10 + i * 3) * 86400000,
          ),
        );
    await db.into(db.cardDueNotices).insert(
          CardDueNoticesCompanion.insert(
            key: 'seed-pay-${k++}',
            kind: 'PAYMENT',
            source: enumToDb(CardDueSource.sms),
            bankName: Value(cd.$1),
            last4: Value(cd.$2),
            statementEpochDay: Value(stmt - 30),
            paymentMinor: Value(_rs([16200, 8100, 19900][i])),
            receivedAt: nowMs - (35 + i) * 86400000,
            processedAt: nowMs - (35 + i) * 86400000,
          ),
        );
  }

  // Budgets.
  for (final e in {
    pc.Category.food: 8000,
    pc.Category.groceries: 12000,
    pc.Category.shopping: 10000,
    pc.Category.transport: 5000,
    pc.Category.entertainment: 4000,
  }.entries) {
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            category: enumToDb(e.key),
            monthlyLimitMinor: _rs(e.value),
          ),
        );
  }

  // Recurring bills and a SIP.
  Future<void> rec(String name, int amt, int day, pc.Category cat) =>
      db.into(db.recurringItems).insert(
            RecurringItemsCompanion.insert(
              name: name,
              amountMinor: _rs(amt),
              income: false,
              frequency: enumToDb(RecurringFrequency.monthly),
              dayOfMonth: day,
              category: enumToDb(cat),
              createdAt: nowMs,
            ),
          );
  await rec('Demo Streaming', 649, 11, pc.Category.subscriptions);
  await rec('Demo Power Board', 2400, 15, pc.Category.bills);
  await rec('Demo Broadband', 999, 5, pc.Category.bills);
  await rec('Demo Landlord', 32000, 1, pc.Category.rent);
  await rec('Demo Insurance Premium', 18500, 24, pc.Category.insurance);
  await db.into(db.sips).insert(
        SipsCompanion.insert(
          name: 'Demo Index Fund SIP',
          amountMinor: _rs(15000),
          frequency: enumToDb(SipFrequency.monthly),
          dayOfMonth: const Value(5),
          startDay: today - 300,
          createdAt: nowMs,
        ),
      );
  await db.into(db.goals).insert(
        GoalsCompanion.insert(
          name: 'Demo Europe trip',
          targetMinor: _rs(300000),
          targetDay: Value(today + 240),
          createdAt: nowMs,
        ),
      );

  // Holdings in every class.
  Future<void> h(
    HoldingKind kind,
    String name,
    String id,
    int value,
    int invested, {
    double? units,
  }) =>
      db.into(db.holdings).insert(
            HoldingsCompanion.insert(
              kind: enumToDb(kind),
              name: name,
              identifier: id,
              source: enumToDb(HoldingSource.manual),
              updatedAt: nowMs,
              units: Value(units),
              valueMinor: Value(_rs(value)),
              investedMinor: Value(_rs(invested)),
              asOf: Value(nowMs - 86400000),
              previousValueMinor: Value(_rs(value * 0.985)),
              previousAsOf: Value(nowMs - 2 * 86400000),
            ),
          );
  await h(
    HoldingKind.stock,
    'Demo Industries Ltd',
    'INE000A01011',
    184000,
    150000,
    units: 62,
  );
  await h(
    HoldingKind.stock,
    'Demo Bank Ltd',
    'INE000B01012',
    96500,
    88000,
    units: 70,
  );
  await h(
    HoldingKind.mutualFund,
    'Demo Flexi Cap Fund',
    'INF000C01013',
    412000,
    330000,
    units: 8120.45,
  );
  await h(
    HoldingKind.mutualFund,
    'Demo Index 50 Fund',
    'INF000D01014',
    268000,
    240000,
    units: 1480.3,
  );
  await h(HoldingKind.nps, 'Demo NPS Tier 1', 'NPS-DEMO-1', 235000, 200000);
  await h(HoldingKind.epf, 'Demo EPF Account', 'EPF-DEMO-1', 640000, 560000);
  await h(
    HoldingKind.sukanya,
    'Demo Sukanya Samriddhi',
    'SSY-DEMO-1',
    148000,
    130000,
  );
  await h(HoldingKind.ppf, 'Demo PPF Account', 'PPF-DEMO-1', 520000, 450000);
  await h(HoldingKind.fd, 'Demo Bank FD', 'FD-DEMO-1', 305000, 300000);
  await h(HoldingKind.fd, 'Demo Bank RD', 'RD-DEMO-1', 74000, 72000);
  await h(
    HoldingKind.gold,
    'Demo Sovereign Gold Bond',
    'SGB-DEMO-1',
    118000,
    90000,
    units: 16,
  );

  return SeedIds(cardIds: cardIds);
}
