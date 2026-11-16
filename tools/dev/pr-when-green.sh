#!/usr/bin/env bash
# Opens a pull request only when CI on the branch's last pushed commit passed.
#   On a version branch (vX.Y.Z): the version pull request into main, the only kind main takes. Its title always leads
#   with the branch's version (`v0.2.0: <what it delivers>`): added when missing, refused when a different one is typed.
#   Only a team member merges it.
#   On any other branch: an optional pull request into the newest version branch, or into the branch given as third
#   argument (another work branch, for example), titled with what it adds and no number. A lead agent integrates it
#   with tools/dev/integrate.sh, which gives the step number.
# Usage: tools/dev/pr-when-green.sh "<what it delivers>" <body-file> [base-branch]
# Exit 0: opened (or already open). Exit 1: CI failed or the branch is not ready. Exit 2: CI still running after 30 minutes.
set -euo pipefail
title=${1:?title}; body=${2:?body file}
[ -f "$body" ] || { echo "No body file: $body"; exit 1; }
branch=$(git rev-parse --abbrev-ref HEAD)
git fetch -q origin
if [[ $branch =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  base=main
  if [[ $title =~ ^v[0-9]+\.[0-9]+\.[0-9]+:\  ]]; then
    [[ $title == "$branch: "* ]] || { echo "The title claims ${title%%:*} but the branch is $branch"; exit 1; }
  else
    title="$branch: $title"
  fi
else
  [ "$branch" != main ] || { echo "Nothing is proposed from main"; exit 1; }
  base=${3:-$(git for-each-ref refs/remotes/origin --format='%(refname:lstrip=3)' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)}
  [ -n "$base" ] || { echo "No version branch to propose into"; exit 1; }
  [ "$base" != main ] || { echo "Only a version branch goes into main, through its version pull request"; exit 1; }
  if [[ $title =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ ]]; then echo "This title carries no number; the step number is given at integration"; exit 1; fi
fi
git fetch -q origin "$branch"
[ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$branch")" ] || { echo "Push first: origin/$branch is not your HEAD"; exit 1; }
if gh pr list --head "$branch" --base "$base" --state open --json url -q '.[0].url' | grep -q .; then echo "Already open"; exit 0; fi
sha=$(git rev-parse HEAD)
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
api="repos/$repo/commits/$sha/check-runs?check_name=Godot%20checks%20and%20web%20build"
for _ in $(seq 1 90); do
  total=$(gh api "$api" --jq '.check_runs | length')
  pending=$(gh api "$api" --jq '[.check_runs[] | select(.status != "completed")] | length')
  if [ "$total" -gt 0 ] && [ "$pending" -eq 0 ]; then
    failed=$(gh api "$api" --jq '[.check_runs[] | select(.conclusion != "success")] | length')
    if [ "$failed" -gt 0 ]; then echo "CI failed on ${sha:0:7}. Fix it on the branch; no pull request opened."; exit 1; fi
    gh pr create --base "$base" --head "$branch" --title "$title" --body-file "$body"
    exit 0
  fi
  echo "Waiting for CI on ${sha:0:7}"
  sleep 20
done
echo "CI still running after 30 minutes"; exit 2
