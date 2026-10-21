import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ids.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';

const int _day = Duration.millisecondsPerDay;
final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1760000000000);
final int _nowMs = _now.millisecondsSinceEpoch;

class FakeSettings implements SmsSettingsRepository {
  FakeSettings({this.settings = const SmsSettings()});
  SmsSettings settings;
  @override
  Future<SmsSettings> read() async => settings;
  @override
  Future<void> setEnabled({required bool enabled}) async {}
  @override
  Future<void> saveScan({
    required int cursor,
    required int lastScanAt,
    required String lastResult,
  }) async {
    settings = SmsSettings(
      enabled: settings.enabled,
      cursor: cursor > settings.cursor ? cursor : settings.cursor,
      lastScanAt: lastScanAt,
      lastResult: lastResult,
      lookbackDays: settings.lookbackDays,
    );
  }

  @override
  Future<void> setPromptDismissed({required bool dismissed}) async {}
  @override
  Future<void> setLookbackDays(int days) async {}
}

class FakeInbox implements SmsInboxSource {
  FakeInbox(this.rows, {this.denied = false});
  final List<InboxSms> rows;
  final bool denied;
  int? lastSince;
  final rejectedBodiesPassed = <String>[];

  @override
  Future<SmsReadStats> readBatches({
    required int since,
    required int batchSize,
    required bool Function(String sender) accept,
    required Future<void> Function(List<InboxSms> batch) onBatch,
  }) async {
    if (denied) throw const PermissionFailure('no');
    lastSince = since;
    final inWindow = rows.where((r) => r.receivedAt > since).toList();
    final ok = inWindow.where((r) => accept(r.sender)).toList();
    for (var i = 0; i < ok.length; i += batchSize) {
      await onBatch(ok.sublist(i, (i + batchSize).clamp(0, ok.length)));
    }
    return SmsReadStats(
      examined: inWindow.length,
      lastTimestamp: inWindow.isEmpty ? 0 : inWindow.last.receivedAt,
    );
  }
}

InboxSms sms(String sender, int at, [String body = 'Rs.250 debited']) =>
    InboxSms(sender: sender, body: '$body $at', receivedAt: at);

ScanSms build(
  FakeInbox inbox,
  FakeSettings settings,
  List<InboxSms> ingested, {
  List<String>? activity,
  IngestOutcome Function(InboxSms)? outcome,
}) =>
    ScanSms(
      inbox: inbox,
      settings: settings,
      accept: (s) => s.contains('BK') || s.contains('UPI'),
      ingest: (m) async {
        ingested.add(m);
        return outcome?.call(m) ?? IngestOutcome.inserted;
      },
      now: () => _now,
      recordActivity: (m) async => activity?.add(m),
    );

