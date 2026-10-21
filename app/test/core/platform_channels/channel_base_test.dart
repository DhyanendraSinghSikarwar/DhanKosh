import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/core/platform_channels/secure_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = SecureChannel.channel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('returns the native value', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => 'pong');
    expect(await const SecureChannel().invoke<String>('ping'), 'pong');
  });
  test('maps PlatformException to ChannelFailure', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'denied', message: 'no'),
    );
    await expectLater(
      const SecureChannel().invoke<String>('ping'),
      throwsA(isA<ChannelFailure>().having((f) => f.code, 'code', 'denied')),
    );
  });
  test('maps a missing handler to unavailable', () async {
    await expectLater(
      const SecureChannel().invoke<String>('ping'),
      throwsA(
        isA<ChannelFailure>().having((f) => f.code, 'code', 'unavailable'),
      ),
    );
  });
}
