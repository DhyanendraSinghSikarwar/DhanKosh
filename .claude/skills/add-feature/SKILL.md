---
name: add-feature
description: Use when a NEW feature (not in memory/_index.md) must be specified or built in Hisaab. Creates the memory file from the template, registers it, then implements to the FR-ids.
---

# Add a new feature

1. Confirm the feature is not already in `memory/_index.md` or plan.md section 12. If it exists, use `update-feature` instead.
2. Pick the next number `NN` and a snake_case name. Create `memory/NN_<name>.md` by copying `memory/_feature_template.md`; keep all 18 sections in order. Fill the header table (Feature ID `F-NN`, Status `Proposed`, Priority, Phase, Last Updated).
3. Write FR-ids as `FR-NN-01 ...`, plus data models, tables, business rules, folder location (`lib/features/<name>/{data,domain,presentation}`), test cases, acceptance criteria. Link other features by their memory file; do not copy their rules.
4. Register in `memory/_index.md`: one line `- [NN_<name>.md](NN_<name>.md) - **Title**: summary (Status)`.
5. Add exactly ONE row to the Feature Index (section 12) of `plan.md`. Change nothing else in `plan.md`.
6. Implement following `flutter-conventions` (and `drift-database`, `android-platform-channel`, `transaction-parser`, `statement-parser` where relevant). Tests first for domain rules (`testing`).
7. Run `dart run build_runner build -d`, `dart format .`, `flutter analyze`, `flutter test`.
8. Sync the memory file with what was built (status `In Progress`/`Done`, Change Log entry). If UI exists, run `capture-screen-gif` and add rows to `assets_reference/_screens_index.md`.
