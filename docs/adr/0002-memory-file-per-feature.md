# ADR-0002: One memory file per feature is the spec

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

fluenough keeps plans in `docs/plans/` and decisions in `docs/adr/`. Hisaab already has 34 feature files in `memory/` with a fixed template, FR-ids and a Change Log. The owner wants to edit one feature file and have that drive the work.

## Decision

Keep `memory/NN_<name>.md` as the single source of truth per feature (FR-ids, models, tables, rules, tests, acceptance). `plan.md` holds app-wide structure only. `docs/plans/` holds proposals that are not features yet; `docs/adr/` holds decisions. `tools/check_memory.py` enforces index, template and plan-row consistency in CI.

## Consequences

Feature changes touch one file. Cross-feature facts are linked, never copied. The cost is discipline: CI checks structure, not truth, so memory sync stays a Definition-of-Done item.

## Alternatives considered

- **Adopt fluenough's `docs/plans/` for features.** Rejected: no FR-ids or per-feature status, weaker traceability to tests.
