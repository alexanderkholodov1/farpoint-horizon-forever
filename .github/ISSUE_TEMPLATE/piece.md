---
name: A piece of work
about: One piece of the version, written so any agent (or person) can take it and know what done means
title: ""
labels: []
assignees: []
---

<!-- Rules behind every line below: AGENTS.md (How we work, Working beside other agents). Claim the issue by assigning
it to your person, then branch: git fetch origin && git switch -c work/<issue>-<name> origin/<version branch> -->

**What the player gets**
<!-- In a player's words: what they can do or see when this is done. -->

**Owns** (files only this piece writes)
<!-- e.g. scripts/screens/<id>.gd, scripts/<area>/*.gd, i18n/<piece>.csv, tests/ci/<name>.gd, tests/look/<name>.tscn, docs/state/<topic>.md -->

**Uses** (shared pieces it reads, never rewrites)
<!-- e.g. GameState.flight, scripts/ui/kit.gd, scripts/flight/flight_hud.gd. A change to a shared piece is its own
small piece, agreed by both team members. -->

**Real values to check**
<!-- The real numbers this must match, with their source IDs: periods, speeds, durations, sizes. -->

**Done when**
- [ ] It behaves as in real life, in real time by default, and the screen says how fast time runs (`Kit`/`FlightHud` warp).
- [ ] Sizes keep their true proportions; what is too small to see is a marker with a label.
- [ ] The UI is built only from `scripts/ui/kit.gd` (type scale, spacing, colours, components); it reads in both appearances.
- [ ] Played as a player at each speed of time; every screenshot judged in this issue (what a player sees, what was wrong, what was fixed).
- [ ] Numbers checked against the real values above, in a test (`tests/ci/<name>.gd` with a `## check:` line).
- [ ] Every outside value cited where it is used and listed in `docs/sources.md` (`tests/ci/sources.gd` passes).
- [ ] Spanish texts in this piece's own `i18n/<piece>.csv`; `tests/ci/i18n.gd` passes.
- [ ] What is true now about this piece is in its own note, `docs/state/<topic>.md`.
- [ ] `tools/dev/check.sh` green; then integrated with `tools/dev/integrate.sh <branch> "<what it adds>"`.
