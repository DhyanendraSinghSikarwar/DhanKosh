# Contributing

Read [CLAUDE.md](CLAUDE.md) (rules) and [AGENTS.md](AGENTS.md) (map) first.

## Flow

1. Find the feature in [memory/_index.md](memory/_index.md) and read its file. New feature: use the `add-feature` skill. Change: `update-feature`.
2. Branch `feat/<feature-id>-<slug>` (or `fix/`, `docs/`). Keep one concern per branch.
3. Write the test first (parser rules need a fixture). Reference FR-ids in code and tests.
4. Sync the feature's memory file (requirements, models, tables, rules, tests, Change Log).
5. Run the checks in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#checks). Open a PR with the template; CI must be green.
6. Add one line to `CHANGELOG.md` under `Unreleased` if the change is user-visible.

## Decisions

If you change the stack, architecture, schema approach, native bridge or distribution, add an ADR (`docs/adr/0000-template.md`). Do not edit an accepted ADR; supersede it.

## Data hygiene

No secrets. No real SMS, email or statement text unless fully masked (names, account numbers, amounts, references, phone numbers, UPI ids). Screenshots and GIFs use dummy data only.

## Commits

Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
