# DhanKosh

Offline-first personal finance app for India. It builds one ledger from bank SMS, email, payment-app notifications and statements, and records each payment once. Everything is parsed and stored on the phone.

Flutter rebuild (Android first) of the Kotlin app [hisaab_apk](https://github.com/DhyanendraSinghSikarwar/hisaab_apk) v2.9.8. Parity with it is the baseline, not a redesign.

## Status

Phases 1-5 are built (ledger, SMS/email/notification capture, statements, cards, portfolio, budgets, bills, loans, analytics, tax, alerts, app lock, backup, themes, widget). Not yet run on a wide range of real phones; see each feature's Implementation Notes and [capture coverage](docs/research/capture-coverage.md). Android only for now.

## Download

**Android:** [latest release](../../releases/latest) → `DhanKosh.apk`
(direct link: `https://github.com/DhyanendraSinghSikarwar/DhanKosh/releases/latest/download/DhanKosh.apk`).
Open the file on the phone and allow installs from your browser or file manager.
**iPhone:** not available yet.

## Run it on your phone

Short version: push, open GitHub Actions, download the `hisaab-debug-apk` artifact, install it. Full steps, including local `flutter run`: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Map

| What | Where |
|---|---|
| Rules for contributors and agents | [CLAUDE.md](CLAUDE.md), [AGENTS.md](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md) |
| Master plan (stack, architecture, schema, roadmap) | [plan.md](plan.md) |
| Feature specs, one file each | [memory/_index.md](memory/_index.md) |
| Decisions | [docs/adr/](docs/adr/) |
| Research | [docs/research/](docs/research/) |
| Flutter project | [app/](app/) |

## Privacy

No analytics, no remote logging, no cloud backup. Network is used only for the user's own email provider, update check, language packs, news and the Support hand-off.

Licence: see [LICENSE](LICENSE) (placeholder, [ADR-0006](docs/adr/0006-licence-and-distribution.md)).
