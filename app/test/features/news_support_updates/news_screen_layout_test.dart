// News screen layout of the approved mock (FR-31-06, FR-31-07): pill scope
// tabs, one card of rows with class tags, privacy note.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/news_support_updates/domain/news.dart';
import 'package:hisaab/features/news_support_updates/presentation/news_screen.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';

class _FakeNews extends NewsController {
  @override
  NewsState build() => const NewsState(
        items: [
          Headline(
            title: 'Gold rate steady ahead of the festive week',
            link: 'https://example.com/a',
            source: 'Example Wire',
          ),
          Headline(
            title: 'Banks lead gains as benchmark indices end higher',
            link: 'https://example.com/b',
            source: 'Example Wire',
          ),
        ],
      );

  @override
  Future<void> load(NewsFeed feed, {bool force = false}) async {}
}

void main() {
  testWidgets('scope pills, one card of rows, tag and privacy note', (t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          newsControllerProvider.overrideWith(_FakeNews.new),
          holdingsProvider
              .overrideWith((ref) => Stream.value(const <Holding>[])),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const NewsScreen()),
      ),
    );
    await t.pump();
    expect(find.text('Latest news'), findsOneWidget);
    expect(find.byKey(const Key('news-scope-My holdings')), findsOneWidget);
    // My holdings is the default scope; no holdings means no rows.
    expect(find.byKey(const Key('news-none')), findsOneWidget);
    await t.tap(find.byKey(const Key('news-scope-Market')));
    await t.pump();
    expect(find.byKey(const Key('news-list')), findsOneWidget);
    expect(
      find.text('Gold rate steady ahead of the festive week'),
      findsOneWidget,
    );
    expect(find.text('Gold'), findsOneWidget);
    expect(find.textContaining('Only headlines are fetched'), findsOneWidget);
  });
}
