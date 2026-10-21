import 'dart:async';

import 'package:hisaab/app/di/phase3_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/identity.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/user_profile.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/maturity_items.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/profile/domain/bank_identity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'portfolio_providers.g.dart';

// Portfolio (F-16) and Profile (F-27) UI wiring.

/// Epoch day in IST for [ms].
int epochDayIst(int ms) => (ms + 19800000) ~/ 86400000;

/// Live holdings, largest first (FR-16-08).
@riverpod
Stream<List<Holding>> holdings(Ref ref) =>
    ref.watch(holdingRepositoryProvider).watch();

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
