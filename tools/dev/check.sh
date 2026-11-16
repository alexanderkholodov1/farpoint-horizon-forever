#!/usr/bin/env bash
# The local checks, the same ones CI runs: the documentation check, a headless import, and every test in tests/ci/.
#
# What a pass proves: the documents name files that exist; the project imports; and each tests/ci/<name>.gd, run
# headless by Godot, exited with code 0 inside the time limit and printed the line its own "## check: <pattern>" asks
# for (the runner anchors it: the line must begin with the pattern). A test with no "## check:" line fails the run.
# The tests exercise the game's rules, numbers and data (and, for story.gd and i18n.gd, the main scene as a running
# node tree).
#
# What it does NOT prove: that anything looks right (headless runs draw nothing: look at tools/dev/shots.sh output),
# that anything sounds right (no audio is played), or that the web build exports and loads in a browser (the export is
# its own script, see issue #1). "It passed" never replaces playing the game.
#
# Usage: tools/dev/check.sh            everything
#        tools/dev/check.sh <name>     only tests/ci/<name>.gd, for an author iterating (no docs check, no import)
set -uo pipefail
cd "$(dirname "$0")/../.."
G=tools/dev/godot.sh
LIMIT=180   # seconds a single test may run
log=$(mktemp)
trap 'rm -f "$log"' EXIT

# Runs one test; prints its output only when it fails. Returns 0 on pass.
run_test() {
  local f=$1 name want code
  name=$(basename "$f" .gd)
  want=$(sed -n 's/^## check: //p' "$f" | head -1 | tr -d '\r')
  if [ -z "$want" ]; then
    echo "FAIL $name: tests/ci/$name.gd has no '## check: <pattern>' line, so nothing says what a pass looks like"
    return 1
  fi
  timeout "$LIMIT" bash "$G" --headless --path . -s "res://tests/ci/$name.gd" >"$log" 2>&1
  code=$?
  if [ "$code" -eq 124 ]; then
    cat "$log"
    echo "FAIL $name: timed out after ${LIMIT} s (tests/ci/$name.gd)"
    return 1
  fi
  if [ "$code" -ne 0 ]; then
    cat "$log"
    echo "FAIL $name: Godot exited with code $code"
    return 1
  fi
  if ! tr -d '\r' <"$log" | grep -qE "^($want)"; then
    cat "$log"
    echo "FAIL $name: exit 0 but no output line begins with: $want"
    return 1
  fi
  echo "ok $name"
}

if [ $# -gt 0 ]; then
  f="tests/ci/$1.gd"
  [ -f "$f" ] || { echo "no such test: $f"; exit 1; }
  run_test "$f" || exit 1
  exit 0
fi

PY=python3
python3 --version >/dev/null 2>&1 || PY=python
echo "0/2 documentation (tools/dev/check_docs.py)"
"$PY" tools/dev/check_docs.py || exit 1
echo "1/2 import"
bash "$G" --headless --path . --import >"$log" 2>&1 || { cat "$log"; echo "FAIL import (issue #3 owns why it can crash)"; exit 1; }
echo "2/2 tests in tests/ci/"
failed=()
for f in tests/ci/*.gd; do
  run_test "$f" || failed+=("$(basename "$f" .gd)")
done
if [ ${#failed[@]} -gt 0 ]; then
  echo "FAILED ${#failed[@]} test(s): ${failed[*]}"
  exit 1
fi
echo "All checks passed"
