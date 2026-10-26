import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';

/// Hosts the updater may download from (FR-31-21): GitHub and the CDN hosts
/// it redirects release assets to.
bool isAllowedUpdateHost(String host) {
  final h = host.toLowerCase();
  return h == 'github.com' ||
      h == 'objects.githubusercontent.com' ||
      h.endsWith('.githubusercontent.com');
}

/// True for an `https` URL on an allowed host, without credentials.
bool isAllowedUpdateUrl(Uri url) =>
    url.scheme == 'https' &&
    url.userInfo.isEmpty &&
    isAllowedUpdateHost(url.host);

/// Only a strictly newer version may be installed (FR-31-22).
bool mayInstall({required String candidate, required String installed}) =>
    isNewer(candidate, installed);

/// First 64-hex digest of a `.sha256` asset body, lower-case; null when the
/// text holds none (FR-31-21). Accepts `hex` and `hex  file`.
String? parseSha256File(String text) {
  final m = RegExp(r'^\s*([0-9a-fA-F]{64})(?![0-9a-fA-F])').firstMatch(text);
  return m?.group(1)?.toLowerCase();
}

/// What's new runs once after the installed version changed (FR-31-36);
/// a fresh install (nothing stored) only records the version.
bool shouldShowWhatsNew({required String lastSeen, required String current}) =>
    lastSeen.isNotEmpty && isNewer(current, lastSeen);

/// Generic line shown when no notes are cached or reachable.
String whatsNewFallback(String version) => 'DhanKosh updated to $version.';
