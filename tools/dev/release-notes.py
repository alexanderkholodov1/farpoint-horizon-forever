"""Joins the change notes of changes/ into one release's notes.

Every piece adds one note, changes/<issue>-<short-name>.md (format in changes/README.md), so pieces built in parallel
never edit the same file. This prints the notes grouped by kind, for the release pull request's body and for the
GitHub release. Usage: python tools/dev/release-notes.py            prints the notes (Markdown)
                       python tools/dev/release-notes.py --check    fails if a note is malformed
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KINDS = {"new": "New", "improvement": "Improved", "fix": "Fixed"}
notes, problems = {k: [] for k in KINDS}, []
for f in sorted((ROOT / "changes").glob("*.md")):
    if f.name == "README.md":
        continue
    if not re.match(r"^\d+-[a-z0-9-]+\.md$", f.name):
        problems.append(f"{f.name}: the name must be <issue>-<short-name>.md")
        continue
    text = f.read_text(encoding="utf-8").strip()
    m = re.match(r"^kind:\s*(\w+)\s*\n+(.+)$", text, flags=re.S)
    if not m or m.group(1) not in KINDS:
        problems.append(f"{f.name}: the first line must be 'kind: new|improvement|fix', then the note")
        continue
    issue = f.name.split("-", 1)[0]
    notes[m.group(1)].append(f"- {' '.join(m.group(2).split())} (#{issue})")
for p in problems:
    print(p, file=sys.stderr)
if "--check" in sys.argv:
    sys.exit(1 if problems else 0)
for k, title in KINDS.items():
    if notes[k]:
        print(f"### {title}\n" + "\n".join(notes[k]) + "\n")
sys.exit(1 if problems else 0)
