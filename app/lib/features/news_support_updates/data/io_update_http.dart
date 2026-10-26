import 'dart:io';

import 'package:hisaab/features/news_support_updates/domain/update_ports.dart';

/// [UpdateHttp] over `dart:io`: anonymous GET, User-Agent only, redirects
/// left to the caller, 15 s connect and 30 s response timeouts (FR-31-20).
class IoUpdateHttp implements UpdateHttp {
  /// Creates the client.
  const IoUpdateHttp();

  @override
  Future<UpdateHttpResponse> get(Uri url) async {
    final client = HttpClient()
      ..userAgent = 'DhanKosh'
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(url);
      req.followRedirects = false;
      final res = await req.close().timeout(const Duration(seconds: 30));
      return _IoResponse(res, client);
    } on Object {
      client.close(force: true);
      rethrow;
    }
  }
}

class _IoResponse implements UpdateHttpResponse {
  _IoResponse(this._res, this._client);

  final HttpClientResponse _res;
  final HttpClient _client;

  @override
  int get statusCode => _res.statusCode;

  @override
  String? get location => _res.headers.value(HttpHeaders.locationHeader);

  @override
  int get contentLength => _res.contentLength;

  @override
  Stream<List<int>> get body => _res.timeout(const Duration(seconds: 30));

  @override
  void close() => _client.close(force: true);
}
