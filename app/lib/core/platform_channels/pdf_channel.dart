import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// Typed wrapper for the `pdf` platform channel. No methods yet.
class PdfChannel extends ChannelBase {
  /// Creates the wrapper over the `pdf` channel.
  const PdfChannel() : super(channel);

  /// The `pdf` method channel.
  static const MethodChannel channel = MethodChannel(ChannelNames.pdf);
}
