import 'package:hisaab/app/di/notification_providers.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/notification_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_providers.g.dart';

/// Switch and system access for the Data sources card (FR-04-16). Call
/// `refresh` on resume.
@riverpod
class NotificationStatus extends _$NotificationStatus {
  @override
  Future<NotificationSourceStatus> build() =>
      ref.read(notificationEngineProvider).status();

  /// Re-reads access (the user may have just granted it).
  Future<void> refresh() async =>
      state = AsyncData(await ref.read(notificationEngineProvider).status());

  /// Turns reading on or off. Turning on without system access opens the
  /// listener settings (FR-04-16).
  Future<void> setEnabled({required bool enabled}) async {
    final engine = ref.read(notificationEngineProvider);
    await engine.setEnabled(enabled: enabled);
    var s = await engine.status();
    state = AsyncData(s);
    if (enabled && !s.hasAccess) await engine.openAccessSettings();
    if (enabled) await engine.start();
    s = await engine.status();
    state = AsyncData(s);
  }

  /// Opens the system "Notification access" page.
  Future<void> openAccessSettings() =>
      ref.read(notificationEngineProvider).openAccessSettings();
}
