import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/alerts_lifecycle.dart';
import 'package:hisaab/app/device_hooks.dart';
import 'package:hisaab/app/di/appearance_providers.dart';
import 'package:hisaab/app/lock_gate.dart';
import 'package:hisaab/app/router.dart';
import 'package:hisaab/app/startup_tasks.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/onboarding_permissions/presentation/app_lifecycle_gate.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';

class HisaabApp extends ConsumerWidget {
  const HisaabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    final lang = ref.watch(languageProvider.select((s) => s.active));
    return MaterialApp.router(
      title: 'DhanKosh',
      theme: AppTheme.build(a.palette, Brightness.light, backdrop: true),
      darkTheme: AppTheme.build(
        a.palette,
        Brightness.dark,
        pureBlack: a.pureBlack,
        backdrop: true,
      ),
      themeMode: switch (a.mode) {
        ThemeModeChoice.system => ThemeMode.system,
        ThemeModeChoice.light => ThemeMode.light,
        ThemeModeChoice.dark => ThemeMode.dark,
      },
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = effectiveTextScale(
          mq.textScaler.scale(1),
          a.textSize.factor,
        );
        // Re-keyed on language so every `t()` call site rebuilds (FR-29-03).
        return KeyedSubtree(
          key: ValueKey(lang),
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(scale),
              // Reduce motion (FR-28-10): the setting or the phone's own.
              disableAnimations: mq.disableAnimations || a.reduceMotion,
            ),
            child: LockGate(
              child: AppLifecycleGate(
                child: AlertsLifecycle(
                  child: DeviceHooks(
                    child: StartupTasks(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
