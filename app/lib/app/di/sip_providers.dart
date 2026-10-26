import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/recurring_transactions/data/sip_repository_impl.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip_detector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sip_providers.g.dart';

// SIP tracker (F-12, FR-12-17..20). Tracking only.

/// User SIPs (F-12).
@Riverpod(keepAlive: true)
SipRepository sipRepository(Ref ref) =>
    SipRepositoryImpl(ref.watch(appDatabaseProvider));

/// User SIPs, live (F-12).
@riverpod
Stream<List<SipItem>> sipItems(Ref ref) =>
    ref.watch(sipRepositoryProvider).watchAll();

/// Detected plus user SIPs from INVESTMENT rows and recorded MF orders
/// (FR-12-17..19). Embeddable on Home as a summary.
@riverpod
Future<List<Sip>> sips(Ref ref) async {
  final txs = await ref.watch(planWindowProvider.future);
  final orders = await ref.watch(mfOrdersProvider.future);
  final mine = await ref.watch(sipItemsProvider.future);
  final today = Ist.dateOf(DateTime.now().millisecondsSinceEpoch);
  final events = [
    ...SipDetector.eventsFromLedger(txs),
    for (final o in orders)
      if (o.amountMinor != null && o.amountMinor! > 0)
        SipEvent(
          name: o.schemeName,
          atMs: o.at,
          amountMinor: o.amountMinor!,
        ),
  ];
  return SipDetector.withManual(
    SipDetector.detect(events, today),
    mine,
    today,
  );
}
