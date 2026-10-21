import 'dart:async';

import 'package:hisaab/features/notification_ingestion/domain/entities/app_notification.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/handle_app_notification.dart';

/// On, Needs access or Off (FR-04-16).
enum NotificationState {
  /// Switch on and access granted.
  on,

  /// Switch on, access missing.
  needsAccess,

  /// Switch off.
  off,
}

/// Switch and access, as the card shows them.
class NotificationSourceStatus {
  /// Creates a status.
  const NotificationSourceStatus({
    this.enabled = false,
    this.hasAccess = false,
    this.sdkInt = 0,
  });

  /// `app_notifications`.
  final bool enabled;

  /// System notification access.
  final bool hasAccess;

  /// Android API level; 0 when unknown.
  final int sdkInt;

  /// Derived state.
  NotificationState get state => !enabled
      ? NotificationState.off
      : hasAccess
          ? NotificationState.on
          : NotificationState.needsAccess;

  /// Android 13+ sideloads may need "Allow restricted settings" (memory 04).
  bool get showRestrictedHint => sdkInt >= 33 && !hasAccess;
}

/// Notification lifecycle: configure native, drain what queued while Dart was
/// away, stream new ones (FR-04-01, FR-04-02, FR-04-16). Mirrors SmsEngine.
class NotificationEngine {
  /// Creates the engine.
  NotificationEngine({
    required NotificationSource source,
    required NotificationSettingsRepository settings,
    required HandleAppNotification handle,
    void Function(NotificationResult result)? onResult,
  })  : _source = source,
        _settings = settings,
        _handle = handle,
        _onResult = onResult;

  final NotificationSource _source;
  final NotificationSettingsRepository _settings;
  final HandleAppNotification _handle;
  final void Function(NotificationResult)? _onResult;

  StreamSubscription<AppNotification>? _sub;

  /// True while subscribed.
  bool get running => _sub != null;

  /// Call at launch and on resume. Never throws.
  Future<void> start() async {
    try {
      await configure();
      await _sub?.cancel();
      _sub = _source.live.listen(
        (n) => unawaited(_safe(n)),
        onError: (Object _) {},
      );
      await drain();
    } on Object {
      // Native side missing (tests, non-Android).
    }
  }

  /// Pushes switch and allow-list to native.
  Future<void> configure() async => await _source.configure(
        enabled: await _settings.isEnabled(),
        packages: PaymentApps.packages,
      );

  /// Ingests notifications queued natively. Never throws.
  Future<void> drain() async {
    try {
      for (final n in await _source.drainPending()) {
        await _safe(n);
      }
    } on Object {
      // Native side missing.
    }
  }

  /// Persists the switch and reconfigures native (FR-04-02).
  Future<void> setEnabled({required bool enabled}) async {
    await _settings.setEnabled(enabled: enabled);
    try {
      await configure();
    } on Object {
      // Native side missing.
    }
  }

  /// Current switch and access; never throws.
  Future<NotificationSourceStatus> status() async {
    final enabled = await _settings.isEnabled();
    try {
      return NotificationSourceStatus(
        enabled: enabled,
        hasAccess: await _source.hasAccess(),
        sdkInt: await _source.sdkInt(),
      );
    } on Object {
      return NotificationSourceStatus(enabled: enabled);
    }
  }

  /// Opens system settings; false when unavailable.
  Future<bool> openAccessSettings() async {
    try {
      await _source.openAccessSettings();
      return true;
    } on Object {
      return false;
    }
  }

  /// Stops listening.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _safe(AppNotification n) async {
    try {
      _onResult?.call(await _handle(n));
    } on Object {
      // One bad notification never stops the engine.
    }
  }
}
