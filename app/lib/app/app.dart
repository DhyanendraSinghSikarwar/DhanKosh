import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/router.dart';
import 'package:hisaab/app/theme/app_theme.dart';
import 'package:hisaab/features/onboarding_permissions/presentation/app_lifecycle_gate.dart';

class HisaabApp extends ConsumerWidget {
  const HisaabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Hisaab',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          AppLifecycleGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
