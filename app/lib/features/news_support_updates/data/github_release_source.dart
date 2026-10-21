import 'dart:convert';
import 'dart:io';

import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_checker.dart';

/// Repository the updater reads (public, anonymous GET).
const releaseRepo = 'DhyanendraSinghSikarwar/DhanKosh';

/// [ReleaseSource] over the GitHub releases API (FR-31-15). Sends no
/// identifiers: no cookies, no body, only the Accept header.
class GithubReleaseSource implements ReleaseSource {
  /// Creates the source.
  const GithubReleaseSource({this.repo = releaseRepo});

  /// `owner/name`.
  final String repo;

  @override
  Future<Release?> latest() async {
    final client = HttpClient()
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
}
