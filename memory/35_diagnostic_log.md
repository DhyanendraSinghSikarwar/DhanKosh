# Diagnostic Log

| Field | Value |
|---|---|
| Feature ID | F-35 |
| Status | In Progress |
| Priority | P1 |
| Phase | 5 |
| Last Updated | 2026-10-26 |

## 1. Description
A small log file kept only on the phone so the owner can see what the app did and send it back when something goes wrong on a real device. It records what happened (scan finished, task failed) and how many, never what a message said.

## 2. What This Feature Will Do
- Writes one line per event to a private file on the phone, from the app and from background tasks.
- Strips anything that looks like a message, number, amount, email or name before writing.
- Shows the log, its size and filters by area in More > Diagnostic log.
- Exports the log as a .txt file or copies the last 200 lines, only when the user asks.
- Clears the log on request; lets the user switch logging off or to Debug level.

### 2.1 Inputs
Calls to the `AppLogger` port from the key seams (scan, live SMS, notifications, email, statements, background, channels, database, lock, app start) and uncaught errors.

### 2.2 Processing
1. Logger checks the switch and level (read from a small config file, shared with the headless isolate).
2. Code, keys and values are sanitised; only short token-like values stay.
3. The entry is formatted as one line and appended with a flushed small write.
4. Past 512 KB the file rotates to `.1` (two files kept).

### 2.3 Outputs
`logs/diagnostic.log` (+ `.1`) in app-private storage; the Diagnostic log screen; an exported .txt on user action.

### 2.4 Out of Scope
Any upload, analytics, remote logging, crash reporting service, logging of message text, amounts, names, accounts, UPI ids, phone numbers, passwords, keys or statement text.

## 3. Behaviour in Existing App
N/A - the Kotlin app v2.9.8 has no diagnostic log (only the activity log, see [22_activity_log.md](22_activity_log.md), which is a user-facing ledger of ingest runs).

## 4. User Stories
- As the owner testing on a phone, I export the log and send it so the problem can be found.
- As a privacy-minded user, I see that the log holds no messages or amounts and can switch it off or clear it.

