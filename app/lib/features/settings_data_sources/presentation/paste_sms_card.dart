import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart' hide Money;

/// Manual test path: paste a bank SMS, see what was parsed or why not
/// (FR-26-26).
class PasteSmsCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const PasteSmsCard({super.key});

  @override
  ConsumerState<PasteSmsCard> createState() => _PasteSmsCardState();
}

class _PasteSmsCardState extends ConsumerState<PasteSmsCard> {
  final _sender = TextEditingController(text: 'VM-HDFCBK');
  final _body = TextEditingController();
  String? _result;
  bool _busy = false;

  @override
  void dispose() {
    _sender.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await ref.read(ingestMessageProvider).detail(
          InboxSms(
            sender: _sender.text.trim(),
            body: _body.text,
            receivedAt: now,
            sentAt: now,
          ),
        );
    final out = switch (d.parse) {
      Parsed(:final transaction) => '${switch (d.outcome) {
          IngestOutcome.inserted => 'Added',
          IngestOutcome.merged => 'Merged with an existing payment',
          IngestOutcome.flagged => 'Added, flagged for review',
          IngestOutcome.skipped => 'Already added',
          IngestOutcome.rejected => 'Not added',
        }}: ${transaction.type.name} '
            '${formatMoney(Money(transaction.amountMinor))}'
            '${transaction.merchant == null ? '' : ' at ${transaction.merchant}'}'
            '${transaction.accountLast4 == null ? '' : ', A/c ${transaction.accountLast4}'}',
      Rejected(:final reason) => 'Ignored: $reason',
      NotATransaction(:final reason) => 'Not a transaction: $reason',
    };
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = out;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste a bank SMS',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('paste-sender'),
            controller: _sender,
            decoration: const InputDecoration(labelText: 'Sender'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('paste-body'),
            controller: _body,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('paste-run'),
            onPressed: _busy ? null : _run,
            child: const Text('Parse and add'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            Text(_result!, key: const Key('paste-result')),
          ],
        ],
      ),
    );
  }
}
