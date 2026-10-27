import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/ocr_providers.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/screenshot_fill.dart';

/// "Fill from a screenshot" card for the Add screen (FR-08-12). Picks an
/// image, reads it on device and hands the draft to [onFill]; never saves.
class OcrFillCard extends ConsumerStatefulWidget {
  /// Creates the card. [accounts] are used to guess the account.
  const OcrFillCard({
    required this.accounts,
    required this.onFill,
    super.key,
  });

  /// Visible accounts.
  final List<Account> accounts;

  /// Receives a result that has an amount.
  final void Function(ScreenshotFill fill) onFill;

  @override
  ConsumerState<OcrFillCard> createState() => _OcrFillCardState();
}

class _OcrFillCardState extends ConsumerState<OcrFillCard> {
  bool _scanning = false;
  String? _message;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _message = null;
    });
    String? msg;
    try {
      final path = await ref.read(screenshotSourceProvider).pick();
      if (path == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }
      final fill = await ref
          .read(screenshotFillServiceProvider)
          .read(path, widget.accounts);
      if (fill.found) {
        widget.onFill(fill);
        msg = 'Filled in from the screenshot. Check the details, then save.';
      } else {
        msg = 'No amount found in that screenshot. Fill the details in '
            'yourself.';
      }
    } on Object {
      msg = "Couldn't read that image.";
    }
    if (mounted) {
      setState(() {
        _scanning = false;
        _message = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                key: const Key('ocr_fill'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_search_outlined),
                title: const Text('Fill from a screenshot'),
                subtitle: const Text('Read on this device'),
                onTap: _scanning ? null : _scan,
              ),
              if (_scanning) const LinearProgressIndicator(),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!, key: const Key('ocr_message')),
                ),
            ],
          ),
        ),
      );
}
