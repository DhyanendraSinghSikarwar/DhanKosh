import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/features/transactions_ledger/data/file_picker_screenshot_source.dart';
import 'package:hisaab/features/transactions_ledger/data/mlkit_text_recognizer.dart';
import 'package:hisaab/features/transactions_ledger/domain/ocr_port.dart';
import 'package:hisaab/features/transactions_ledger/domain/screenshot_fill.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ocr_providers.g.dart';

// F-08 screenshot fill wiring; override both ports in tests.

/// Image chooser for the screenshot fill.
@Riverpod(keepAlive: true)
ScreenshotSource screenshotSource(Ref ref) => FilePickerScreenshotSource(
      lockSkipper: ref.watch(lockSkipperProvider),
    );

/// Reads a screenshot into a draft.
@Riverpod(keepAlive: true)
ScreenshotFillService screenshotFillService(Ref ref) => ScreenshotFillService(
      recognizer: ref.watch(textRecognizerProvider),
    );

/// The OCR port, overridable.
@Riverpod(keepAlive: true)
TextRecognizerPort textRecognizer(Ref ref) => const MlkitTextRecognizer();
