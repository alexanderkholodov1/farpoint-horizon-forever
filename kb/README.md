# Knowledge base

What every agent and teammate needs to build the game, in one place. This repository is public: nothing private
goes here (no personal data, accounts, credentials or internal notes of any team member's tools).

Read `AGENTS.md` first. Then read only what your task needs; the table says what each file is for.

| Path | What it holds | Read it when |
|---|---|---|
| `research/prior-art.md` | Existing games and tools (Webb telescope game, KSP, JPL Team X, board games...), with patterns to take and pitfalls to avoid | Before game design |
| `research/missions.md`, [data/missions.json](data/missions.json) | 16 candidate missions (Earth, Moon, Mars, Venus, flybys, sample return, telescope, playful ones) with real twin missions, numbers, extra-objective ideas and what makes each fun; most numbers still to be checked against agency pages | Before writing missions, objectives or bonuses |
| `research/nasa-data.md` | The NASA datasets found for the game (issue 19) and what each became | Before adding NASA data or photos |
| `research/in-flight-failures.md` | 17 real in-flight failures and how people solved them, each with a 30-90 second mini-game seed; how deep-space communication works; signal-reading mini-game ideas | Before designing ground control, failures or events |
| `domain/mission-lifecycle.md` | How a real mission goes from need to operations (NASA phases, segments, Concept Maturity Levels, CubeSat process) | Before designing the game's stages |
| `domain/tradeoffs.md` | What each design decision affects, with simple formulas and rules of thumb | Before designing or coding any rule of the simulation |
| [data/reference.json](data/reference.json), [data/README.md](data/README.md) | Real-world reference values with a source for each (orbits, launch vehicles, buses, components, instruments, ground networks) | Before writing game data or balance |
| `tech/platform-options.md` | Godot, web and hybrid options with current facts, and what is installed | Before choosing or setting up the engine |
| `tech/godot-agent-tooling.md` | Tools that let agents operate Godot (MCP servers, headless runs and screenshots, tests, Blender for 3D models, asset sources and licenses), with a recommended toolkit and its risks | Before setting up an agent to work on the game |
| `tech/collaboration.md` | How two people with several AI agents share this repository without collisions | Before your first commit |
| `decisions.md` | Decisions taken (with who decided and when) and decisions still open | Always; a decision here overrides anything older |

## Sources
The challenge the game was born from (its text, resources and requirement IDs) lives in `kb/challenge/`; the event's
rules and the team's notes stay in the frozen hackathon repository (https://github.com/alexanderkholodov1/farpoint-horizon, folder `spaceapps/`). Every fact in this folder cites its source;
anything inferred is labeled "(inference)".

## Keeping it current
- A new decision goes to `decisions.md` with its date and who took it.
- A fact that turns out wrong is corrected where it lives, with the correct source.
- The game's vision and design criteria live in `docs/design/`; what each part of the game does in `docs/areas/`; what is in progress lives in the issues and pull requests.
