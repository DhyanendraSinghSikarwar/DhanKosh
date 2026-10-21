import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `widget` platform channel. No methods yet.
class WidgetChannel extends ChannelBase {
  /// Creates the wrapper over the `widget` channel.
  const WidgetChannel() : super(channel);

  /// The `widget` method channel.
  static const MethodChannel channel = MethodChannel(ChannelNames.widget);
}
