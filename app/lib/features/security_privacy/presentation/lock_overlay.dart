import 'dart:async';

import 'package:flutter/material.dart';

/// Opaque full-screen lock (FR-25-04). Shows no app content.
class LockOverlay extends StatefulWidget {
  /// Creates the overlay.
  const LockOverlay({
    required this.onUnlock,
    this.failed = false,
    this.busy = false,
    this.retryAt,
    super.key,
  });

  /// Re-fires the prompt.
  final VoidCallback onUnlock;

  /// Last attempt failed.
  final bool failed;

  /// Prompt on screen.
  final bool busy;

  /// Prompts are blocked until this time after repeated failures (FR-25-24).
  final DateTime? retryAt;

  @override
  State<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<LockOverlay> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.retryAt != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _wait {
    final r = widget.retryAt;
    if (r == null) return 0;
    final ms = r.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  @override
  Widget build(BuildContext context) {
    final failed = widget.failed;
    final busy = widget.busy;
    final wait = _wait;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('lock-overlay'),
      color: scheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'DhanKosh is locked',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (failed && !busy) ...[
              const SizedBox(height: 8),
              const Text('Not unlocked', key: Key('lock-failed')),
            ],
            if (wait > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Too many attempts. Try again in $wait s',
                key: const Key('lock-wait'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('lock-unlock'),
              onPressed: busy || wait > 0 ? null : widget.onUnlock,
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
