import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/features/news_support_updates/domain/news.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/pill_tabs.dart';

/// Market news (F-31, FR-31-01 to FR-31-08).
class NewsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  bool _mine = true;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() => ref.read(newsSeenProvider.notifier).markSeen()),
    );
    unawaited(
      Future.microtask(
        () => ref.read(newsControllerProvider.notifier).load(NewsFeed.latest),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(newsControllerProvider);
    final c = ref.read(newsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Latest news')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PillTabs(
                keyPrefix: 'news-scope',
                labels: const ['My holdings', 'Market'],
                selected: _mine ? 0 : 1,
                onChanged: (i) => setState(() => _mine = i == 0),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PillTabs(
                keyPrefix: 'news-tab',
                labels: [for (final f in NewsFeed.values) f.label],
                selected: NewsFeed.values.indexOf(s.feed),
                onChanged: (i) => c.load(NewsFeed.values[i]),
              ),
            ),
          ),
          Expanded(child: _body(s, c)),
        ],
      ),
    );
  }

  Widget _body(NewsState s, NewsController c) {
    if (s.loading && s.items.isEmpty) {
      return ListView(
        key: const Key('news-skeleton'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [for (var i = 0; i < 6; i++) const _SkeletonCard()],
      );
    }
    if (s.failed && s.items.isEmpty) {
      return Center(
        key: const Key('news-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 8),
            const Text("Couldn't load headlines"),
            const Text('Check your connection and try again.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => c.load(s.feed, force: true),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final now = DateTime.now();
    final keys = holdingNewsKeywords(
      ref.watch(holdingsProvider).value ?? const [],
    );
    final items = _mine
        ? [
            for (final h in s.items)
              if (keys.any(h.title.toLowerCase().contains)) h,
          ]
        : s.items;
    if (items.isEmpty) {
      return const Center(
        key: Key('news-none'),
        child: Text('No headlines for your holdings'),
      );
    }
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return RefreshIndicator(
      onRefresh: () => c.load(s.feed, force: true),
      child: ListView(
        key: const Key('news-list'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final h in items)
                  _row(h, ageText(h.published, now), muted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Only headlines are fetched. Your holdings never leave the '
              'phone.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Headline h, String age, Color muted) {
    final tag = headlineClassLabel(h.title);
    return InkWell(
      // FR-31-08: failures are ignored silently.
      onTap: () async {
        try {
          await ref.read(widgetChannelProvider).openUrl(h.link);
        } on Object {
          // ignore
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.title, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    age.isEmpty ? h.source : '${h.source} · $age',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(tag, style: TextStyle(fontSize: 10, color: muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double w) => Container(
          width: w,
          height: 12,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [bar(double.infinity), bar(260), bar(100)],
      ),
    );
  }
}
