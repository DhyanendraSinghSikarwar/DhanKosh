import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/ocr_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/ocr_port.dart';
import 'package:hisaab/features/transactions_ledger/domain/screenshot_fill.dart';
import 'package:hisaab/features/transactions_ledger/presentation/ocr_fill_card.dart';
import 'package:parser_core/parser_core.dart';

class _Ocr implements TextRecognizerPort {
  _Ocr(this.text);
  final String text;
  @override
  Future<String> recognize(String path) async => text;
}

class _Pick implements ScreenshotSource {
  @override
  Future<String?> pick() async => '/tmp/fake.png';
}

Account _acc(int id, String bank, String last4) => Account(
      id: id,
      bankName: bank,
      last4: last4,
      kind: AccountKind.account,
      createdAt: 0,
    );

const _text = 'Payment successful\n₹450.00\nPaid to Test Cafe\n'
    'UPI Ref No: 123456789012\nFrom Test Bank XX1234';

void main() {
  final now = DateTime(2026, 10, 27, 12).millisecondsSinceEpoch;

  test('FR-08-12 draft from fixture text, account guessed by last4', () {
    final svc = ScreenshotFillService(recognizer: _Ocr(_text), now: () => now);
    final fill = svc.fromText(_text, [_acc(1, 'Test Bank', '1234')]);
    expect(fill.found, isTrue);
    expect(fill.draft!.amountMinor, 45000);
    expect(fill.accountId, 1);
  });

  test('FR-08-12 no amount gives no draft; ambiguous account is not guessed',
      () {
    final svc = ScreenshotFillService(recognizer: _Ocr(''), now: () => now);
    expect(svc.fromText('hello world', const []).found, isFalse);
    final fill = svc.fromText(_text, [
      _acc(1, 'Test Bank', '1234'),
      _acc(2, 'Test Bank', '1234'),
    ]);
    expect(fill.accountId, isNull);
  });

  testWidgets('FR-08-12 card reads the picked image and calls onFill',
      (tester) async {
    ScreenshotFill? got;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          screenshotSourceProvider.overrideWithValue(_Pick()),
          textRecognizerProvider.overrideWithValue(_Ocr(_text)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OcrFillCard(accounts: const [], onFill: (f) => got = f),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ocr_fill')));
    await tester.pumpAndSettle();
    expect(got?.draft?.amountMinor, 45000);
    expect(
      find.textContaining('Filled in from the screenshot'),
      findsOneWidget,
    );
  });
}
