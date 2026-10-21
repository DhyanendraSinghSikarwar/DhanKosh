---
name: update-feature
description: Use when changing, fixing or extending an EXISTING Hisaab feature. Reads the feature memory file first, implements, then edits only that file and adds a Change Log entry.
---

# Change an existing feature

1. Find the feature in `memory/_index.md` and read its whole memory file before touching code.
2. Identify affected FR-ids and acceptance criteria. If the change adds behaviour, add new FR-ids (never renumber existing ones).
3. Implement the change within the architecture rules in `CLAUDE.md` (see `flutter-conventions`). Add or update tests first; parser rule changes need a fixture (`transaction-parser`).
4. Run `dart run build_runner build -d` (if annotations changed), `dart format .`, `flutter analyze`, `flutter test`.
5. Edit ONLY that feature's memory file: update the affected sections (requirements, models, tables, rules, tests, acceptance), set `Last Updated` and `Status`, and append a Change Log row `date | change | reason`.
6. Do not write feature details into `plan.md`, `CLAUDE.md` or other feature files. If another feature is affected, record it as an Open Question or link to it, and update that file in its own change.
7. `plan.md` is edited only if app-wide structure changed (stack, architecture, folders, schema overview, navigation, roadmap).
8. If screens changed, re-capture the GIF with `capture-screen-gif`.
