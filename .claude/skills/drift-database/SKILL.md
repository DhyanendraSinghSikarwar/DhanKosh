---
name: drift-database
description: Use when adding or changing Drift tables, DAOs, migrations, triggers or SQLCipher setup in Hisaab.
---

# Drift + SQLCipher

1. Read the owning feature's memory file (sections 8 and 9) and the table-owner map in plan.md section 6. The schema starts fresh at Drift v1, mirroring Android Room v15.
2. Define tables under `lib/core/db` (or the feature `data` folder if feature-owned); DAOs end in `Dao`. Money columns are `integer` paise (name them `...Minor`). Dates stored as UTC epoch ms/`DateTime`.
3. The DB opens with SQLCipher (`package:sqlite3` build hook, `source: sqlcipher` in `pubspec.yaml`; never add `sqlcipher_flutter_libs`, see ADR-0003); the key is generated once and held in Keystore via the `secure` channel. Never hardcode a key. Key loss recovery is CSV re-import.
4. `transactions` is written only by the transaction repository inside one DB transaction (ingest, dedup, balance update). Other code reads via DAOs/repositories.
5. Schema change: bump `schemaVersion`, write a `MigrationStrategy` step, and add a migration test using Drift's schema verification (`dart run drift_dev schema dump` / `schema steps`). Recreate the `forex_rates` triggers that keep `inrMinor` current (feature 23).
6. Run `dart run build_runner build -d`; never edit `*.g.dart`.
7. Tests use an in-memory `NativeDatabase.memory()` (no cipher needed); cover FK behaviour (accountId SET NULL, sources CASCADE).
8. Update memory section 9 and the Change Log; touch plan.md section 6 only if tables or owners change at app level.
