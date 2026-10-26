import 'package:hisaab/core/platform_channels/alerts_channel.dart';
import 'package:hisaab/features/security_privacy/domain/screen_guard.dart';

/// [ScreenGuard] over the Kotlin FLAG_SECURE call (FR-25-23).
class ChannelScreenGuard implements ScreenGuard {
  /// Creates the guard.
  const ChannelScreenGuard([this._channel = const AlertsChannel()]);

  final AlertsChannel _channel;

  @override
  Future<void> setBlocked({required bool blocked}) async {
    try {
      await _channel.setSecure(on: blocked);
    } on Object {
      // No native side (tests, headless): nothing to block.
    }
  }
}
