import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `widget` platform channel: external hand-offs
/// (browser, UPI chooser, APK page) for F-31. Widget data goes through the
/// `home_widget` plugin (F-30).
class WidgetChannel extends ChannelBase {
  /// Creates the wrapper over the `widget` channel.
  const WidgetChannel() : super(_channel);

  /// Opens [url] with `ACTION_VIEW`; with [chooser] shows the system chooser
  /// titled [chooserTitle]. False when no app can handle it.
  Future<bool> openUrl(
    String url, {
    bool chooser = false,
    String chooserTitle = 'Open with',
  }) async =>
      (await invoke<bool>('openUrl', {
        'url': url,
        'chooser': chooser,
        'chooserTitle': chooserTitle,
      })) ??
      false;

  /// The `widget` method channel.
  static const MethodChannel _channel = MethodChannel(ChannelNames.widget);
}
