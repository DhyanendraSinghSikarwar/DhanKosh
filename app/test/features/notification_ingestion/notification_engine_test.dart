import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/notification_ingestion/data/notification_settings_store.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ids.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/handle_app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/notification_engine.dart';
import 'package:hisaab/features/settings_data_sources/data/settings_key_value_store.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/ingest_message.dart';

import '../../support/test_env.dart';

class FakeNotificationSource implements NotificationSource {
  final pending = <AppNotification>[];
  final controller = StreamController<AppNotification>.broadcast();
  bool access = true;
  int sdk = 34;
  int opened = 0;
  bool? enabled;
  List<String>? packages;
  bool unavailable = false;

  @override
  Stream<AppNotification> get live => controller.stream;
  @override
  Future<List<AppNotification>> drainPending() async {
    if (unavailable) throw StateError('no native');
    final out = [...pending];
    pending.clear();
    return out;
  }

  @override
  Future<bool> hasAccess() async => access;
  @override
  Future<int> sdkInt() async => sdk;
  @override
  Future<void> openAccessSettings() async => opened++;
  @override
  Future<void> configure({
    required bool enabled,
    required List<String> packages,
  }) async {
    if (unavailable) throw StateError('no native');
    this.enabled = enabled;
    this.packages = packages;
  }
}

void main() {
  late TestEnv env;
  late FakeNotificationSource source;
  late NotificationSettingsStore settings;
  late NotificationEngine engine;
  late HandleAppNotification handle;
  final results = <NotificationResult>[];
  final t = DateTime.now().millisecondsSinceEpoch - 60000;

  AppNotification pay({
    String pkg = 'com.phonepe.app',
    String key = 'k1',
    List<String> parts = const [
      'Payment successful',
      '₹250 paid to Ravi Kumar',
    ],
    bool summary = false,
    bool ongoing = false,
    String? category,
    bool messages = false,
    String? channel,
  }) =>
      AppNotification(
        packageName: pkg,
        key: key,
        postTime: t,
        parts: parts,
        isGroupSummary: summary,
        isOngoing: ongoing,
        category: category,
        hasMessagesExtra: messages,
        channelId: channel,
      );

  setUp(() async {
    results.clear();
    env = TestEnv();
    source = FakeNotificationSource();
    settings = NotificationSettingsStore(SettingsKeyValueStore(env.settings));
    handle = HandleAppNotification(
      settings: settings,
      ingest: IngestMessage(ledger: env.txs),
    );
    engine = NotificationEngine(
      source: source,
      settings: settings,
      handle: handle,
      onResult: results.add,
    );
  });
  tearDown(() async {
    await engine.stop();
    await env.close();
  });

  test('start pushes switch and 20 packages (FR-04-01, FR-04-02)', () async {
    await engine.start();
    expect(source.enabled, isFalse);
    expect(source.packages, hasLength(20));
    expect(source.packages, contains('com.phonepe.app'));
    expect(engine.running, isTrue);
  });

  test('disabled setting ingests nothing (FR-04-02)', () async {
    source.pending.add(pay());
    await engine.start();
    expect(await env.count('transactions'), 0);
    expect(results.single.skip, NotificationSkip.settingOff);
  });

  test('enabled: drained notification becomes an APP row (FR-04-08, 11)',
      () async {
    await engine.setEnabled(enabled: true);
    source.pending.add(pay());
    await engine.start();
    expect(source.enabled, isTrue);
    expect(await env.count('transactions'), 1);
    expect(results.single.outcome, IngestOutcome.inserted);
  });

  test('repeat post of the same notification is a no-op (FR-04-10)', () async {
    await engine.setEnabled(enabled: true);
    source.pending
      ..add(pay())
      ..add(pay());
    await engine.start();
    expect(await env.count('transactions'), 1);
    expect(results.map((r) => r.outcome), [
      IngestOutcome.inserted,
      IngestOutcome.skipped,
    ]);
    // live path, same key and text again
    source.controller.add(pay());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await env.count('transactions'), 1);
  });

  test('id depends on package, key and text only (FR-04-10)', () {
    final a = NotificationIds.of(pay());
    expect(a, startsWith('app:'));
    expect(a.length, 4 + 32);
    expect(NotificationIds.of(pay()), a);
    expect(NotificationIds.of(pay(key: 'k2')), isNot(a));
    expect(NotificationIds.of(pay(pkg: 'net.one97.paytm')), isNot(a));
  });

  test('live stream is ingested while running (FR-04-01)', () async {
    await engine.setEnabled(enabled: true);
    await engine.start();
    source.controller.add(pay(key: 'live'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await env.count('transactions'), 1);
  });

  test('unlisted package, summary and ongoing are ignored (FR-04-01, 03)',
      () async {
    await settings.setEnabled(enabled: true);
    expect(
      (await handle(pay(pkg: 'com.example.shop'))).skip,
      NotificationSkip.notWatched,
    );
    expect(
      (await handle(pay(summary: true))).skip,
      NotificationSkip.ignoredKind,
    );
    expect(
      (await handle(pay(ongoing: true))).skip,
      NotificationSkip.ignoredKind,
    );
    expect(await env.count('transactions'), 0);
  });

  test('WhatsApp chats are never read, payments are (FR-04-05)', () async {
    await settings.setEnabled(enabled: true);
    const chat = ['Ravi', 'Dinner at 8 tonight?'];
    expect(
      (await handle(pay(pkg: 'com.whatsapp', parts: chat))).skip,
      NotificationSkip.chat,
    );
    const money = ['You paid ₹250 to Ravi Kumar'];
    expect(
      (await handle(pay(pkg: 'com.whatsapp', parts: money, category: 'msg')))
          .skip,
      NotificationSkip.chat,
    );
    expect(
      (await handle(pay(pkg: 'com.whatsapp', parts: money, messages: true)))
          .skip,
      NotificationSkip.chat,
    );
    expect(
      (await handle(pay(pkg: 'com.whatsapp', parts: money, channel: 'chats')))
          .skip,
      NotificationSkip.chat,
    );
    final ok = await handle(pay(pkg: 'com.whatsapp', parts: money));
    expect(ok.outcome, IngestOutcome.inserted);
  });

  test('non-payment text keeps only a generic reason (FR-04-06, 17)', () async {
    await settings.setEnabled(enabled: true);
    final r = await handle(
      pay(parts: ['Payment failed', '₹250 to Ravi Kumar could not be paid']),
    );
    expect(r.skip, NotificationSkip.parser);
    expect(r.reason, 'failed or pending payment');
    expect(await env.count('transactions'), 0);
  });

  test('status: On, Needs access, Off and restricted hint (FR-04-16)',
      () async {
    expect((await engine.status()).state, NotificationState.off);
    await engine.setEnabled(enabled: true);
    source.access = false;
    final s = await engine.status();
    expect(s.state, NotificationState.needsAccess);
    expect(s.showRestrictedHint, isTrue);
    source.sdk = 30;
    expect((await engine.status()).showRestrictedHint, isFalse);
    source.access = true;
    expect((await engine.status()).state, NotificationState.on);
  });

  test('missing native side never throws', () async {
    source.unavailable = true;
    await engine.start();
    await engine.setEnabled(enabled: true);
    await engine.drain();
    expect(await settings.isEnabled(), isTrue);
  });

  test('allow-list has 20 packages, 19 apps (FR-04-01)', () {
    expect(PaymentApps.all, hasLength(20));
    expect(PaymentApps.displayNames, hasLength(19));
  });
}
