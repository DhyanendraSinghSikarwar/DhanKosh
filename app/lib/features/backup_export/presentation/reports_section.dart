import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/shared/report/report_document.dart';

/// PDF reports (FR-24-29, FR-24-30): monthly or yearly summary, portfolio.
class ReportsSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const ReportsSection({super.key});

  @override
  ConsumerState<ReportsSection> createState() => _State();
}

class _State extends ConsumerState<ReportsSection> {
  bool _busy = false;

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save(Future<ReportDocument> Function() build) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(reportServiceProvider);
      final doc = await build();
      final saved = await svc.save(ref.read(blobGatewayProvider), doc);
      if (saved != null) _say('Saved $saved');
    } on Object catch (e) {
      _say('Report failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _summary() async {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - 1);
    final svc = ref.read(reportServiceProvider);
    final choice =
        await showModalBottomSheet<Future<ReportDocument> Function()>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('report-this-month'),
              title: const Text('This month'),
              onTap: () =>
                  Navigator.pop(c, () => svc.month(now.year, now.month)),
            ),
            ListTile(
              key: const Key('report-last-month'),
              title: const Text('Last month'),
              onTap: () =>
                  Navigator.pop(c, () => svc.month(last.year, last.month)),
            ),
            ListTile(
              key: const Key('report-this-year'),
              title: Text('${now.year}'),
              onTap: () => Navigator.pop(c, () => svc.year(now.year)),
            ),
            ListTile(
              key: const Key('report-last-year'),
              title: Text('${now.year - 1}'),
              onTap: () => Navigator.pop(c, () => svc.year(now.year - 1)),
            ),
          ],
        ),
      ),
    );
    if (choice != null) await _save(choice);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PDF reports', style: Theme.of(context).textTheme.titleSmall),
          ListTile(
            key: const Key('report-summary'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Monthly or yearly summary'),
            subtitle: const Text('Income, spend, merchants, budgets'),
            trailing: OutlinedButton(
              onPressed: _busy ? null : _summary,
              child: const Text('Create'),
            ),
          ),
          ListTile(
            key: const Key('report-portfolio'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Portfolio report'),
            subtitle: const Text('Holdings, allocation, gain'),
            trailing: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _save(
                        () => ref
                            .read(reportServiceProvider)
                            .portfolio(DateTime.now()),
                      ),
              child: const Text('Create'),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      );
}
