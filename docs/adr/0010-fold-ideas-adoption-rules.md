# ADR-0010: Adopt Fold's UX ideas only inside DhanKosh's privacy rules

- **Status:** Accepted
- **Date:** 2026-10-26

## Context

The owner supplied a teardown of the Fold app and asked which features to copy. Detail and per-item verdicts: [research/fold-adoption.md](../research/fold-adoption.md).

## Decision

1. A feature is adopted only if it needs no backend, no partner, no paid service and sends no user data off the phone.
2. Keep the device-credential app lock (biometric or screen lock). Do not add an app PIN or recovery key: it would add a secret we must store and a recovery flow we cannot back with a server.
3. Recovery is a passphrase-encrypted full backup the user keeps ([feature 24](../../memory/24_backup_export.md)); the database key is bound to the phone.
4. The only new network use allowed is an optional, user-enabled download of the public AMFI NAV file. It sends nothing about the user.
5. No XIRR until real cash-flow history exists.
6. Fold's brand assets and wording are not used; DhanKosh keeps its own logo and palettes.

## Consequences

Backups become essential to document in the UI. Some Fold features (rewards, trading, bill pay) stay out for good.

## Alternatives considered

- **App PIN plus recovery key.** Rejected for the reasons in item 2.
- **Live stock prices.** Rejected: needs a paid or rate-limited API.
