#!/usr/bin/env bash
# The map of the code, read from the code itself: every script under scripts/ with its length and the first lines of
# its own "##" description. It replaces a hand-kept file table that went stale (issue #29); a script's description is
# kept where the script is. Usage: tools/dev/map.sh [folder]   (default scripts/)
cd "$(dirname "$0")/../.."
dir="${1:-scripts}"
find "$dir" -name '*.gd' | sort | while read -r f; do
  n=$(wc -l <"$f" | tr -d ' ')
  # the first block of "##" lines (after extends/class_name), joined, cut to one line of about 160 characters
  d=$(awk '/^##/{sub(/^## ?/,""); printf "%s ", $0; got=1; next} got{exit}' "$f" | cut -c1-160)
  printf '%-44s %5s  %s\n' "$f" "$n" "${d:-(no description: add a ## line at the top)}"
done
