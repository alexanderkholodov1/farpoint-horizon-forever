"""The documentation stays true: run by tools/dev/check.sh (and CI) on every push.

1. Every area of the repository (docs/, tools/, kb/) and each folder directly inside docs/ and tools/ has a
   README.md that says what is in it.
2. Every repository path a Markdown document names (in `code` or as a [link](path)) exists, so a document never points
   at a file that was moved or deleted. Patterns (`*`, `<name>`, `{a,b}`), URLs, res:// paths and folders that are
   made at run time (build/, shots/, .godot/) are not checked, nor records of a past moment (HISTORY below).

Prints each problem and exits 1 when there is any; prints "docs check: ok" otherwise.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOP = ("docs/", "tools/", "kb/", "scripts/", "data/", "assets/", "tests/", "i18n/", "scenes/",
       "assets/textures/", "assets/audio/", "assets/fonts/", "assets/shaders/", "web/", ".github/")
ROOT_FILES = ("README.md", "AGENTS.md", "CLAUDE.md", "LICENSE", "project.godot", "export_presets.cfg", "icon.svg",
              "firebase.json", "database.rules.json", ".gitignore", ".gitattributes")
# Records of a past moment name what existed then: the plans of shipped versions, the decision log, dated research.
HISTORY = ("docs/versions/v0.1.0.md", "docs/versions/v0.2.0.md", "kb/decisions.md", "kb/tech/")
SKIP_PREFIX = ("build/", "shots/", ".godot/", "user://", "res://")
problems = []

# 1. READMEs
need = [ROOT / a for a in ("docs", "tools", "kb")]
for area in ("docs", "tools"):
    need += [d for d in (ROOT / area).iterdir() if d.is_dir() and not d.name.startswith(".") and d.name != "__pycache__"]
for d in need:
    if not (d / "README.md").exists():
        problems.append(f"{d.relative_to(ROOT).as_posix()}/ has no README.md")

# 2. paths named in documents
tracked = subprocess.run(["git", "ls-files", "*.md"], cwd=ROOT, capture_output=True, text=True).stdout.split()
for rel in tracked:
    md = ROOT / rel
    if not md.exists() or rel.startswith(HISTORY):
        continue
    text = md.read_text(encoding="utf-8", errors="ignore")
    cands = [(m.group(1), "root") for m in re.finditer(r"`([^`\s]+)`", text)]
    cands += [(m.group(1), "here") for m in re.finditer(r"\]\(([^)\s]+)\)", text)]
    for raw, base in cands:
        p = raw.split("#")[0].rstrip(".,;:)")
        p = re.sub(r":\d+(-\d+)?$", "", p)
        if not p or "://" in p or p.startswith(("mailto:", "#")) or re.search(r"[*<>{}$|]", p):
            continue
        if base == "root":
            if not (p.startswith(TOP) or p in ROOT_FILES):
                continue
            if p.startswith(SKIP_PREFIX):
                continue
            target = ROOT / p
        else:
            target = (md.parent / p).resolve()
            try:
                if target.relative_to(ROOT).as_posix().startswith(SKIP_PREFIX):
                    continue
            except ValueError:
                continue
        if not target.exists():
            ignored = subprocess.run(["git", "check-ignore", "-q", str(target)], cwd=ROOT).returncode == 0
            if ignored:   # a generated file git leaves out on purpose (a .translation, a build): made on demand
                continue
            problems.append(f"{rel}: names `{raw}`, which does not exist")

for p in problems:
    print(p)
print("docs check: ok" if not problems else f"docs check: {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
