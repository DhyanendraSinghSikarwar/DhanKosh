# ADR-0008: Parsing lives in a pure-Dart package, `parser_core`

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

The Kotlin app kept parsing in a pure module (`parser-core`) with corpus tests; that is the part that worked best. Feature [06](../../memory/06_transaction_parsing_engine.md) specifies the same split.

## Decision

`app/packages/parser_core` is a path-dependency package with no Flutter imports. The app calls `parse(source, sender, body, receivedAt)`. It owns the shared models, the hasher and the duplicate matcher. It has its own `dart test` and analysis, so the parity gate runs without a device or Flutter, and CI runs it as a separate step.

## Consequences

Parser tests run in seconds (598, 940/940 corpus fields). The app's `analysis_options.yaml` excludes `packages/**`. Two dedup implementations currently exist (the ledger's `DedupPolicy` and the package's `DuplicateMatcher`); reconcile them, tracked in [07](../../memory/07_dedup_review.md).

## Alternatives considered

- **Parser inside `lib/`.** Rejected: needs the Flutter toolchain for every parser test and blurs the pure-function boundary.
