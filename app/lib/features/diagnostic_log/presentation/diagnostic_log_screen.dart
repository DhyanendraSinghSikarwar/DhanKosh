import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/log_providers.dart';
import 'package:hisaab/features/diagnostic_log/domain/diagnostic_log_store.dart';
import 'package:hisaab/shared/log/app_logger.dart';
import 'package:hisaab/shared/log/log_format.dart';
import 'package:hisaab/shared/log/log_models.dart';

/// Diagnostic log (F-35): view, filter, export, copy and clear the local log.
class DiagnosticLogScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DiagnosticLogScreen({super.key});

  @override
  ConsumerState<DiagnosticLogScreen> createState() => _State();
}

class _View {
  const _View(this.config, this.stats, this.entries);
  final LogConfig config;
  final LogStats stats;
  final List<LogEntry> entries;
}

class _State extends ConsumerState<DiagnosticLogScreen> {
  _View? _view;
  LogCategory? _filter;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<DiagnosticLogStore> get _store =>
      ref.read(diagnosticLogStoreProvider.future);

  Future<void> _load() async {
    try {
      final s = await _store;
      final v = _View(
        await s.config(),
        await s.stats(),
        await s.recent(limit: 300),
      );
      if (mounted) setState(() => _view = v);
    } on Object {
      if (mounted) {
        setState(
          () => _view = const _View(LogConfig(), LogStats(), []),
        );
      }
    }
  }

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _setConfig(LogConfig c) async {
    final s = await _store;
    await s.setConfig(c);
    await _load();
  }

  // FR-35-18: explicit user action only.
  Future<void> _export() async {
    try {
      final text = await (await _store).exportText();
      final stamp = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final name = await ref
          .read(logExportGatewayProvider)
          .save('dhankosh-log-$stamp.txt', utf8.encode(text));
      _say(name == null ? 'Export cancelled' : 'Saved $name');
    } on Object {
      _say('Could not export the log');
    }
  }

  Future<void> _copy() async {
    final lines = await (await _store).lines();
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    _say('Copied ${lines.length} lines');
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('log-clear-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await (await _store).clear();
    await _load();
    _say('Log cleared');
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    final shown = v == null
        ? const <LogEntry>[]
        : [
            for (final e in v.entries.reversed)
              if (_filter == null || e.category == _filter) e,
          ];
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic log')),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Logs stay on this phone. They never include messages, '
                  'amounts or names.',
                  key: Key('log-note'),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(v.stats.bytes / 1024).toStringAsFixed(1)} KB, '
                  '${v.stats.entries} entries',
                  key: const Key('log-stats'),
                ),
                SwitchListTile(
                  key: const Key('log-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Keep a diagnostic log'),
                  value: v.config.enabled,
                  onChanged: (on) =>
                      _setConfig(LogConfig(enabled: on, level: v.config.level)),
                ),
                if (v.config.enabled)
                  SegmentedButton<LogLevel>(
                    key: const Key('log-level'),
                    segments: const [
                      ButtonSegment(
                        value: LogLevel.info,
                        label: Text('Info'),
                      ),
                      ButtonSegment(
                        value: LogLevel.debug,
                        label: Text('Debug'),
                      ),
                    ],
                    selected: {
                      if (v.config.level == LogLevel.debug)
                        LogLevel.debug
                      else
                        LogLevel.info,
                    },
                    onSelectionChanged: (s) =>
                        _setConfig(LogConfig(level: s.first)),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('log-export'),
                      onPressed: _export,
                      child: const Text('Export log'),
                    ),
                    OutlinedButton(
                      key: const Key('log-copy'),
                      onPressed: _copy,
                      child: const Text('Copy last 200 lines'),
                    ),
                    OutlinedButton(
                      key: const Key('log-clear'),
                      onPressed: _clear,
                      child: const Text('Clear log'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in LogCategory.values)
                      FilterChip(
                        key: Key('log-chip-${c.name}'),
                        label: Text(c.name),
                        selected: _filter == c,
                        onSelected: (on) =>
                            setState(() => _filter = on ? c : null),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  const Text('No entries', key: Key('log-empty'))
                else
                  for (final e in shown)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        LogFormat.line(e),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
