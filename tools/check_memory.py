#!/usr/bin/env python3
"""Structure check for feature memory files (CLAUDE.md Memory Protocol).

Checks: every memory/NN_*.md is in memory/_index.md and in plan.md section 12
(exactly once), nothing in either points to a missing file, each file has the
19 template headings in order, a metadata table and a Change Log.
Exit 1 on any problem. Checks structure, not truth: sync stays a DoD item.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEM = ROOT / "memory"
errors: list[str] = []

files = sorted(p.name for p in MEM.glob("[0-9][0-9]_*.md"))
index = (MEM / "_index.md").read_text(encoding="utf-8")
plan = (ROOT / "plan.md").read_text(encoding="utf-8")
plan12 = plan.split("## 12. Feature Index", 1)[-1].split("\n## ", 1)[0]

idx_links = re.findall(r"\]\(([0-9]{2}_[^)]+\.md)\)", index)
plan_links = re.findall(r"\]\(memory/([0-9]{2}_[^)]+\.md)\)", plan12)

for f in files:
    for links, where in ((idx_links, "memory/_index.md"), (plan_links, "plan.md section 12")):
        n = links.count(f)
        if n != 1:
            errors.append(f"{f}: listed {n}x in {where} (expected 1)")
for links, where in ((idx_links, "memory/_index.md"), (plan_links, "plan.md section 12")):
    for l in links:
        if l not in files:
            errors.append(f"{where}: links to missing file {l}")

ids = [f[:2] for f in files]
if len(set(ids)) != len(ids):
    errors.append("duplicate feature number in memory/")

heads = re.findall(r"^## (\d+)\. ", (MEM / "_feature_template.md").read_text(encoding="utf-8"), re.M)
for f in files:
    text = (MEM / f).read_text(encoding="utf-8")
    got = re.findall(r"^## (\d+)\. ", text, re.M)
    if got != heads:
        errors.append(f"{f}: section numbers {got} != template {heads}")
    for field in ("Feature ID", "Status", "Priority", "Phase", "Last Updated"):
        if not re.search(rf"^\| {field} \|", text, re.M):
            errors.append(f"{f}: missing metadata row '{field}'")
    if not re.search(rf"F-{f[:2]}\b", text):
        errors.append(f"{f}: Feature ID should be F-{f[:2]}")

for e in errors:
    print("ERROR:", e)
print(f"checked {len(files)} feature files, {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
