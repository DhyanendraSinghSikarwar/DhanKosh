#!/usr/bin/env python3
"""Architecture rules from CLAUDE.md as code (app/lib).

1. domain is pure Dart: no flutter, drift, or platform-channel imports.
2. presentation does not import data (of any feature).
3. A feature never imports another feature's data or presentation.
4. No `double` money in domain (identifier or type containing amount/balance/
   price/paise/minor next to `double`).
5. Only the transactions repository may write `transactions` (no
   `into(transactions)` / `transactions` writes outside features/transactions_ledger/data).
Exit 1 on violations. Heuristic by design: keeps the three invariants that pass
every test from regressing silently.
"""
import re
import sys
from pathlib import Path

LIB = Path(__file__).resolve().parent.parent / "app" / "lib"
errors: list[str] = []
imp = re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", re.M)
money_double = re.compile(r"\bdouble\b[^;=\n]*\b\w*(amount|balance|price|paise|minor)\w*", re.I)
ledger_write = re.compile(r"\b(into|update|delete)\(\s*(db\.)?transactions\s*\)")
LEDGER_DIR = "features/transactions_ledger/data"

for path in sorted(LIB.rglob("*.dart")):
    rel = path.relative_to(LIB).as_posix()
    if rel.endswith((".g.dart", ".freezed.dart", ".drift.dart")):
        continue
    text = path.read_text(encoding="utf-8")
    parts = rel.split("/")
    feature = parts[1] if parts[0] == "features" and len(parts) > 2 else None
    layer = parts[2] if feature and len(parts) > 3 else None

    for target in imp.findall(text):
        if layer == "domain" and re.match(r"package:(flutter|flutter_riverpod|riverpod|drift|sqlite3|sqlcipher)\b", target):
            errors.append(f"{rel}: domain imports {target}")
        if layer == "domain" and target.startswith("dart:ui"):
            errors.append(f"{rel}: domain imports {target}")
        m = re.match(r"package:hisaab/features/([^/]+)/(data|presentation)/", target)
        if m:
            other, olayer = m.groups()
            if layer == "presentation" and olayer == "data":
                errors.append(f"{rel}: presentation imports data ({target})")
            if feature and other != feature:
                errors.append(f"{rel}: imports {other}/{olayer} from feature {feature}")

    if layer == "domain":
        for i, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            if money_double.search(line):
                errors.append(f"{rel}:{i}: double used for money: {line.strip()}")

    if ledger_write.search(text) and not rel.startswith(LEDGER_DIR):
        errors.append(f"{rel}: writes transactions outside the ledger repository")

for e in errors:
    print("ERROR:", e)
print(f"architecture check: {len(errors)} violation(s)")
sys.exit(1 if errors else 0)
