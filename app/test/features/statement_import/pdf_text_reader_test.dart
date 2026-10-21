import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/core/platform_channels/pdf_channel.dart';
import 'package:hisaab/features/statement_import/data/pdf_text_reader_impl.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hisaab/pdf');
  final calls = <Map<Object?, Object?>>[];

  void handler(Future<Object?> Function(MethodCall) f) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, f);

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  final bytes = Uint8List.fromList([1, 2, 3]);
  const reader = PdfTextReaderImpl(PdfChannel());

  // FR-05-02: channel contract and error mapping.
  test('extractText sends bytes and password, returns text', () async {
    handler((c) async {
      expect(c.method, 'extractText');
      calls.add(c.arguments as Map<Object?, Object?>);
      return {'text': 'hello', 'pages': 2};
    });
    expect(await reader.extractText(bytes, password: 'pw'), 'hello');
    expect(calls.single['password'], 'pw');
    expect(calls.single['bytes'], bytes);
  });

  test('native error codes map to PdfFailure', () async {
    for (final (code, want) in [
      ('password_required', PdfFailure.passwordRequired),
      ('wrong_password', PdfFailure.wrongPassword),
      ('scanned', PdfFailure.scanned),
      ('unreadable', PdfFailure.unreadable),
    ]) {
      handler((_) async => throw PlatformException(code: code));
      await expectLater(
        reader.extractText(bytes),
        throwsA(
          isA<PdfReadException>().having((e) => e.failure, 'failure', want),
        ),
      );
    }
  });
}
