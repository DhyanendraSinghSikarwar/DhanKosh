# ADR-0004: Own Kotlin platform channels for SMS, notifications and the rest

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

No maintained Flutter plugin gives a reliable SMS receiver, notification listener service, Keystore sealing, PdfBox PDF text with passwords, or a home widget with the needed behaviour.

## Decision

Write five Kotlin channels (`sms`, `notifications`, `secure`, `pdf`, `widget`) under `android/app/src/main/kotlin/com/hisaab/`. Dart sees only domain interfaces; platform code is mocked in Dart tests. Workflow: `android-platform-channel` skill.

## Consequences

Behaviour matches the Kotlin app (PdfBox, same receivers). Live SMS needs a headless Dart entrypoint. Native code needs instrumented tests, which CI does not run yet.

## Alternatives considered

- **Community SMS plugins.** Rejected: unmaintained or inbox-read only.
