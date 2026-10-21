import 'dart:convert';
import 'dart:io';

import 'package:hisaab/features/localization/domain/language.dart';

/// Documented pack base (memory 29 section 3.4, FR-29-06).
const defaultPackBase =
    'https://raw.githubusercontent.com/DhyanendraSinghSikarwar/hisaab_apk/main/lang';

/// HTTPS GET of `<base>/<code>.json`; sends nothing about the user
/// (FR-29-06, FR-29-14). Call only on explicit user action.
class LanguagePackRemoteImpl implements LanguagePackRemote {
  /// Creates the remote.
  LanguagePackRemoteImpl({this.base = defaultPackBase});

  /// Base URL.
  final String base;

  @override
  Future<String> fetch(Language l) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('$base/${l.code}.json'));
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode > 299) {
        await res.drain<void>();
        throw HttpException('HTTP ${res.statusCode}');
      }
      return await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }
}
