# ADR-0003: Drift on SQLCipher, key in Android Keystore

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

The Kotlin app stores a plain Room database. The ledger is sensitive financial data. See [feature 25](../../memory/25_security_privacy.md) and [33](../../memory/33_upgrade_migration_from_kotlin.md).

## Decision

Use Drift on `package:sqlite3` 3.x with the SQLCipher build hook (`hooks.user_defines.sqlite3.source: sqlcipher` in `pubspec.yaml`). `sqlcipher_flutter_libs` is obsolete from sqlite3 3.x and must not be added. The key is generated on first run and sealed by the Kotlin `secure` channel (Keystore). This is a new decision, not parity.

## Consequences

Encryption at rest. Key loss means data loss; recovery is re-import from CSV backup (feature 24). The native library is downloaded by the build hook at build time (needs network on first build). Do not add `sqlite3_flutter_libs` or `sqlcipher_flutter_libs`.

## Alternatives considered

- **Plain SQLite like the Kotlin app.** Rejected: weaker privacy for no real saving.
- **Isar / ObjectBox.** Rejected: no SQL triggers or FTS, and the schema ports from Room.
