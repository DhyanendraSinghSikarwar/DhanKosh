import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `notifications` platform channel. No methods yet.
class NotificationsChannel extends ChannelBase {
  /// Creates the wrapper over the `notifications` channel.
  const NotificationsChannel() : super(channel);

  /// The `notifications` method channel.
  static const MethodChannel channel =
      MethodChannel(ChannelNames.notifications);
}
