---
name: adr
description: Use when a decision changes the stack, architecture, schema approach, native bridge, licence or distribution in Hisaab. Creates a numbered ADR from the template.
---

# Record a decision

1. List `docs/adr/`; take the next number (zero-padded, 4 digits). Copy `docs/adr/0000-template.md` to `docs/adr/NNNN-<slug>.md`.
2. Fill Context (link the affected `memory/NN_*.md` files), Decision (one or two sentences), Consequences (including the cost accepted), Alternatives considered (with why rejected). Date it today. Status `Proposed` until the owner agrees, then `Accepted`.
3. Never edit an accepted ADR. To change a decision, write a new ADR and set the old one's status to `Superseded by ADR-NNNN` (the only edit allowed).
4. If the decision changes app-wide structure, make the matching change in `plan.md` (stack, architecture, folders, schema, navigation, roadmap or risks). Feature detail goes in the feature's memory file, not here.
5. Evidence (comparisons, benchmarks) goes in `docs/research/` and is linked from the ADR.
