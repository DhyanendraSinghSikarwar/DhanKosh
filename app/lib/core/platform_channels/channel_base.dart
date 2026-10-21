import 'package:flutter/services.dart';
import 'package:hisaab/core/errors/failure.dart';

/// Base for typed wrappers around a Kotlin platform channel.
///
/// Maps native errors to [ChannelFailure] so callers never see
/// [PlatformException].
abstract class ChannelBase {
  /// Wraps [channel].
  const ChannelBase(this.channel);

  /// The underlying method channel.
  final MethodChannel channel;

  /// Invokes [method]; throws [ChannelFailure] on native error or no handler.
  Future<T?> invoke<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw ChannelFailure(e.code, e.message ?? 'Native call failed');
    } on MissingPluginException {
      throw const ChannelFailure('unavailable', 'Native side not available');
    }
  }
}
