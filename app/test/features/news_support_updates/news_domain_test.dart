import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/news_support_updates/domain/news.dart';

const _rss = '''
<rss><channel>
<item><title><![CDATA[Sensex &amp; Nifty <b>rise</b>]]></title><link>https://n.test/a</link><pubDate>Tue, 21 Oct 2026 10:00:00 +0530</pubDate></item>
<item><title>Older story</title><link>https://n.test/b</link><pubDate>Mon, 20 Oct 2026 04:30:00 GMT</pubDate></item>
<item><title>No link</title></item>
<item><title>Sensex &amp; Nifty RISE!</title><link>https://n.test/dup</link><pubDate>Tue, 21 Oct 2026 04:00:00 GMT</pubDate></item>
<item><title>Undated</title><link>https://n.test/c</link><pubDate>garbage</pubDate></item>
</channel></rss>''';

void main() {
  test('FR-31-03 parseRss cleans titles, drops incomplete items', () {
    final h = parseRss(_rss, 'Test');
    expect(h.map((e) => e.title), [
      'Sensex & Nifty rise',
      'Older story',
      'Sensex & Nifty RISE!',
      'Undated',
    ]);
    expect(h.first.published, DateTime.utc(2026, 10, 21, 4, 30));
    expect(h.last.published, isNull);
  });

  test('FR-31-04 merge: newest first, null last, dedupe, cap', () {
    final merged = mergeHeadlines(parseRss(_rss, 'Test'));
    expect(merged.map((e) => e.link), [
      'https://n.test/a',
      'https://n.test/b',
      'https://n.test/c',
    ]);
    final many = [
      for (var i = 0; i < 250; i++)
        Headline(title: 't$i', link: 'l$i', source: 's'),
    ];
    expect(mergeHeadlines(many), hasLength(200));
  });

  test('FR-31-07 ageText', () {
    final now = DateTime.utc(2026, 10, 21, 12);
    String a(Duration d) => ageText(now.subtract(d), now);
    expect(a(const Duration(seconds: 30)), 'just now');
    expect(a(const Duration(minutes: 5)), '5m ago');
    expect(a(const Duration(hours: 3)), '3h ago');
    expect(a(const Duration(days: 2)), '2d ago');
    expect(ageText(null, now), '');
  });

  test('FR-31-01 four tabs, default Latest', () {
    expect(NewsFeed.values.first, NewsFeed.latest);
    expect(newsFeeds.keys.toSet(), NewsFeed.values.toSet());
    expect(newsFeeds[NewsFeed.latest], hasLength(4));
    expect(
      newsFeeds.values
          .expand((e) => e)
          .every((f) => f.url.startsWith('https://')),
      isTrue,
    );
  });
}
