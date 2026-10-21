# ADR-0001: Rebuild in Flutter, Android first

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

The Kotlin app `hisaab_apk` works, but its structure made it hard to change (see [research](../research/reference-repos.md)). The goal is a maintainable rebuild with the same behaviour. iOS cannot read SMS or notifications, so it could only ever offer email, statements and manual entry.

## Decision

Rebuild in Flutter (Dart 3). Ship Android only first; keep iOS possible. Only SMS, notifications, Keystore, PDF text and the widget stay in Kotlin behind platform channels.

## Consequences

Parsers, ledger, analytics and UI become pure Dart and unit-testable without a device. The cost is five native bridges to maintain and a Dart port of about 287 Kotlin files, delivered by phase ([plan.md](../../plan.md) section 13).

## Alternatives considered

- **Keep refactoring the Kotlin app.** Rejected: owner reports structure, not features, was the problem.
- **Kotlin Multiplatform.** Rejected: less mature UI story; the parser is the only truly shared part and it ports to Dart cheaply.
