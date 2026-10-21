# AGENTS.md

Entry point for any coding agent (Claude Code, Codex, Copilot, humans). The rules live in [CLAUDE.md](CLAUDE.md); this file is the map. Read CLAUDE.md before changing anything.

## Where things are

| Need | Go to |
|---|---|
| Rules, architecture, Definition of Done | [CLAUDE.md](CLAUDE.md) |
| App-wide structure, schema overview, roadmap | [plan.md](plan.md) |
| One feature's spec (single source of truth) | [memory/_index.md](memory/_index.md) then `memory/NN_<name>.md` |
| Why a decision was made | [docs/adr/](docs/adr/) |
| Research and comparisons | [docs/research/](docs/research/) |
| Proposals not yet features | [docs/plans/](docs/plans/) |
| UI mockups and screen GIFs | [docs/mockups/](docs/mockups/), [assets_reference/_screens_index.md](assets_reference/_screens_index.md) |
| Behaviour of the Kotlin app being ported | [docs/analysis/existing_app_analysis.md](docs/analysis/existing_app_analysis.md); source in `../hisaab_apk` (read-only) |
| Setup, run on a phone, CI | [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) |
| Repeatable workflows | `.claude/skills/*/SKILL.md` |

## Three rules that pass every test and still break the app

1. **Money is integer paise.** Never `double`. `tools/check_architecture.py` flags it in `domain`.
2. **One ledger write path.** Only the transaction repository writes `transactions` (ingest, dedup, balance in one DB transaction).
3. **Data never leaves the phone.** No analytics, remote logging or uploads. No real SMS, emails or account data in fixtures, GIFs or commits.

## Working agreements

- **Memory first.** Read the feature file before work; sync it after (FR-ids, models, tables, rules, tests, Change Log). Feature detail never goes in `plan.md` or `CLAUDE.md`.
- **Decisions get an ADR.** Anything that changes the stack, architecture, schema approach or distribution gets `docs/adr/NNNN-<slug>.md` (template: `0000-template.md`). Never edit an accepted ADR; supersede it.
- **Checks before push:** `python3 tools/check_memory.py`, `python3 tools/check_architecture.py`, then in `app/`: `dart format .`, `flutter analyze`, `flutter test`. CI runs the same and builds a debug APK.
- **Reference apps are read-only.** `../hisaab_apk` is the behavioural baseline; never edit it. Port behaviour, not structure.
- **Docs-only changes** (Markdown, skills) need no feature-memory sync unless they change a feature's spec.
- **Token budget.** Read the index, then only the files you need. One review per change.
- Commit and push only when asked. Conventional Commits. Do not create tags or releases.
