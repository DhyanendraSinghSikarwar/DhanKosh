/// News tabs (FR-31-01) with their feeds, in order.
enum NewsFeed {
  /// Default tab.
  latest('Latest'),

  /// Markets.
  markets('Markets'),

  /// Business.
  business('Business'),

  /// Stocks.
  stocks('Stocks');

  const NewsFeed(this.label);

  /// Tab label.
  final String label;
}

/// A feed URL and its publication name.
class FeedSource {
  /// Creates a source.
  const FeedSource(this.source, this.url);

  /// Publication.
  final String source;

  /// RSS URL.
  final String url;
}

/// Feed lists per tab (memory 31 section 3.1).
const newsFeeds = <NewsFeed, List<FeedSource>>{
  NewsFeed.latest: [
    FeedSource(
      'Business Standard',
      'https://www.business-standard.com/rss/latest.rss',
    ),
    FeedSource(
      'Economic Times',
      'https://economictimes.indiatimes.com/rssfeedsdefault.cms',
    ),
    FeedSource(
      'Moneycontrol',
      'https://www.moneycontrol.com/rss/latestnews.xml',
    ),
    FeedSource(
      'Moneycontrol',
      'https://www.moneycontrol.com/rss/MCtopnews.xml',
    ),
  ],
  NewsFeed.markets: [
    FeedSource(
      'Economic Times',
      'https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms',
    ),
    FeedSource(
      'Business Standard',
      'https://www.business-standard.com/rss/markets-106.rss',
    ),
    FeedSource('Mint', 'https://www.livemint.com/rss/markets'),
    FeedSource(
      'Moneycontrol',
      'https://www.moneycontrol.com/rss/marketreports.xml',
    ),
  ],
  NewsFeed.business: [
    FeedSource(
      'Business Standard',
      'https://www.business-standard.com/rss/companies-101.rss',
    ),
    FeedSource(
      'Business Standard',
      'https://www.business-standard.com/rss/economy-102.rss',
    ),
    FeedSource(
      'Economic Times',
      'https://economictimes.indiatimes.com/news/economy/rssfeeds/1373380680.cms',
    ),
    FeedSource('Moneycontrol', 'https://www.moneycontrol.com/rss/business.xml'),
  ],
  NewsFeed.stocks: [
    FeedSource(
      'Economic Times',
      'https://economictimes.indiatimes.com/markets/stocks/rssfeeds/2146842.cms',
    ),
    FeedSource(
      'Moneycontrol',
      'https://www.moneycontrol.com/rss/buzzingstocks.xml',
    ),
  ],
};

/// One headline.
class Headline {
  /// Creates a headline.
  const Headline({
    required this.title,
    required this.link,
    required this.source,
    this.published,
  });

  /// Cleaned title.
  final String title;

  /// Article URL.
  final String link;

  /// Publication.
  final String source;

  /// Publish time, null when unparsable.
  final DateTime? published;
}

String _text(String raw) {
  var s = raw.trim();
  final cdata = RegExp(r'^<!\[CDATA\[(.*?)\]\]>$', dotAll: true).firstMatch(s);
  if (cdata != null) s = cdata.group(1)!;
  return s.trim();
}

String _field(String item, String tag) {
  final m =
      RegExp('<$tag(?:\\s[^>]*)?>(.*?)</$tag>', dotAll: true).firstMatch(item);
  return m == null ? '' : _text(m.group(1)!);
}

/// Strips tags, decodes the five entities, collapses whitespace (FR-31-03).
String cleanTitle(String raw) => raw
    .replaceAll(RegExp('<[^>]+>'), '')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// RFC 1123 date such as `Tue, 21 Oct 2026 10:00:00 +0530`; null if bad.
DateTime? parseRfc1123(String s) {
  final m = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\w*\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|GMT|UTC|Z)?',
  ).firstMatch(s);
  if (m == null) return null;
  final month = _months[m.group(2)!.toLowerCase()];
  if (month == null) return null;
  var utc = DateTime.utc(
    int.parse(m.group(3)!),
    month,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6) ?? '0'),
  );
  final z = m.group(7);
  if (z != null && (z.startsWith('+') || z.startsWith('-'))) {
    final sign = z.startsWith('-') ? -1 : 1;
    final off = Duration(
      hours: int.parse(z.substring(1, 3)),
      minutes: int.parse(z.substring(3, 5)),
    );
    utc = sign > 0 ? utc.subtract(off) : utc.add(off);
  }
  return utc;
}

/// Parses RSS [xml] `item` entries for [source] (FR-31-03). Pure.
List<Headline> parseRss(String xml, String source) {
  final out = <Headline>[];
  for (final m in RegExp('<item[ >].*?</item>', dotAll: true).allMatches(xml)) {
    final item = m.group(0)!;
    final title = cleanTitle(_field(item, 'title'));
    final link = _field(item, 'link');
    if (title.isEmpty || link.isEmpty) continue;
    out.add(
      Headline(
        title: title,
        link: link,
        source: source,
        published: parseRfc1123(_field(item, 'pubDate')),
      ),
    );
  }
  return out;
}

String _norm(String t) =>
    t.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// Sorts newest first (null last), de-duplicates by link then normalised
/// title, caps at 200 (FR-31-04).
List<Headline> mergeHeadlines(Iterable<Headline> all) {
  final list = all.toList()
    ..sort((a, b) {
      final x = a.published?.millisecondsSinceEpoch ?? 0;
      final y = b.published?.millisecondsSinceEpoch ?? 0;
      return y.compareTo(x);
    });
  final links = <String>{};
  final titles = <String>{};
  final out = <Headline>[];
  for (final h in list) {
    if (!links.add(h.link)) continue;
    if (!titles.add(_norm(h.title))) continue;
    out.add(h);
    if (out.length == 200) break;
  }
  return out;
}

/// Age text (FR-31-07).
String ageText(DateTime? published, DateTime now) {
  if (published == null) return '';
  final d = now.difference(published);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
