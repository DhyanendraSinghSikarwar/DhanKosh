import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:hisaab/features/portfolio/domain/nav_file.dart';
import 'package:hisaab/features/portfolio/domain/nav_refresh.dart';

/// Public AMFI NAV file (FR-16-23). A plain GET with no user data.
class AmfiNavSource implements NavSource {
  /// Creates the source.
  const AmfiNavSource({
    this.url = 'https://www.amfiindia.com/spages/NAVAll.txt',
  });

  /// File address.
  final String url;

  @override
  Future<String?> fetch() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      return await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 60));
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Parses in a background isolate (the file is a few MB).
Future<Map<String, NavQuote>> parseNavInIsolate(String text) =>
    Isolate.run(() => NavFileParser.parse(text));
