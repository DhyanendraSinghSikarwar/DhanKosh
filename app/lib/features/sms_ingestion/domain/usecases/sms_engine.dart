import 'dart:async';

import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/handle_live_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/usecases/scan_sms.dart';

/// Live SMS lifecycle: configure the native receiver, drain what queued while
/// Dart was away, stream new messages, 14-day catch-up (FR-02-01, FR-02-05,
/// FR-02-06, FR-02-08).
class SmsEngine {
  /// Creates the engine.
  SmsEngine({
    required SmsLiveSource live,
    required SmsSettingsRepository settings,
    required HandleLiveSms handle,
    required ScanSms Function() scan,
    required this.senderPattern,
  })  : _live = live,
        _settings = settings,
        _handle = handle,
        _scan = scan;

  final SmsLiveSource _live;
  final SmsSettingsRepository _settings;
  final HandleLiveSms _handle;
  final ScanSms Function() _scan;

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
      await configure();
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
    } on Object {
      // Native side missing.
    }
  }

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