void main() {
  test('SmsIds golden: sha256 abc and upper-case equivalence (TC-02-03)', () {
    final d = SmsIds.sha256(Uint8List.fromList('abc'.codeUnits));
    final hex = d.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(
      hex,
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    final a = SmsIds.of('vm-hdfcbk-s', 1760000000000, 'x');
    expect(a, SmsIds.of('VM-HDFCBK-S', 1760000000000, 'x'));
    expect(a.length, 36);
    expect(a, startsWith('sms:'));
  });

  group('windowStart (TC-02-06, FR-02-08)', () {
    int w(SmsScanRequest r, int cursor) => ScanSms.windowStart(
          request: r,
          cursor: cursor,
          nowMs: _nowMs,
          lookbackDays: 90,
        );
    test('full ignores cursor', () {
      expect(w(const SmsScanRequest.full(), _nowMs), _nowMs - 90 * _day);
    });
    test('recent 14 with newer cursor gives now-14d', () {
      expect(
        w(const SmsScanRequest.recent(14), _nowMs - _day),
        _nowMs - 14 * _day,
      );
    });
    test('recent 14 with older cursor keeps the cursor', () {
      expect(
        w(const SmsScanRequest.recent(14), _nowMs - 30 * _day),
        _nowMs - 30 * _day,
      );
    });
    test('incremental uses cursor, first run uses look-back', () {
      expect(w(const SmsScanRequest(), 123), 123);
      expect(w(const SmsScanRequest(), 0), _nowMs - 90 * _day);
    });
  });

  test('counts, summary, cursor and activity (FR-02-11, TC-02-09)', () async {
    final rows = [
      sms('VM-HDFCBK-S', _nowMs - 3000),
      sms('VM-AMAZON', _nowMs - 2000),
      sms('AD-SBIUPI-S', _nowMs - 1000),
    ];
    final settings = FakeSettings();
    final ingested = <InboxSms>[];
    final activity = <String>[];
    final r = await build(
      FakeInbox(rows),
      settings,
      ingested,
      activity: activity,
      outcome: (m) => m.sender.contains('SBI')
          ? IngestOutcome.merged
          : IngestOutcome.inserted,
    )(const SmsScanRequest.full());
    expect(ingested.map((m) => m.sender), ['VM-HDFCBK-S', 'AD-SBIUPI-S']);
    expect(r.checked, 3);
    expect(r.bankMessages, 2);
    expect(r.inserted, 1);
    expect(r.merged, 1);
    expect(r.changed, isTrue);
    expect(r.cursor, _nowMs - 1000);
    expect(settings.settings.cursor, _nowMs - 1000);
    expect(settings.settings.lastResult, r.summary);
    expect(
      r.summary,
      '3 SMS checked, 2 from banks, 1 new, 1 merged, 0 to review (0.0s)',
    );
    expect(activity.single, r.summary);
    expect(activity.single, isNot(contains('Rs.250')));
  });

  test('summary format is exact', () {
    expect(
      SmsScanResult.formatSummary(
        checked: 1200,
        bankMessages: 1050,
        inserted: 120,
        merged: 40,
        flagged: 3,
        millis: 1400,
      ),
      '1200 SMS checked, 1050 from banks, 120 new, 40 merged, 3 to review (1.4s)',
    );
  });

  test('batches of 500 and rejected senders never ingested (TC-02-07)',
      () async {
    final rows = [
      for (var i = 1; i <= 1200; i++)
        sms(i % 8 == 0 ? 'VM-AMAZON' : 'VM-HDFCBK-S', _nowMs - 100000 + i),
    ];
    final sizes = <int>[];
    final inbox = FakeInbox(rows);
    final scan = ScanSms(
      inbox: _Spy(inbox, sizes),
      settings: FakeSettings(),
      accept: (s) => s.contains('BK'),
      ingest: (m) async {
        expect(m.sender, isNot('VM-AMAZON'));
        return IngestOutcome.inserted;
      },
      now: () => _now,
    );
    final r = await scan(const SmsScanRequest.full());
    expect(sizes, [500, 500, 50]);
    expect(r.bankMessages, 1050);
    expect(r.checked, 1200);
  });

  test('idempotent rescan reports skipped, cursor never decreases', () async {
    final rows = [sms('VM-HDFCBK-S', _nowMs - 1000)];
    final settings = FakeSettings();
    final seen = <String>{};
    IngestOutcome once(InboxSms m) =>
        seen.add(m.messageId) ? IngestOutcome.inserted : IngestOutcome.skipped;
    final scan = build(FakeInbox(rows), settings, [], outcome: once);
    final first = await scan(const SmsScanRequest.full());
    final second = await scan(const SmsScanRequest.full());
    expect(first.inserted, 1);
    expect(second.inserted, 0);
    expect(second.skipped, 1);
    expect(second.changed, isFalse);
    expect(settings.settings.cursor, _nowMs - 1000);
    // An older recent window cannot move the cursor back.
    settings.settings = SmsSettings(cursor: _nowMs, lastScanAt: 1);
    await build(FakeInbox(const []), settings, [])(
      const SmsScanRequest.recent(14),
    );
    expect(settings.settings.cursor, _nowMs);
  });

  test('recent(14) reads 14 days even with a newer cursor (AC-02-06)',
      () async {
    final inbox = FakeInbox(const []);
    await build(
      inbox,
      FakeSettings(settings: SmsSettings(cursor: _nowMs - _day)),
      [],
    )(const SmsScanRequest.recent(14));
    expect(inbox.lastSince, _nowMs - 14 * _day);
  });

  test('permission denied returns error, no throw (FR-02-12, TC-02-10)',
      () async {
    final activity = <String>[];
    final r = await build(
      FakeInbox(const [], denied: true),
      FakeSettings(),
      [],
      activity: activity,
    )(const SmsScanRequest());
    expect(r.error, 'permission');
    expect(activity, isNotEmpty);
  });

  test('ingest exception keeps cursor of completed work', () async {
    final rows = [
      sms('VM-HDFCBK-S', _nowMs - 2000),
      sms('VM-HDFCBK-S', _nowMs - 1000),
    ];
    final settings = FakeSettings();
    final scan = ScanSms(
      inbox: FakeInbox(rows),
      settings: settings,
      accept: (_) => true,
      ingest: (m) async => throw StateError('boom ${m.body}'),
      now: () => _now,
      batchSize: 1,
    );
    final r = await scan(const SmsScanRequest.full());
    expect(r.error, 'StateError');
    expect(r.summary, isNot(contains('boom')));
    expect(settings.settings.lastResult, 'StateError');
  });

  test('live handler is silent when paused (FR-02-05, TC-02-05)', () async {
    var calls = 0;
    HandleLiveSms h({required bool enabled}) => HandleLiveSms(
          settings: FakeSettings(settings: SmsSettings(enabled: enabled)),
          accept: (_) => true,
          ingest: (_) async {
            calls++;
            return IngestOutcome.inserted;
          },
        );
    expect(await h(enabled: false)(sms('VM-HDFCBK-S', 1)), isNull);
    expect(calls, 0);
    expect(
      await h(enabled: true)(sms('VM-HDFCBK-S', 1)),
      IngestOutcome.inserted,
    );
    expect(calls, 1);
  });
}

class _Spy implements SmsInboxSource {
  _Spy(this._inner, this.sizes);
  final SmsInboxSource _inner;
  final List<int> sizes;
  @override
  Future<SmsReadStats> readBatches({
    required int since,
    required int batchSize,
    required bool Function(String sender) accept,
    required Future<void> Function(List<InboxSms> batch) onBatch,
  }) =>
      _inner.readBatches(
        since: since,
        batchSize: batchSize,
        accept: accept,
        onBatch: (b) {
          sizes.add(b.length);
          return onBatch(b);
        },
      );
}
