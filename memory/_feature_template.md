# <Feature Name>

| Field | Value |
|---|---|
| Feature ID | F-XX |
| Status | Existing / Proposed / In Progress / Done |
| Priority | P0 / P1 / P2 |
| Phase | X |
| Last Updated | YYYY-MM-DD |

## 1. Description
2-4 sentences: what this feature is, why it exists, and the problem it solves for the user. Plain language.

## 2. What This Feature Will Do
Clear, testable capability list. Each line starts with a verb (Reads, Detects, Parses, Stores, Shows, Calculates, Notifies ...). Plain language.

### 2.1 Inputs
What data or user action triggers it (source, format, frequency).

### 2.2 Processing
Step-by-step what happens (numbered).

### 2.3 Outputs
What the user sees, what is stored, what other features receive.

### 2.4 Out of Scope
What this feature explicitly does NOT do.

## 3. Behaviour in Existing App
How hisaab_apk does it today (with file:line cites and screenshot / GIF links from assets_reference/).

## 4. User Stories

## 5. Functional Requirements (FR-XX-01 ...)

## 6. Non-Functional Requirements (performance, battery, privacy, offline)

## 7. UI / Screens & User Flow
Screen list, flow diagram (Mermaid), GIF links: `![screen](../assets_reference/<NN_feature>/<screen>.gif)`.

## 8. Data Models (Dart entities, fields, types)

## 9. Database Tables / Changes

## 10. Business Rules & Logic (regex, algorithms, thresholds, formulas)

## 11. Platform / Native Requirements (permissions, channels, background work)

## 12. Dependencies (links to other feature files; packages)

## 13. Folder Location (lib/features/<name>/...)

## 14. Edge Cases & Error Handling

## 15. Test Cases (unit / widget / integration + fixtures)

## 16. Acceptance Criteria

## 17. Open Questions

## 18. Implementation Notes
Filled during build: decisions, deviations.

## 19. Change Log (date | change | reason)

Rules:
- Sections 1 and 2 are written first, in plain language a non-developer can understand.
- If a section does not apply, write `N/A - <reason>`; never delete it.
- Existing-app behaviour and proposed ideas never share a file (Proposed features get `Status: Proposed`).
