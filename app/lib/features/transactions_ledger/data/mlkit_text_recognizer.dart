import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hisaab/features/transactions_ledger/domain/ocr_port.dart';

/// ML Kit Latin recognition, bundled model, fully offline (FR-08-12).
class MlkitTextRecognizer implements TextRecognizerPort {
  /// Creates the recognizer.
  const MlkitTextRecognizer();

  @override
  Future<String> recognize(String path) async {
    final recognizer = TextRecognizer();
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
