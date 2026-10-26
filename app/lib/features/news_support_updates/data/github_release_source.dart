import 'dart:convert';
import 'dart:io';

import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_checker.dart';
import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';

/// [ReleaseSource] over the GitHub releases API (FR-31-15). Sends no
/// identifiers: no cookies, no body, only the Accept header.
class GithubReleaseSource implements ReleaseSource, ReleaseHistorySource {
  /// Creates the source.
  const GithubReleaseSource({this.repo = releaseRepo});

  /// `owner/name`.
  final String repo;

  @override
  Future<Release?> latest() async {
    final client = HttpClient()
      ..userAgent = 'DhanKosh'
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      );
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode == 404) {
        await res.drain<void>();
        return null;
      }
      if (res.statusCode < 200 || res.statusCode > 299) {
        await res.drain<void>();
        throw Exception('GitHub answered ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      return json is Map<String, Object?> ? parseRelease(json) : null;
    } finally {
      client.close(force: true);
    }
  }

  /// All releases, newest first (FR-31-29): anonymous GET, 10 s timeouts,
  /// Accept and User-Agent only.
  @override
  Future<List<Release>> list() async {
    final client = HttpClient()
      ..userAgent = 'DhanKosh'
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      const t = Duration(seconds: 10);
      final req = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$repo/releases?per_page=30'),
      );
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(t);
      if (res.statusCode < 200 || res.statusCode > 299) {
        await res.drain<void>();
        throw Exception('GitHub answered ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join().timeout(t);
      return parseReleaseHistory(jsonDecode(body));
    } finally {
      client.close(force: true);
    }
  }
}