## 5. Functional Requirements (FR-35-01 ...)
- FR-35-01: `AppLogger` port with `debug/info/warn/error(category, code, {fields})`; implementations never throw.
- FR-35-02: `LogLevel` (debug, info, warn, error) and a closed `LogCategory` set (sms, notifications, email, statement, ledger, background, channel, db, ui, app).
- FR-35-03: `LogEntry` = UTC time, level, category, code, sanitised fields.
- FR-35-04: `LogFormat`: one line `ISO-UTC | LEVEL | category | code | k=v ...`; parseable back.
- FR-35-05: Sanitizer masks digit runs of 6+ and decimal amounts as `[num]`.
- FR-35-06: Sanitizer redacts values with `@` (email, UPI id), marks values with spaces or odd characters `[text]`, values over 40 characters or 20+ char tokens `[long]`; codes and keys are lower-case tokens.
- FR-35-07: Only counts, durations, enum names, error class names, error codes and file:line frames are passed by callers.
- FR-35-08: Message bodies, sender text, amounts, accounts, UPI ids, names, phones, passwords, keys and statement text are never logged.
- FR-35-09: Global handlers (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`) log the error class and up to 4 `file.dart:line` frames; the message text is never read.
- FR-35-10: File sink in app-private storage; append-only whole-line flushed writes; each isolate opens its own sink, so the headless task isolate logs too.
- FR-35-11: Size cap 512 KB per file; rotate to `.1`; two files kept.
- FR-35-12: Default logger is a no-op (`AppLog.instance`); seams use optional injection or `AppLog.instance`, so existing tests are unaffected.
- FR-35-13: Setting to keep the log (default on) and level (default Info, Debug optional), stored in `diagnostic.cfg` next to the log so every isolate sees it; off writes nothing.
- FR-35-14: Screen `/settings/logs` shows size, entry count and recent entries in a monospace list.
- FR-35-15: Visible note: "Logs stay on this phone. They never include messages, amounts or names."
- FR-35-16: "Clear log" with confirm.
- FR-35-17: Toggle "Keep a diagnostic log", Info/Debug selector, category filter chips.
- FR-35-18: "Export log" saves a .txt through the system save dialog (lock skipped via `LockSkipper`); never automatic.
- FR-35-19: "Copy last 200 lines" to the clipboard.
- FR-35-20: Scan logs start and finish with counts (`scan.start`, `scan.done`, `scan.failed`); live SMS logs `live.handled` (outcome) and `live.ignored` (debug); drain logs counts.
- FR-35-21: Email sync logs mode, counts and failure type (`sync.done`, `sync.failed`).
- FR-35-22: Statement import logs result kind, counts and unsupported reason (`import.result`).
- FR-35-23: `app.start` / `app.resume` log app version, build mode, OS name and Android SDK int.
- FR-35-24: Background tasks log `task.start/done/failed` with task name and duration; channel failures log method and code; DB logs create/open/migrate with schema versions; alert post failures; notification engine events; lock events log only `lock.locked` / `lock.unlocked`.

## 6. Non-Functional Requirements (performance, battery, privacy, offline)
Local only, no network. One small synchronous write per event; events are coarse (per run, not per message, except live SMS and notifications). Cap 1 MB total. Privacy rules in section 10.

## 7. UI / Screens & User Flow
More > Diagnostic log (`/settings/logs`): note, stats, toggle, level, Export / Copy / Clear, category chips, entries. GIF: Pending (see `assets_reference/_screens_index.md`).

## 8. Data Models (Dart entities, fields, types)
`LogLevel`, `LogCategory`, `LogEntry(at, level, category, code, fields)`, `LogConfig(enabled, level)`, `LogStats(bytes, entries)` (domain/shared, pure Dart). Ports: `AppLogger`, `LogSink`, `DiagnosticLogStore`, `LogExportGateway`.

## 9. Database Tables / Changes
N/A - file based, no database table (the log must work before and without the encrypted DB).

## 10. Business Rules & Logic (regex, algorithms, thresholds, formulas)
- Value rules: empty `-`; length over 40 `[long]`; contains `@` `[redacted]`; `\d+[.,]\d{2}` `[num]`; chars outside `[A-Za-z0-9_.:/-]` `[text]`; token of 20+ alphanumerics `[long]`; digit runs of 6+ `[num]`.
- Keys and codes: lower-case, non `[a-z0-9_.]` become `_`, max 32.
- Rotation: when the active file is at least 512 KB, rename to `.1` (delete older), start a new file.
- Config cached for 2 s per isolate.

## 11. Platform / Native Requirements (permissions, channels, background work)
No permission, no native code. `path_provider` support directory (`<support>/logs`). Export uses the `file_picker` save dialog. The headless entry installs its own logger.

## 12. Dependencies (links to other feature files; packages)
[24_backup_export.md](24_backup_export.md) (save pattern), [25_security_privacy.md](25_security_privacy.md) (`LockSkipper`), [26_settings_data_sources.md](26_settings_data_sources.md) (tile slot), [22_activity_log.md](22_activity_log.md) (separate user-facing log). Packages: path_provider, file_picker.

## 13. Folder Location (lib/features/<name>/...)
`lib/shared/log/` (port, models, sanitizer, format, `AppLog`), `lib/features/diagnostic_log/{domain,data,presentation}`, `lib/app/di/log_providers.dart`, `lib/app/error_handlers.dart`.

## 14. Edge Cases & Error Handling
Storage unavailable: no-op logger. Unreadable or corrupt lines: skipped. Concurrent isolates: whole-line appends, rotation errors swallowed. Export cancelled: message only. Logging never throws into callers.

## 15. Test Cases (unit / widget / integration + fixtures)
- `test/shared/log/log_core_test.dart`: sanitizer privacy cases, logger toggle and level, error fields, format round-trip.
- `test/features/diagnostic_log/file_log_sink_test.dart`: rotation and cap, two writers, config, clear/export.
- `test/features/diagnostic_log/error_handlers_test.dart`: class names only.
- `test/features/diagnostic_log/diagnostic_log_screen_test.dart`: empty, populated, filter, toggle, export, clear.
- `test/features/sms_ingestion/scan_sms_log_test.dart`: counts, no body.

## 16. Acceptance Criteria
- AC-35-01: A sample SMS body, account number, amount or email passed as a field never appears in the file.
- AC-35-02: Logging off writes nothing.
- AC-35-03: The log never exceeds about 1 MB.
- AC-35-04: Export and Copy happen only on tap; nothing leaves the phone otherwise.
- AC-35-05: Background task runs appear in the log.

## 17. Open Questions
Whether to add an in-app "share" sheet; needs a share plugin (none today).

## 18. Implementation Notes
- The switch is a sidecar `diagnostic.cfg`, not the settings DB, so the headless isolate and a locked or failing DB still log correctly.
- Global `AppLog.instance` is per isolate; `main` and `callbackDispatcher` install the file logger.
- Not yet run on a device.

## 19. Change Log (date | change | reason)
| Date | Change | Reason |
|---|---|---|
| 2026-10-26 | Created | New feature F-35 Diagnostic Log |
