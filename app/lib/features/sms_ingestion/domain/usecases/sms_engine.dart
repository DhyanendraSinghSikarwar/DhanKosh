import 'dart:async';

import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';

/// Live SMS lifecycle: configure the native receiver, drain what queued while
/// Dart was away, stream new messages, 14-day catch-up (FR-02-01, FR-02-05,
/// FR-02-13, FR-02-08).
class SmsEngine {
  /// Creates the engine.
  SmsEngine({
    required SmsLiveSource live,
    required SmsSettingsRepository settings,
    required HandleLiveSms handle,
    required ScanSms Function() scan,
    required this.senderPattern,
    SmsScanScheduler? scheduler,
    Future<void> Function()? prepare,
  })  : _live = live,
        _prepare = prepare,
        _settings = settings,
        _handle = handle,
        _scan = scan,
        _scheduler = scheduler;

  final SmsLiveSource _live;
  final SmsSettingsRepository _settings;
  final HandleLiveSms _handle;
  final ScanSms Function() _scan;
  final SmsScanScheduler? _scheduler;
  final Future<void> Function()? _prepare;

  /// Case-insensitive address regex pushed to the native receiver.
  final String senderPattern;

  /// Any address containing a letter; the registry filters in Dart.
  static const senderPatternDefault = '.*[A-Za-z].*';

  StreamSubscription<InboxSms>? _sub;

  /// Catch-up window on every start, in days.
  static const catchUpDays = 14;

  /// True while subscribed to live messages.
  bool get running => _sub != null;

  /// Call once SMS access is granted (and again on every launch while it is).
  /// Never throws.
  Future<void> start() async {
    try {
      await _prepare?.call();
      await configure();
      await _safe(_syncSchedule);
      await _sub?.cancel();
      _sub = _live.live.listen(
        (m) => unawaited(_safe(() => _handle(m))),
        onError: (Object _) {},
      );
      await drain();
      await _safe(() => _scan()(const SmsScanRequest.recent(catchUpDays)));
    } on Object {
      // Native side missing (tests, non-Android): nothing to do.
    }
  }

  /// Pushes the pause flag and sender pattern to native.
  Future<void> configure() async {
    final s = await _settings.read();
    await _live.configure(enabled: s.enabled, senderPattern: senderPattern);
  }

  /// Ingests messages queued natively; call on start and on app resume.
  Future<void> drain() async {
    for (final m in await _live.drainPending()) {
      await _safe(() => _handle(m));
    }
  }

  /// Persists the toggle and reconfigures the receiver (FR-02-05).
  Future<void> setEnabled({required bool enabled}) async {
    await _settings.setEnabled(enabled: enabled);
    try {
      await configure();
      await _safe(_syncSchedule);
    } on Object {
      // Native side missing.
    }
  }

  /// Nightly job registered whether or not SMS reading is on (FR-02-14,
  /// FR-03-17): it also syncs every mailbox, and skips only the SMS part
  /// while reading is paused.
  Future<void> _syncSchedule() async {
    await _scheduler?.scheduleNightly();
  }

  /// Registers the nightly job on its own, for launches where SMS access was
  /// never granted. Never throws.
  Future<void> ensureNightly() => _safe(_syncSchedule);

  /// Stops listening.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _safe(Future<Object?> Function() f) async {
    try {
      await f();
    } on Object {
      // One bad message never stops the engine.
    }
  }
}
