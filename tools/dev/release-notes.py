"""Joins the change notes of changes/ into one release's notes.

Every piece adds one note, changes/<short-name>.md (format in changes/README.md), so pieces built in parallel never
edit the same file. When the team has decided the release's number, this writes the notes as that version's section
at the top of CHANGELOG.md and removes the notes it used; that change goes into next by a pull request, before the
release pull request (docs/guides/releasing.md).

Usage: python tools/dev/release-notes.py                  prints the pending notes (Markdown)
       python tools/dev/release-notes.py --check          fails if a note is malformed
       python tools/dev/release-notes.py --release vA.B.C writes CHANGELOG.md's section for vA.B.C, removes the notes
       python tools/dev/release-notes.py --section vA.B.C prints CHANGELOG.md's section for vA.B.C (for the release)
"""
import datetime
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHANGELOG = ROOT / "CHANGELOG.md"
HEADER = "# Changelog\n\nWhat each release gave players, newest first. Written by `tools/dev/release-notes.py`.\n"
KINDS = {"new": "New", "improvement": "Improved", "fix": "Fixed"}


def read_notes():
    notes, problems, files = {k: [] for k in KINDS}, [], []
    for f in sorted((ROOT / "changes").glob("*.md")):
        if f.name == "README.md":
            continue
        if not re.match(r"^[a-z0-9][a-z0-9-]*\.md$", f.name):
            problems.append(f"{f.name}: the name must be <short-name>.md, lowercase words joined by hyphens")
            continue
        text = f.read_text(encoding="utf-8").strip()
        m = re.match(r"^kind:\s*(\w+)\s*\nissue:\s*#?(\d+)\s*\n+(.+)$", text, flags=re.S)
        if not m or m.group(1) not in KINDS:
            problems.append(f"{f.name}: the first lines must be 'kind: new|improvement|fix' and 'issue: <number>', then the note")
            continue
        notes[m.group(1)].append(f"- {' '.join(m.group(3).split())} (#{m.group(2)})")
        files.append(f)
    body = "\n".join(f"### {t}\n" + "\n".join(notes[k]) + "\n" for k, t in KINDS.items() if notes[k])
    return body, problems, files


def section(version):
    if not CHANGELOG.exists():
        return None
    m = re.search(rf"^## {re.escape(version)}\b.*?$(.*?)(?=^## |\Z)", CHANGELOG.read_text(encoding="utf-8"), flags=re.S | re.M)
    return m.group(1).strip() if m else None


def main():
    args = sys.argv[1:]
    if args[:1] == ["--section"]:
        s = section(args[1])
        if s is None:
            print(f"CHANGELOG.md has no section for {args[1]}", file=sys.stderr)
            return 1
        print(s)
        return 0
    body, problems, files = read_notes()
    for p in problems:
        print(p, file=sys.stderr)
    if args[:1] == ["--check"]:
        return 1 if problems else 0
    if args[:1] == ["--release"]:
        v = args[1]
        if problems or not re.match(r"^v\d+\.\d+\.\d+$", v):
            print("fix the notes above, and give the version as vA.B.C", file=sys.stderr)
            return 1
        if not body:
            print("there are no change notes to release", file=sys.stderr)
            return 1
        if section(v) is not None:
            print(f"CHANGELOG.md already has {v}", file=sys.stderr)
            return 1
        old = CHANGELOG.read_text(encoding="utf-8") if CHANGELOG.exists() else HEADER
        head, _, rest = old.partition("\n## ")
        new = f"{head.rstrip()}\n\n## {v} ({datetime.date.today().isoformat()})\n\n{body}\n" + (f"## {rest}" if rest else "")
        CHANGELOG.write_text(new, encoding="utf-8", newline="\n")
        for f in files:
            f.unlink()
        print(f"CHANGELOG.md: {v} written; {len(files)} notes removed")
        return 0
    print(body)
    return 1 if problems else 0


sys.exit(main())
