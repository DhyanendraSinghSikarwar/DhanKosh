import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Notifier, NotifierProvider, Provider;

import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/scope_providers.dart';
import 'package:hisaab/core/utils/combine_latest.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/portfolio/data/amfi_nav_source.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/portfolio/domain/investment_tx.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/nav_refresh.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/profile/domain/bank_identity.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart' show Category;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'portfolio_providers.g.dart';

// Portfolio (F-16) and Profile (F-27) UI wiring.

/// Epoch day in IST for [ms].
int epochDayIst(int ms) => (ms + 19800000) ~/ 86400000;

/// Live holdings, largest first (FR-16-08).
@riverpod
Stream<List<Holding>> holdings(Ref ref) =>
    ref.watch(holdingRepositoryProvider).watch();

/// Net worth of one non-All book (FR-16-42).
@riverpod
Stream<NetWorth> netWorthForBook(Ref ref, Book book) =>
    ref.watch(netWorthServiceProvider).watch(book: book);

/// Net worth following the global book (FR-16-42).
final Provider<AsyncValue<NetWorth>> bookNetWorthProvider =
    Provider<AsyncValue<NetWorth>>((ref) {
  final book = ref.watch(bookProvider);
  return book == Book.all
      ? ref.watch(netWorthProvider)
      : ref.watch(netWorthForBookProvider(book));
});

/// True once the news screen was opened this session; drives the unread dot
/// on the Portfolio news button (FR-31-40).
class NewsSeenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Marks the headlines as seen.
  void markSeen() => state = true;
}

/// Whether headlines were seen this session.
final NotifierProvider<NewsSeenNotifier, bool> newsSeenProvider =
    NotifierProvider<NewsSeenNotifier, bool>(NewsSeenNotifier.new);

/// Recorded net worth points, oldest first (FR-16-05).
@riverpod
Stream<List<WorthPoint>> netWorthPoints(Ref ref) =>
    ref.watch(netWorthRepositoryProvider).watchPoints();

/// Net worth exclusions (FR-16-14).
@riverpod
Stream<NetWorthFilter> netWorthFilter(Ref ref) =>
    ref.watch(netWorthPrefsRepositoryProvider).watch();

/// Deposits maturing within a year (FR-16-12).
@riverpod
Stream<List<MaturityItem>> maturities(Ref ref) async* {
  final db = ref.watch(appDatabaseProvider);
  await for (final accounts
      in ref.watch(accountRepositoryProvider).watchVisible()) {
    final rows = await db
        .customSelect(
          'SELECT id, maturity_day FROM accounts '
          'WHERE maturity_day IS NOT NULL',
        )
        .get();
    final days = {
      for (final r in rows) r.read<int>('id'): r.read<int>('maturity_day'),
    };
    final today = epochDayIst(DateTime.now().millisecondsSinceEpoch);
    yield maturityItems(accounts, days, today);
  }
}

/// Recorded fund purchases, newest first (FR-16-22).
@riverpod
Stream<List<MfOrderEntry>> mfOrders(Ref ref) =>
    ref.watch(holdingRepositoryProvider).watchMfOrders();

/// Latest investment rows: buys, redemptions, dividends (FR-16-25).
@riverpod
Stream<List<LedgerTx>> investmentTxs(Ref ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return combineLatest<List<LedgerTx>>(
    [
      repo.watch(const LedgerFilter(kind: TxKind.investments), limit: 60),
      repo.watch(const LedgerFilter(category: Category.investment), limit: 60),
    ],
    (v) {
      final byId = <int, LedgerTx>{
        for (final l in v)
          for (final t in l! as List<LedgerTx>)
            if (isInvestmentTx(t)) t.id: t,
      };
      return byId.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    },
  );
}

/// Optional AMFI NAV refresh (FR-16-23, FR-16-24). Off by default.
@Riverpod(keepAlive: true)
NavRefreshService navRefreshService(Ref ref) => NavRefreshService(
      holdings: ref.watch(holdingRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
      source: const AmfiNavSource(),
      parse: parseNavInIsolate,
    );

bool _deduped = false;

/// Dedupes holdings once per run and records today's net worth point
/// (FR-16-05, FR-16-18). Call at launch and on resume. Never throws.
@Riverpod(keepAlive: true)
Future<void> Function() portfolioSync(Ref ref) => () async {
      try {
        if (!_deduped) {
          _deduped = true;
          await ref.read(holdingRepositoryProvider).dedupe();
        }
        await ref.read(navRefreshServiceProvider).refresh();
        await ref.read(netWorthServiceProvider).recordToday(
              epochDayIst(DateTime.now().millisecondsSinceEpoch),
            );
      } on Object {
        // Database not ready (tests).
      }
    };

/// Saved profile (F-27).
@riverpod
Future<UserProfile> profileData(Ref ref) =>
    ref.watch(profileRepositoryProvider).read();

/// Sealed identity (F-27).
@riverpod
Future<Identity?> identityData(Ref ref) =>
    ref.watch(identityRepositoryProvider).read();

/// Number of saved statement passwords (FR-27-15 hint).
@riverpod
Future<int> savedPasswordCount(Ref ref) async =>
    (await ref.watch(savedPasswordRepositoryProvider).list()).length;

/// Saved per-account unlock details.
@riverpod
Future<List<BankIdentity>> bankIdentities(Ref ref) =>
    ref.watch(bankIdentityRepositoryProvider).readAll();
