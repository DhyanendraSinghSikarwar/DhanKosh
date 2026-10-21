import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `sms` platform channel. No methods yet.
class SmsChannel extends ChannelBase {
  /// Creates the wrapper over the `sms` channel.
  const SmsChannel() : super(channel);

  /// The `sms` method channel.
  static const MethodChannel channel = MethodChannel(ChannelNames.sms);
}
