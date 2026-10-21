import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/core/platform_channels/permissions_channel.dart';
import 'package:hisaab/core/platform_channels/sms_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const sms = SmsChannel();
  const perms = PermissionsChannel();

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(sms.channel, null)
      ..setMockMethodCallHandler(perms.channel, null);
  });

  test('readInbox sends args and parses a page', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(sms.channel, (call) async {
      seen = call;
      return <String, Object?>{
        'items': [
          {
            'id': '7',
            'sender': 'VM-HDFCBK-S',
            'body': 'Sent Rs.250',
            'timestamp': 1760000000000,
            'sentTimestamp': 1759999999000,
          },
        ],
        'examined': 3,
        'nextSince': 1760000000000,
        'nextAfterId': 7,
        'done': false,
      };
    });
    final page = await sms.readInbox(sinceMillis: 5, limit: 2);
    expect(seen!.method, 'readInbox');
    expect(seen!.arguments, {'sinceMillis': 5, 'limit': 2});
    expect(page.items.single.sender, 'VM-HDFCBK-S');
    expect(page.examined, 3);
    expect(page.done, isFalse);
  });

  test('permission error maps to ChannelFailure(permission)', () async {
    messenger.setMockMethodCallHandler(
      sms.channel,
      (_) async => throw PlatformException(code: 'permission'),
    );
    await expectLater(
      sms.readInbox(sinceMillis: 0),
      throwsA(
        isA<ChannelFailure>().having((f) => f.code, 'code', 'permission'),
      ),
    );
  });

  test('drainPending, hasPermission, configureLive', () async {
    messenger.setMockMethodCallHandler(sms.channel, (call) async {
      switch (call.method) {
        case 'drainPending':
          return [
            {'id': '', 'sender': 'AX-SBIUPI', 'body': 'b', 'timestamp': 1},
          ];
        case 'hasPermission':
          return true;
        default:
          return null;
      }
    });
    expect((await sms.drainPending()).single.sender, 'AX-SBIUPI');
    expect(await sms.hasPermission(), isTrue);
    await sms.configureLive(enabled: true, senderPattern: 'BK');
  });

  test('permissions channel snapshot', () async {
    messenger.setMockMethodCallHandler(
      perms.channel,
      (_) async => {'granted': false, 'rationale': true},
    );
    final s = await perms.smsStatus();
    expect(s.granted, isFalse);
    expect(s.rationale, isTrue);
  });
}
