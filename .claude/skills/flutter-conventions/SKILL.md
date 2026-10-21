---
name: flutter-conventions
description: Use when writing or reviewing any Dart/Flutter code in Hisaab (providers, screens, repositories, routing, money). Enforces Clean Architecture, Riverpod codegen, go_router and paise rules.
---

# Flutter conventions

1. Place code in `lib/features/<feature>/{data,domain,presentation}`; shared widgets in `lib/shared`; db, channels, money and utils in `lib/core`; router, theme, DI in `lib/app`.
2. `domain`: pure Dart (entities with `freezed`, use cases, repository interfaces). No imports of `flutter`, `drift`, or `MethodChannel`.
3. `data`: Drift DAOs, channel sources, repository implementations of domain interfaces. `presentation`: screens, sheets, Riverpod notifiers; depends on `domain` only.
4. Never import another feature's `data` or `presentation`. Use a domain interface or `shared`.
5. Riverpod: use `@riverpod` / `@Riverpod(keepAlive: true)` codegen (`riverpod_annotation`); `part 'x.g.dart';`. Providers are wired in `app/di`. Override in tests with `ProviderContainer(overrides: ...)`.
6. Navigation: `go_router`; 5-tab `StatefulShellRoute` (Home, Transactions, Portfolio, Analysis, More). Deep links: `hisaab://budgets`, `bills`, `transaction/{id}`, `account/{id}`, `statements`.
7. Money: `int` paise everywhere (domain, db, channels). Convert only at the display edge with the en-IN formatter in `core/money`. Honour the global amount-masking setting (`₹••••`).
8. Writes to `transactions` go only through the transaction repository (single ledger write path: ingest, dedup, balance update in one DB transaction).
9. Naming: `snake_case` files, one public widget per file, suffixes `Screen`, `Sheet`, `Dialog`, `Notifier`, `Repository`, `Dao`. Theme via `ThemeExtension` tokens, no hard-coded colours.
10. Never edit `*.g.dart` / `*.freezed.dart`; run `dart run build_runner build -d`. Finish with `dart format .` and `flutter analyze` (zero issues, `very_good_analysis`).
11. Cite FR-ids from the feature memory file in tests and key code comments.
