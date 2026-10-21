# ADR-0006: Placeholder licence; distribute as a signed APK

- **Status:** Proposed
- **Date:** 2026-10-21

## Context

fluenough is GPL-3.0 plus a store exception because it is a public learning app. Hisaab reads SMS and holds financial parsing rules; `hisaab_apk` has no licence file. Google Play restricts `READ_SMS` ([plan.md](../../plan.md) section 7).

## Decision

Until the owner decides, `LICENSE` is "all rights reserved" (most restrictive, reversible). Distribute as a signed APK via GitHub Releases; no Play submission until the SMS strategy is chosen.

## Consequences

Contributors cannot reuse the code. Loosening to an open licence later is a one-file change; tightening later is not.

## Alternatives considered

- **GPL-3.0 now.** Deferred: irreversible once others fork; owner has not chosen. Open question in plan.md section 15.
