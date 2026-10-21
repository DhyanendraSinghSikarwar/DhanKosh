import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `secure` platform channel. No methods yet.
class SecureChannel extends ChannelBase {
  /// Creates the wrapper over the `secure` channel.
  const SecureChannel() : super(_channel);

  /// The `secure` method channel.
  static const MethodChannel _channel = MethodChannel(ChannelNames.secure);
}
