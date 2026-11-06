#!/usr/bin/env python3
"""Language catalogue tooling (FR-29-15).

  check_l10n.py sync    rewrite app/assets/l10n/*.yaml: every `t('...')` key in
                        app/lib appears in en.yaml (value = key) and, blank,
                        in every other language; stale keys are dropped.
                        Existing translations are kept.
  check_l10n.py check   fail when a key used in code is missing from en.yaml,
                        a catalogue holds a key no code uses, or a translation
                        changes the {placeholders} of its key. Prints the
                        coverage per language.
"""
import json, pathlib, re, sys
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "app" / "lib"
CAT = ROOT / "app" / "assets" / "l10n"
LANGS = ["en", "hi", "bn", "te", "mr", "ta", "gu", "kn"]

CALL = re.compile(r"""(?<![A-Za-z0-9_.])t\(\s*(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")""")
PLURAL = re.compile(r"""\.plural\([^,]+,\s*(?:'((?:[^'\\\n]|\\.)*)'),\s*(?:'((?:[^'\\\n]|\\.)*)')""")
ESC = {"n": "\n", "t": "\t", "'": "'", '"': '"', "\\": "\\", "$": "$"}


def unescape(s: str) -> str:
    return re.sub(r"\\(.)", lambda m: ESC.get(m.group(1), m.group(1)), s)


def code_keys() -> set:
    keys = set()
    for f in LIB.rglob("*.dart"):
        if f.name.endswith((".g.dart", ".freezed.dart")):
            continue
        text = f.read_text()
        for m in CALL.finditer(text):
            keys.add(unescape(m.group(1) if m.group(1) is not None else m.group(2)))
        for m in PLURAL.finditer(text):
            keys.update(unescape(g) for g in m.groups())
    return keys


def load(code: str) -> dict:
    p = CAT / f"{code}.yaml"
    if not p.exists():
        return {}
    doc = yaml.safe_load(p.read_text()) or {}
    return {str(k): ("" if v is None else str(v)) for k, v in (doc.get("strings") or {}).items()}


def tokens(s: str) -> set:
    return set(re.findall(r"\{[A-Za-z_][A-Za-z0-9_]*\}", s))


def dump(code: str, strings: dict) -> str:
    out = [
        "# Language catalogue. Key = the English text used in code, value = its",
        "# translation. A blank value shows English until it is translated.",
        "# Keep every {placeholder} exactly as in the key. Edit here, then run",
        "# `python3 tools/check_l10n.py check`.",
        "version: 1",
        f"code: {code}",
        "strings:",
    ]
    for k in sorted(strings, key=str.lower):
        out.append(f"  {json.dumps(k, ensure_ascii=False)}: {json.dumps(strings[k], ensure_ascii=False)}")
    return "\n".join(out) + "\n"


def sync() -> None:
    keys = code_keys()
    CAT.mkdir(parents=True, exist_ok=True)
    for code in LANGS:
        old = load(code)
        new = {k: (k if code == "en" else old.get(k, "")) for k in keys}
        (CAT / f"{code}.yaml").write_text(dump(code, new))
    print(f"synced {len(keys)} keys into {len(LANGS)} catalogues")


def check() -> int:
    keys = code_keys()
    problems = []
    en = load("en")
    for k in sorted(keys - set(en)):
        problems.append(f"en.yaml misses key used in code: {k!r}")
    for code in LANGS:
        cat = load(code)
        for k in sorted(set(cat) - keys):
            problems.append(f"{code}.yaml has a key no code uses: {k!r}")
        done = 0
        for k, v in cat.items():
            if k not in keys or not v.strip():
                continue
            done += 1
            if tokens(v) != tokens(k):
                problems.append(f"{code}.yaml changes placeholders of {k!r}")
        pct = 100 * done / max(len(keys), 1)
        print(f"{code}: {done}/{len(keys)} translated ({pct:.0f}%)")
    for p in problems:
        print("PROBLEM:", p)
    print(f"l10n check: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "sync":
        sync()
    elif cmd == "check":
        sys.exit(check())
    else:
        sys.exit(__doc__)
