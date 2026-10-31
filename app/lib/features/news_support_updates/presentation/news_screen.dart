import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/features/news_support_updates/domain/news.dart';
import 'package:hisaab/features/portfolio/domain/portfolio_class.dart';

/// Market news (F-31, FR-31-01 to FR-31-08).
class NewsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  bool _mine = false;

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
      appBar: AppBar(title: const Text('Market news')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<bool>(
              key: const Key('news-scope'),
              segments: const [
                ButtonSegment(value: true, label: Text('My holdings')),
                ButtonSegment(value: false, label: Text('Market')),
              ],
              selected: {_mine},
              onSelectionChanged: (v) => setState(() => _mine = v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<NewsFeed>(
              key: const Key('news-tabs'),
              segments: [
                for (final f in NewsFeed.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {s.feed},
              onSelectionChanged: (v) => c.load(v.first),
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
    return RefreshIndicator(
      onRefresh: () => c.load(s.feed, force: true),
      child: ListView.builder(
        key: const Key('news-list'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final h = items[i];
          final age = ageText(h.published, now);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              h.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: i == 0 ? 17 : 15,
                fontWeight: i == 0 ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            subtitle: Text(age.isEmpty ? h.source : '${h.source} · $age'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            // FR-31-08: failures are ignored silently.
            onTap: () async {
              try {
                await ref.read(widgetChannelProvider).openUrl(h.link);
              } on Object {
                // ignore
              }
            },
          );
        },
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
