# ADR-0007: Project scaffolding adopted from fluenough and hisaab_apk

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

The owner asked for the working structure of fluenough (skills, memory, tools, CLAUDE.md, licence, .github, docs) applied to Hisaab, keeping the working ideas of hisaab_apk. Details and per-item verdicts: [research/reference-repos.md](../research/reference-repos.md).

## Decision

Adopt: AGENTS.md as a map plus CLAUDE.md as rules, ADRs, `docs/research`, `docs/plans`, `docs/mockups`, `tools/` checks run in CI, PR and issue templates, CI with analyze/test/APK. Keep ours: memory-per-feature, plan.md, FR-id traceability. Reject: fluenough's "never run tests locally", docs-straight-to-main, generated `android/` (we have custom Kotlin), deck/language tooling.

## Consequences

Structure is enforceable by CI rather than by convention. Some fluenough conventions (model-per-job table, Opus quotas) were not copied because they are workflow preferences, not project needs.

## Alternatives considered

- **Copy fluenough wholesale.** Rejected: different product (decks, TTS), different constraints (native SMS, finance privacy).
