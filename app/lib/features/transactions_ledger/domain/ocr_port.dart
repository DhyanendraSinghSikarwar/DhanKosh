/// On-device text recognition of an image (FR-08-12). The only
/// implementation reads the image locally; nothing leaves the device.
abstract interface class TextRecognizerPort {
  /// Text found in the image at [path]; empty when none. Throws on an
  /// unreadable image.
  Future<String> recognize(String path);
}

/// Lets the user choose a screenshot (FR-08-12).
abstract interface class ScreenshotSource {
  /// Local path of the chosen image, or null when cancelled.
  Future<String?> pick();
}
