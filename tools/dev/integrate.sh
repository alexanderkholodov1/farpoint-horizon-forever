#!/usr/bin/env bash
# Integrates a finished branch into the version branch:
#   tools/dev/integrate.sh <branch> "<what it adds>" [version-branch]
# Run by a lead agent (or a team member) once the piece works; no need to ask. It never touches main and never
# deletes a branch. The complete version branch reaches main only through its one pull request, merged by a person.
#
# 1. The branch's last pushed commit must have passed CI (it waits while CI is still running).
# 2. In a scratch copy, it merges the branch into the newest version branch and commits
#    it as the next step number (`0.1.6: <what it adds>`); the branch's own commits and authors are kept.
# 3. It runs tools/dev/check.sh (what CI runs) on that result, so the version branch never turns red.
# 4. It pushes. If someone integrated first, it starts again on top of theirs, so numbers never collide.
# 5. It comments on the branch's open pull request (GitHub then shows it merged into the version branch), or on the
#    issue named in the branch (work/<issue>-<name>).
set -euo pipefail
branch=${1:?branch to integrate}; what=${2:?what it adds}
case $branch in main|v[0-9]*.[0-9]*.[0-9]*) echo "$branch is not a piece of work"; exit 1;; esac
if [[ $what =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ ]]; then echo "Say what it adds without a number; the number is given here"; exit 1; fi
root=$(git rev-parse --show-toplevel)
git fetch -q --prune origin
base=${3:-$(git for-each-ref refs/remotes/origin --format='%(refname:lstrip=3)' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)}
[[ $base =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+$ ]] || { echo "No version branch to integrate into"; exit 1; }
line="${BASH_REMATCH[1]}.$((BASH_REMATCH[2] - 1))"
git rev-parse -q --verify "origin/$branch" >/dev/null || { echo "origin/$branch does not exist: push it first"; exit 1; }
sha=$(git rev-parse "origin/$branch")
if git merge-base --is-ancestor "$sha" "origin/$base"; then echo "$branch (${sha:0:7}) is already in $base"; exit 0; fi

# 1. CI on the branch's last pushed commit (only the CI job: a pull request's other checks do not block this).
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
api="repos/$repo/commits/$sha/check-runs?check_name=Godot%20checks%20and%20web%20build"
for i in $(seq 1 60); do
  total=$(gh api "$api" --jq '.check_runs | length')
  pending=$(gh api "$api" --jq '[.check_runs[] | select(.status != "completed")] | length')
  if [ "$total" -gt 0 ] && [ "$pending" -eq 0 ]; then break; fi
  [ "$i" -eq 60 ] && { echo "CI has not finished on ${sha:0:7} after 20 minutes. Nothing integrated."; exit 1; }
  echo "Waiting for CI on ${sha:0:7} of $branch"; sleep 20
done
failed=$(gh api "$api" --jq '[.check_runs[] | select(.conclusion != "success")] | length')
if [ "$failed" -gt 0 ]; then echo "CI failed on ${sha:0:7} of $branch: its author fixes it there. Nothing integrated."; exit 1; fi

scratch=$(mktemp -d)
cleanup() { cd "$root"; git worktree remove --force "$scratch/v" >/dev/null 2>&1 || true; rm -rf "$scratch"; }
trap cleanup EXIT
for attempt in 1 2 3 4 5; do
  git fetch -q origin "$base"
  git worktree remove --force "$scratch/v" >/dev/null 2>&1 || true
  git worktree add -q --detach "$scratch/v" "origin/$base"
  cd "$scratch/v"
  # 2. The next step number of this line, from the steps already on the version branch.
  last=$(git log --first-parent --format=%s HEAD | grep -oE "^${line//./\.}\.[0-9]+:" | tr -d ':' | sort -V | tail -1 || true)
  if [ -n "$last" ]; then next="$line.$(( ${last##*.} + 1 ))"; else next="$line.1"; fi
  if ! git merge -q --no-ff --no-commit "$sha" >/dev/null 2>&1; then
    # A generated file in conflict (the credits, made from docs/sources.md and the README) is made again from the
    # merged sources instead of stopping: two pieces that each add a source always meet there.
    if [ "$(git diff --name-only --diff-filter=U)" = "data/credits.json" ]; then
      git checkout -q --theirs data/credits.json
      (python3 tools/content/credits.py >/dev/null 2>&1 || python tools/content/credits.py >/dev/null) && git add data/credits.json
    fi
  fi
  if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
    echo "$branch conflicts with $base in: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
    echo "Its author merges $base into it (git merge origin/$base), resolves, pushes, and this runs again. Nothing integrated."
    git merge --abort; exit 1
  fi
  git commit -q -m "$next: $what" -m "Integrated from $branch (${sha:0:7}) by tools/dev/integrate.sh."
  # 3. What CI runs, on the merged result.
  echo "Checking the merged result ($next) with tools/dev/check.sh"
  if ! bash tools/dev/check.sh > "$scratch/check.log" 2>&1; then
    tail -40 "$scratch/check.log"
    echo "The merged result fails tools/dev/check.sh (above), though $branch alone passed: the two pieces clash. Nothing integrated."
    exit 1
  fi
  # 4. Push; if the version branch moved meanwhile, start again on top of it.
  if git push -q origin "HEAD:$base" 2>/dev/null; then
    result=$(git rev-parse --short HEAD); cd "$root"
    echo "Integrated $branch into $base as $next ($result)"
    # 5. Tell the author where it went.
    note="Integrated into \`$base\` as step \`$next\` ($result) by \`tools/dev/integrate.sh\`: CI passed on ${sha:0:7} and \`tools/dev/check.sh\` passed on the merged result. \`main\` is untouched; it changes only through the version pull request, merged by a person."
    pr=$(gh pr list --head "$branch" --base "$base" --state open --json number -q '.[0].number' 2>/dev/null || true)
    issue=$(sed -nE 's#^work/([0-9]+)-.*#\1#p' <<<"$branch")
    if [ -n "$pr" ]; then gh pr comment "$pr" --body "$note GitHub shows this pull request as merged into \`$base\` because its commits are there now." >/dev/null || true
    elif [ -n "$issue" ]; then gh issue comment "$issue" --body "$note" >/dev/null || true; fi
    exit 0
  fi
  echo "$base moved while checking (attempt $attempt); starting again on top of it"
  cd "$root"
done
echo "$base kept moving; nothing integrated. Run this again."; exit 1
