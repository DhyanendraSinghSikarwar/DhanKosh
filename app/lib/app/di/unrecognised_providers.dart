import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ids.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/unrecognised_messages/data/unrecognised_repository_impl.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_repository.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/add_from_unrecognised.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/offer_unrecognised.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/scan_missed_messages.dart';
import 'package:parser_core/parser_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unrecognised_providers.g.dart';

// F-38 wiring: the review queue, learned senders and the hooks that feed it.

/// The queue and learned senders in the encrypted database.
@Riverpod(keepAlive: true)
UnrecognisedRepository unrecognisedRepository(Ref ref) =>
    UnrecognisedRepositoryImpl(ref.watch(appDatabaseProvider));

/// Decides what is worth queueing.
@Riverpod(keepAlive: true)
OfferUnrecognised offerUnrecognised(Ref ref) =>
    OfferUnrecognised(ref.watch(unrecognisedRepositoryProvider));

/// Adds a queued message through the ledger.
@Riverpod(keepAlive: true)
AddFromUnrecognised addFromUnrecognised(Ref ref) => AddFromUnrecognised(
      queue: ref.watch(unrecognisedRepositoryProvider),
      ledger: ref.watch(transactionRepositoryProvider),
    );

/// Live SMS from a sender no parser accepts: queued only for senders the user
/// taught the app (FR-38-07).
@Riverpod(keepAlive: true)
Future<void> Function(InboxSms sms) liveSmsOffer(Ref ref) {
  final offer = ref.watch(offerUnrecognisedProvider);
  return (sms) async {
    final (result, id) = await offer.smsWithId(
      NewUnrecognised(
        source: UnrecognisedSource.sms,
        sender: sms.sender,
        sourceMessageId: sms.messageId,
        body: sms.body,
        receivedAt: sms.receivedAt,
      ),
      requireLearned: true,
    );
    if (result != OfferResult.queuedFromLearned || id == null) return;
    // FR-38-13: "Spent ₹X at Y?" for a sender the user taught the app.
    final s = GenericExtractor.read(sms.sender, sms.body);
    if (s == null) return;
    final d = AlertRules.learnedSenderAlert(
      messageId: id,
      amountMinor: s.amountMinor,
      currency: s.currency,
      isCredit: s.type == TransactionType.credit,
      who: s.merchant ?? sms.sender,
      settings: await ref.read(alertSettingsRepositoryProvider).read(),
    );
    if (d != null) await ref.read(alertPosterProvider).post(d);
  };
}

/// A watched app's notification the strict parser could not read (FR-38-06).
@Riverpod(keepAlive: true)
Future<void> Function(AppNotification n, PaymentApp app) notificationOffer(
  Ref ref,
) {
  final offer = ref.watch(offerUnrecognisedProvider);
  return (n, app) async {
    await offer.notification(
      NewUnrecognised(
        source: UnrecognisedSource.app,
        sender: app.displayName,
        sourceMessageId: NotificationIds.of(n),
        body: n.joinedText,
        receivedAt: n.postTime,
      ),
    );
  };
}

/// The user's own scan for messages no parser claims (FR-38-04).
@Riverpod(keepAlive: true)
ScanMissedMessages scanMissedMessages(Ref ref) => ScanMissedMessages(
      inbox: ref.watch(smsInboxSourceProvider),
      offer: ref.watch(offerUnrecognisedProvider),
      knownSender: ref.watch(ingestMessageProvider).accepts,
    );
