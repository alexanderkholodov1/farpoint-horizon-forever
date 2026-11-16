# Testing

Two kinds of tests live in `tests/`: the checks in `tests/ci/` and the look harnesses in `tests/look/`. A piece is
done only after both, plus a person's (or an agent's) judgment as a player (`AGENTS.md`, "Done means you judged it").

## The checks (CI, every push)

`bash tools/dev/check.sh` runs what CI runs: the import, a short headless run of the main scene, the fuzz test, every
check below, the documentation check and the web export. A check is a `tests/ci/<name>.gd` script with a line
`## check: <pattern>`: `check.sh` finds it by folder, runs it headless and passes when the output matches the
pattern. A new check is only a new file.

| Check | What it proves |
|---|---|
| `flight.gd` | The climb, the trip to the Moon and the landing against real values (orbit 87.7 min, Apollo 11's burns, LOLA ground) |
| `crew.gd`, `room.gd` | The bots play every scenario; the room's protocol on one screen and online |
| `apollo13.gd`, `sts61.gd`, `pathfinder.gd`, `lcross.gd`, `dart.gd` | Each story mission's rules against NASA's numbers |
| `story.gd` | Every scene of `data/story/` plays through |
| `ground.gd`, `space_weather.gd` | Ground control's mini-games; the solar storms on 400 random designs |
| `sources.gd`, `credits.gd` | Every cited source exists in `docs/sources.md`, and every source is in the credits |
| `i18n.gd` | No text the player can meet is left without Spanish |
| `fuzz.gd` (run by `check.sh` directly) | 600 random designs simulate without errors |

## The look harnesses (by hand, need a window)

The scenes in `tests/look/` (`tripshot`, `sts61shot`, `deviceshot`, `play`, ...) drive the game and save screenshots to
`shots/` (not committed), so a person can judge what a player sees. Run one with
`bash tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/<name>.tscn`; `tools/dev/shots.sh` runs the
walkthrough. Each says in its first `##` lines what it looks at. A screenshot only counts once someone looked at it
and wrote down what is wrong.

## Sources

Open every link of `docs/sources.md`. A page that answers is not yet a
page that says what we cite: open it and find the cited words or numbers before trusting it.
