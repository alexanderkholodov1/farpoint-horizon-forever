#!/usr/bin/env bash
# Where the project is now, assembled from pieces that nobody shares (issue #28):
#   the notes in docs/state/ (one file per topic), the steps integrated on the version branch (its history), and the
#   open issues with who holds each (GitHub, when gh is available).
# Usage: tools/dev/state.sh [version-branch]   (default: the newest v* branch on origin)
set -uo pipefail
cd "$(dirname "$0")/../.."
git fetch -q origin 2>/dev/null || true
base=${1:-$(git branch -r --format='%(refname:short)' | grep -oE 'origin/v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's#origin/##' | sort -V | tail -1)}
echo "# State of $base ($(date -u +%Y-%m-%d\ %H:%MZ))"
for f in docs/state/*.md; do
  [ "$(basename "$f")" = README.md ] && continue
  echo; echo "----- $f"; cat "$f"
done
echo; echo "----- Steps integrated on $base, newest first"
git log --first-parent --format='%s  (%as)' "origin/$base" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+: ' | head -40
if command -v gh >/dev/null 2>&1; then
  echo; echo "----- Open issues (who holds each)"
  gh issue list --state open --limit 100 --json number,title,assignees \
    --template '{{range .}}#{{.number}} {{.title}}  [{{range $i, $a := .assignees}}{{if $i}}, {{end}}{{$a.login}}{{else}}free{{end}}]{{"\n"}}{{end}}' 2>/dev/null \
    || echo "(gh is not signed in: see the issues on GitHub)"
fi
