import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/credit_cards/data/card_bill_debit_source_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_due_repository_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_flow_source_impl.dart';
import 'package:hisaab/features/credit_cards/data/card_paid_store_impl.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_actions.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_service.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/data/holding_repository_impl.dart';
import 'package:hisaab/features/portfolio/data/net_worth_repository_impl.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_repository.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_service.dart';
import 'package:hisaab/features/profile/data/bank_identity_store.dart';
import 'package:hisaab/features/profile/domain/bank_identity_repository.dart';
import 'package:hisaab/features/statement_import/data/statement_password_store.dart';
import 'package:hisaab/features/statement_import/data/statement_repository_impl.dart';
import 'package:hisaab/features/statement_import/domain/saved_password.dart';
import 'package:hisaab/features/statement_import/domain/statement_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'phase3_providers.g.dart';

// Phase 3 data-layer wiring (F-05, F-14, F-16, F-27). Presentation reads the
// domain interfaces only.

/// Statement rows (F-05).
@Riverpod(keepAlive: true)
StatementRepository statementRepository(Ref ref) =>
    StatementRepositoryImpl(ref.watch(appDatabaseProvider));

/// Sealed saved statement passwords (F-05).
@Riverpod(keepAlive: true)
SavedPasswordRepository savedPasswordRepository(Ref ref) =>
    StatementPasswordStore(ref.watch(secureStoreProvider));

/// Sealed per-account unlock details (F-27).
@Riverpod(keepAlive: true)
BankIdentityRepository bankIdentityRepository(Ref ref) =>
    BankIdentityStore(ref.watch(secureStoreProvider));

/// Holdings (F-16).
@Riverpod(keepAlive: true)
HoldingRepository holdingRepository(Ref ref) =>
    HoldingRepositoryImpl(ref.watch(appDatabaseProvider));

/// Net worth history points (F-16).
@Riverpod(keepAlive: true)
NetWorthRepository netWorthRepository(Ref ref) =>
    NetWorthRepositoryImpl(ref.watch(appDatabaseProvider));

/// Net worth exclusions (F-16).
@Riverpod(keepAlive: true)
NetWorthPrefsRepository netWorthPrefsRepository(Ref ref) =>
    NetWorthPrefsRepositoryImpl(ref.watch(settingsRepositoryProvider));

/// Card notices and overrides (F-14).
@Riverpod(keepAlive: true)
CardDueRepository cardDueRepository(Ref ref) =>
    CardDueRepositoryImpl(ref.watch(appDatabaseProvider));

/// Card paid marks (F-14).
@Riverpod(keepAlive: true)
CardPaidStore cardPaidStore(Ref ref) =>
    CardPaidStoreImpl(ref.watch(settingsRepositoryProvider));

/// Card figures from the ledger, notices and statements (F-14).
@Riverpod(keepAlive: true)
CardDueService cardDueService(Ref ref) => CardDueService(
      accounts: ref.watch(accountRepositoryProvider),
      dues: ref.watch(cardDueRepositoryProvider),
      statements: ref.watch(statementRepositoryProvider),
      flow: CardFlowSourceImpl(ref.watch(transactionRepositoryProvider)),
      paid: ref.watch(cardPaidStoreProvider),
      debits: CardBillDebitSourceImpl(ref.watch(transactionRepositoryProvider)),
    );

/// Mark paid and override edits (F-14).
@Riverpod(keepAlive: true)
CardDueActions cardDueActions(Ref ref) => CardDueActions(
      dues: ref.watch(cardDueRepositoryProvider),
      paid: ref.watch(cardPaidStoreProvider),
    );

/// Live credit cards (F-14).
@riverpod
Stream<List<CardLimit>> cardLimits(Ref ref) =>
    ref.watch(cardDueServiceProvider).watchCards();

/// Net worth service (F-16).
@Riverpod(keepAlive: true)
NetWorthService netWorthService(Ref ref) => NetWorthService(
      accounts: ref.watch(accountRepositoryProvider),
      holdings: ref.watch(holdingRepositoryProvider),
      cards: ref.watch(cardDueServiceProvider),
      prefs: ref.watch(netWorthPrefsRepositoryProvider),
      history: ref.watch(netWorthRepositoryProvider),
    );

/// Live net worth for all books (F-16).
@riverpod
Stream<NetWorth> netWorth(Ref ref) =>
    ref.watch(netWorthServiceProvider).watch();
