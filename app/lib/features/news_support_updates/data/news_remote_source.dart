import 'dart:convert';
import 'dart:io';

import 'package:hisaab/features/news_support_updates/domain/news.dart';

/// Fetches and parses one RSS feed (FR-31-02). Anonymous GET with a fixed
/// User-Agent; throws on any failure.
Future<List<Headline>> fetchFeed(FeedSource feed) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(Uri.parse(feed.url));
    req.headers
        .set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Android) DhanKosh');
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode > 299) {
      await res.drain<void>();
      throw Exception('HTTP ${res.statusCode}');
    }
    final body = await res.transform(utf8.decoder).join();
    return parseRss(body, feed.source);
  } finally {
    client.close(force: true);
  }
}

/// Loads every feed of [tab] in parallel, skipping failures; throws when all
/// fail (FR-31-02, FR-31-04).
Future<List<Headline>> loadNews(NewsFeed tab) async {
  final feeds = newsFeeds[tab]!;
  var failed = 0;
  final lists = await Future.wait(
    feeds.map((f) async {
      try {
        return await fetchFeed(f);
      } on Object {
        failed++;
        return <Headline>[];
      }
    }),
  );
  if (failed == feeds.length) throw Exception('No feed reachable');
  return mergeHeadlines(lists.expand((l) => l));
}
