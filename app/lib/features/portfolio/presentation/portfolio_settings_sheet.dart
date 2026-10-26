import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/portfolio_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/portfolio/domain/nav_refresh.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';

/// Portfolio settings: the optional fund NAV refresh (FR-16-23). Off by
/// default; the file is public and nothing about the user is sent.
class PortfolioSettingsSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const PortfolioSettingsSheet({super.key});

  @override
  ConsumerState<PortfolioSettingsSheet> createState() => _State();
}

class _State extends ConsumerState<PortfolioSettingsSheet> {
  bool? _on;
  String _result = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsRepositoryProvider);
    unawaited(_load(s));
  }

  Future<void> _load(SettingsRepository s) async {
    final on = await s.read(NavSettings.enabled);
    final r = await s.read(NavSettings.lastResult);
    if (mounted) {
      setState(() {
        _on = on;
        _result = r;
      });
    }
  }

  Future<void> _set(bool v) async {
    setState(() => _on = v);
    await ref.read(settingsRepositoryProvider).write(NavSettings.enabled, v);
  }

  Future<void> _now() async {
    setState(() => _busy = true);
    await ref.read(navRefreshServiceProvider).refresh(force: true);
    final r = await ref.read(settingsRepositoryProvider).read(
          NavSettings.lastResult,
        );
    if (mounted) {
      setState(() {
        _busy = false;
        _result = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const Key('nav-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Refresh fund NAV'),
              subtitle: const Text(
                'Once a day from the public AMFI file. Sends no data about you.',
              ),
              value: _on ?? false,
              onChanged: _on == null ? null : _set,
            ),
            if (_on ?? false)
              Row(
                children: [
                  Expanded(
                    child: Text(_result, key: const Key('nav-result')),
                  ),
                  TextButton(
                    key: const Key('nav-now'),
                    onPressed: _busy ? null : _now,
                    child: const Text('Refresh now'),
                  ),
                ],
              ),
          ],
        ),
      );
}
