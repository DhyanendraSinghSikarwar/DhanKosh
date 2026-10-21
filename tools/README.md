# tools

Python 3 scripts, no dependencies. Run from the repo root; CI runs them too. A rule that agents must follow lives here as a check, not only as a sentence in a doc.

| Script | Enforces |
|---|---|
| `check_memory.py` | memory index, plan.md feature rows and the 19-section template stay consistent |
| `check_architecture.py` | domain purity, no cross-feature data/presentation imports, no `double` money in domain, single ledger write path |
