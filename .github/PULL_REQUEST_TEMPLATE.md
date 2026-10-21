## What this changes

<!-- One or two sentences. Feature ids (F-NN) touched. -->

## What I verified

<!-- What you ran, and what you did not. -->

## Checklist

- [ ] Feature memory file read first and synced (FR-ids, models, tables, rules, tests, Change Log)
- [ ] `python3 tools/check_memory.py` and `python3 tools/check_architecture.py` pass
- [ ] `dart format .`, `flutter analyze`, `flutter test` pass (in `app/`)
- [ ] Architecture rules kept: no cross-feature data/presentation imports, single ledger write path, paise only
- [ ] ADR added if stack, architecture, schema approach or distribution changed
- [ ] No secrets, no real financial data in code, fixtures or screenshots
- [ ] `CHANGELOG.md` line added (if user-visible)
- [ ] UI changed: GIF captured and `_screens_index.md` updated
