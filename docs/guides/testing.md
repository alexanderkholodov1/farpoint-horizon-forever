# Testing

Two kinds of tests live in `tests/`: the checks in `tests/ci/` and the look harnesses in `tests/look/`. A piece is
done only after both, plus a person's (or an agent's) judgment as a player (`AGENTS.md`, "Done means you judged it").

## The checks (CI, every pull request)

`bash tools/dev/check.sh` runs what CI runs: the documentation check, one headless import, and every test in
`tests/ci/`; `tools/dev/check.sh <name>` runs one test while you work on it. A test is a `tests/ci/<name>.gd` script
with a line `## check: <pattern>`: it passes only when Godot exits with code 0 within the time limit and the output
has a line that begins with the pattern; a test without that line, a non-zero exit or a timeout fails the run, by
name. A new test is only a new file, and it must call `quit(1)` when a check fails.

**What a pass proves:** the documents name files that exist, the project imports, and each test's rules, numbers and
data hold. **What it does not prove:** that anything looks or sounds right (headless runs draw nothing and play no
audio), or that the web build loads in a browser. That is the reviewer's, by playing (`AGENTS.md`, "Review"). Before
you trust a test, read what it asserts; a test that compares a value with a copy of itself proves nothing, and each
test here was broken once on purpose to see it fail (issue #2).

| Test | What it proves |
|---|---|
| `flight.gd`, `flowaudit.gd` | The climb, the trip to the Moon and the landing against real values; a pilot who does nothing still reaches orbit; each circular orbit's period against Kepler's law |
| `crew.gd`, `room.gd` | The bots' designs launch in every scenario; the room's protocol and who may edit each station |
| `apollo13.gd`, `artemis1.gd`, `sts61.gd`, `pathfinder.gd`, `lcross.gd`, `dart.gd`, `reentry.gd` | Each story mission's rules, and the cross-checks of NASA's numbers that do not just repeat the data |
| `story.gd` | Every scene of `data/story/` plays through and its speakers are in the cast |
| `data.gd` | Every cited source exists, every player-facing text has a real Spanish version, every reference between catalogs exists |
| `ground.gd`, `space_weather.gd` | Ground control's astronomy and mini-games; the solar storms on 400 random designs |
| `sources.gd`, `credits.gd` | Every source cited in code or data is listed in `docs/sources.md`, and every source is in the credits |
| `i18n.gd` | Both languages are really played, and no text the player can meet is left without Spanish |

## The look harnesses (by hand, need a window)

The scenes in `tests/look/` (`tripshot`, `sts61shot`, `deviceshot`, `play`, ...) drive the game and save screenshots to
`shots/` (not committed), so a person can judge what a player sees. Run one with
`bash tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/<name>.tscn`; `tools/dev/shots.sh` runs the
walkthrough. Each says in its first `##` lines what it looks at. A screenshot only counts once someone looked at it
and wrote down what is wrong.

## Sources

Open every link of `docs/sources.md`. A page that answers is not yet a
page that says what we cite: open it and find the cited words or numbers before trusting it.
