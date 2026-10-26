import 'package:flutter/services.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_models.dart';

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
      AppLog.instance.warn(
        LogCategory.channel,
        'channel.failed',
        fields: {'method': method, 'code': e.code},
      );
      throw ChannelFailure(e.code, e.message ?? 'Native call failed');
    } on MissingPluginException {
      AppLog.instance.warn(
        LogCategory.channel,
        'channel.unavailable',
        fields: {'method': method},
      );
      throw const ChannelFailure('unavailable', 'Native side not available');
    }
  }
}
