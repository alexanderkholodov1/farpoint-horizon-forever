# Development tools

| Script | What it does |
|---|---|
| `godot.sh` | Runs Godot 4.7 (uses `$GODOT`, else `godot` on the PATH, else the usual install places) |
| `check.sh` | The automatic checks CI runs on every pull request; `check.sh <name>` runs one test (see `docs/guides/testing.md`) |
| `check_docs.py` | Every folder of `docs/`, `tools/` and `kb/` has its README, and every repository path a document names exists |
| `export-web.sh` | Builds the web game into `build/web/` with its version from git (`git describe`), to play it or publish it |
| `release-notes.py` | Joins the change notes of `changes/` into the release's notes (used by the release pull request and workflow) |
| `shots.sh` | Plays the scripted walkthrough with a window and saves screenshots to `shots/` |
| `map.sh` | The map of the code, read from each script's first `##` lines |
