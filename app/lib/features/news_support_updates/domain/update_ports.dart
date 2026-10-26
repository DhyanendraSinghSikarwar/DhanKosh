import 'package:hisaab/features/news_support_updates/domain/release.dart';

/// Updater failure with a user-visible [message] (FR-31-26).
class UpdateFailure implements Exception {
  /// Creates the failure.
  const UpdateFailure(this.message);

  /// User-visible text.
  final String message;

  @override
  String toString() => message;
}

/// Raised when the user cancels a download.
class UpdateCancelled implements Exception {
  /// Creates the marker.
  const UpdateCancelled();
}

/// Cancel flag shared between the UI and a running download (FR-31-20).
class UpdateCancel {
  bool _cancelled = false;

  /// Whether cancel was requested.
  bool get cancelled => _cancelled;

  /// Requests cancel.
  void cancel() => _cancelled = true;
}

/// All releases, newest first (FR-31-29). Throws on failure.
abstract interface class ReleaseHistorySource {
  /// Fetches up to 30 releases.
  Future<List<Release>> list();
}

/// One HTTP answer; redirects are never followed by the port.
abstract interface class UpdateHttpResponse {
  /// Status code.
  int get statusCode;

  /// `Location` header, when present.
  String? get location;

  /// Body length when known, else -1.
  int get contentLength;

  /// Body bytes.
  Stream<List<int>> get body;

  /// Releases the connection.
  void close();
}

/// Minimal anonymous GET for the downloader; fakeable in tests (FR-31-20).
abstract interface class UpdateHttp {
  /// GETs [url]; sends no body and no headers beyond User-Agent.
  Future<UpdateHttpResponse> get(Uri url);
}

/// Result of handing an APK to the system installer.
enum InstallHandoff {
  /// The package installer was opened.
  started,

  /// "Install unknown apps" is off; the settings page was opened.
  permissionNeeded,
}

/// Hands a verified APK to the package installer (FR-31-22). Throws
/// [UpdateFailure] when it cannot.
abstract interface class ApkInstaller {
  /// Starts the install of the file at [path].
  Future<InstallHandoff> install(String path);
}
