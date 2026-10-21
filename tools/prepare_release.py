#!/usr/bin/env python3
"""Release preparation (memory 32): bump pubspec, date the changelog, write notes.

  prepare_release.py bump [--version X.Y.Z] [--date YYYY-MM-DD]   edits app/pubspec.yaml + CHANGELOG.md
  prepare_release.py notes --version X.Y.Z --sha HEX              prints release notes (FR-32-09 format)

`bump` prints `version=...` and `build=...` for `$GITHUB_OUTPUT`. Without
--version the name is kept and only the build number grows.
"""
import argparse
import datetime
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "app" / "pubspec.yaml"
CHANGELOG = ROOT / "CHANGELOG.md"
VERSION_LINE = re.compile(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", re.M)
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def read_version(pubspec_text: str) -> tuple[str, int]:
    m = VERSION_LINE.search(pubspec_text)
    if not m:
        raise ValueError("pubspec.yaml has no `version: X.Y.Z+N` line")
    return m.group(1), int(m.group(2))


def bump_pubspec(text: str, version: str | None = None) -> tuple[str, str, int]:
    name, build = read_version(text)
    if version is not None and not SEMVER.match(version):
        raise ValueError(f"bad version {version!r}; use X.Y.Z")
    name = version or name
    build += 1
    return VERSION_LINE.sub(f"version: {name}+{build}", text, count=1), name, build


def promote_changelog(text: str, version: str, date: str) -> str:
    """Turns `## [Unreleased]` content into `## [version] - date`, leaving a fresh Unreleased."""
    head = "## [Unreleased]"
    if head not in text:
        raise ValueError("CHANGELOG.md has no `## [Unreleased]` section")
    if f"## [{version}]" in text:
        raise ValueError(f"CHANGELOG.md already has {version}")
    return text.replace(head, f"{head}\n\n## [{version}] - {date}", 1)


def section_bullets(text: str, version: str, limit: int = 40) -> list[str]:
    m = re.search(rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\Z)", text, re.M | re.S)
    if not m:
        return []
    return [l.strip() for l in m.group(1).splitlines() if l.startswith("- ")][:limit]


def make_notes(version: str, bullets: list[str], sha: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        raise ValueError("sha must be 64 lower-case hex characters")
    lines = [f"DhanKosh {version}", ""]
    lines += bullets or [f"- DhanKosh {version}"]
    return "\n".join(lines + ["", f"sha256: {sha}", ""])


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("bump")
    b.add_argument("--version")
    b.add_argument("--date", default=datetime.date.today().isoformat())
    n = sub.add_parser("notes")
    n.add_argument("--version", required=True)
    n.add_argument("--sha", required=True)
    a = ap.parse_args(argv)
    try:
        if a.cmd == "bump":
            new_pub, name, build = bump_pubspec(PUBSPEC.read_text(encoding="utf-8"), a.version)
            new_log = promote_changelog(CHANGELOG.read_text(encoding="utf-8"), name, a.date)
            PUBSPEC.write_text(new_pub, encoding="utf-8")
            CHANGELOG.write_text(new_log, encoding="utf-8")
            print(f"version={name}\nbuild={build}")
        else:
            sys.stdout.write(
                make_notes(a.version, section_bullets(CHANGELOG.read_text(encoding="utf-8"), a.version), a.sha)
            )
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
