# Map of the repository

Farpoint HORIZON (project name Farpoint HORIZON Forever until the final one), by team SK-Horizons. Two parts live
side by side: the game and the team's work on it. Each area and each of its main folders starts with a README that says what is in it, who uses
it and when it changes; `tools/dev/check.sh` fails when one is missing or when a document points at a file that no
longer exists.

## 1. The game (what Godot loads)

| Folder | What is in it |
|---|---|
| `project.godot`, `scenes/` | The project and its one scene, `scenes/main.tscn`, which starts `scripts/core/main.gd` |
| `scripts/` | All the code, one folder per area: `core/` (start-up, the game's state, the catalogs, the mission model), `world/` (the 3D world and its builders), `screens/` (one script per screen), `flight/`, `story/`, `missions/`, `minigames/`, `craft/`, `crew/`, `net/`, `tutorial/`, `ui/`. Each script says what it does in its first `##` lines; `tools/dev/map.sh` lists them |
| `data/` | Content and balance as JSON (missions, parts, orbits, the story, NASA data), each entry with its source |
| `i18n/` | The Spanish texts, one CSV per piece (`keys,es`) |
| `assets/` | Everything seen and heard: `models/`, `parts/`, `textures/`, `photos/` (NASA pictures a mission shows), `story/`, `brand/`, `audio/`, `fonts/`, `shaders/`; `source/` holds the scripts that build our models and textures |
| `tests/` | `ci/`: the checks CI runs on every push; `look/`: the harnesses that save screenshots to judge by eye ([guides/testing.md](guides/testing.md)) |

## 2. The team's work

| Where | What it is for | Updated |
|---|---|---|
| `AGENTS.md` | The one rulebook for every agent and person: criteria, never state | when the team changes a rule |
| `changes/` | One change note per piece of the release in preparation | by each piece; emptied at release |
| [guides/](guides/) | How the game is built and how to work on it: architecture, testing, leading a piece | with the code they describe |
| [design/](design/) | What the game is and how it must feel: vision, criteria, the story, the crew | when the team decides |
| [versions/](versions/) | The versions made at the hackathon (a record; releases from v0.3.0 on are GitHub releases) | never |
| [areas/](areas/) | What each part of the game does and what was checked about it (knowledge, never status) | in the pull request that changes that part |
| [sources.md](sources.md) | The bibliography: every outside number, image, model and dataset, once, with an ID | grows with every source; the credits and the submission links are made from it |
| `kb/` | Research gathered for the game: the domain, NASA data, techniques, decisions | when research is added |
| `tools/` | Scripts for people and agents: `dev/` to build and check, `content/` to make data, credits and art | with the work they serve |

## Where the game comes from

The game was born at the NASA Space Apps Challenge 2026. The challenge it answers is kept in `kb/challenge/`;
everything about the event (its rules, the team's notes, the decks, the submission) stays in the frozen hackathon
repository, https://github.com/alexanderkholodov1/farpoint-horizon, which nobody changes.

## Conventions

- English for the repository; Spanish only in `i18n/`, in the README's Spanish section and in the team's own notes.
- Documents and folders: lowercase words joined by hyphens (`event-and-judging.md`). Code follows its language
  (`snake_case.gd`, `snake_case.py`).
- One fact in one place: a document links to another instead of repeating it, and what can be generated is
  generated (`tools/content/credits.py`, `tools/dev/map.sh`).
