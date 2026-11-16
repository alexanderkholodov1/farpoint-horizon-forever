# Development tools

| Script | What it does |
|---|---|
| `godot.sh` | Runs Godot 4.7 (uses `$GODOT`, else `godot` on the PATH, else the usual install places) |
| `check.sh` | Everything CI runs: import, a headless run, the fuzz test, every `tests/ci/*.gd` with a `## check:` line, the documentation check and the web export |
| `check_docs.py` | Every folder of `docs/`, `spaceapps/`, `tools/` and `kb/` has its README, and every repository path a document names exists |
| `shots.sh` | Plays the scripted walkthrough with a window and saves screenshots to `shots/` |
| `map.sh` | The map of the code, read from each script's first `##` lines |
| `state.sh` | Where the project is: the notes of `docs/state/`, the steps on the version branch, the open issues |
| `integrate.sh` | Merges a finished work branch into the version branch, checks the result and numbers the step |
| `pr-when-green.sh` | Opens a pull request only when CI is green (into `main`, only the version's) |
