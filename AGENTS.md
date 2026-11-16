# Agent guide: Farpoint HORIZON

The one rulebook for every agent in this repository, whoever runs it (Claude Code, Codex, Cursor, Gemini or any
other) and whichever team member it works for. `CLAUDE.md` only imports this file.

The game: **Farpoint HORIZON** (always written this way), a 3D space-mission game in Godot 4.7 for the 2026 NASA Space
Apps Challenge, challenge "Space Mission Design Game", by team **SK-Horizons** (Quito, Ecuador; always written this way, with the hyphen and the final s, never "SK Horizon"). Alone or with up to three friends, players build a craft, plan its
route, launch it, fly it to its target, land it or keep it talking to Earth, and enjoy what they achieved.

## Read first
1. `tools/dev/state.sh`: where the project is today and what comes next, assembled from one note per topic
   (`docs/state/`), the steps on the version branch and the open issues.
2. `docs/design/vision.md`: what the game will be and what it will have. Every change serves it.
3. `kb/README.md`, then `spaceapps/challenge/requirements.md` (the challenge as IDs) and `kb/decisions.md` (what the team
   decided; open items are theirs to decide).
4. `docs/guides/architecture.md` before touching code; `docs/design/criteria.md` before touching anything players see.
5. If you lead a piece of work (you plan it, brief other agents and integrate their results), `docs/guides/leading.md`.

## Who decides
- **The two team members decide**: the idea, the design, scope, accounts, anything public. Agents bring evidence,
  alternatives and a recommendation, and are free to propose anything, concepts included.
- **Only a person merges into `main`**, either team member, never an agent. Lead agents integrate finished work
  branches into the version branch themselves, with no need to ask, once the checks are green; the complete version
  branch goes to `main` only through one pull request that a team member reviews and merges.
- Agents talk with their person in that person's language. The repository and the game are in English by default; the
  game also offers Spanish, and the project description and deliverables for the platform exist in Spanish too
  (the local venue requires both; the live pitch in Sangolquí is in Spanish).

## How we work
- **Fun and satisfaction first.** The player should feel the pride of watching their own craft lift off, deploy,
  arrive and land. Missing something is never a failure screen; achieving more is rewarded. Kerbal Space Program is
  the main inspiration (the builder, route and orbit planning, the whole journey, freedom to invent, humor, the
  spectacle of launch and landing); its difficulty and its fail-and-retry loop are not.
- **Nothing that looks AI-made.** `docs/design/criteria.md` holds the team's design criteria; they apply to models,
  UI, motion, sound and copy.
- **Real data at the core, and everything cited.** The judges score how much NASA data is part of the game, and they
  will read our sources. Every number, formula, fact, dataset, image, model or sound that comes from outside carries
  its source where it is used (a data field, a code comment, a document line) and is listed once in
  `docs/sources.md` with an ID, in a form fit to show the judges. Our own simplifications say so and cite what they
  simplify. The README and the game's credits are built from that list. Research notes in `kb/` keep their URLs.
- **Data apart from code.** Missions, parts, launchers, orbits, events and texts live in data (today
  `scripts/core/game_data.gd`), so content and balance change without touching logic.
- **Measure before you claim.** Run it, read the log, look at the screenshot; cite the file and line or the command.
  A guess is labeled as a guess.
- **Real behavior, never a drawing of it.** Everything that moves behaves as in real life: launch, orbits, transfers,
  landings. Paths come from the physics (the gravity of every body involved, with real constants and ephemerides),
  never from a hand-drawn curve or a straight dash. Speeds, orbital periods, burn lengths, trip times and distances
  are the real ones or follow from real physics, and the code cites where each comes from. A trip to another body is
  planned as a real one: the departure is timed so the craft meets the body where it will be (phasing), with the
  corrections real missions make. Where we simplify, the code says what and why.
- **Real time, said on screen.** Every simulation runs in real time by default. Faster time is a visible control
  (×1, ×10, ×100 ... as in `scripts/flight/flight_hud.gd`, keys `,` and `.`), the screen always says how fast time
  runs, and a clock shows the true mission time. Never compress time silently, and never make the player wait: time
  runs by itself to the next moment that needs the player and slows for it (a countdown in real time). With an
  engine on, at most ×100; near the ground, real time only.
- **True scale, made readable.** Sizes and distances keep their true proportions. What is too small to see gets a
  marker of constant screen size and a label; it is never scaled up (a craft is never drawn half a planet's size).
  What the player must act on (the orbit, the path, the target, where the target will be) is in view.
- **Mechanics before content.** The core mechanics (time, building, launch, orbit, transfer, landing, ground control)
  are made right and real before new missions or content are added on top. A new mission waits until every
  mechanic it uses has passed the rule below.
- **Done means you judged it, as a player.** Before integrating, play it yourself at each speed of time, look at every
  screenshot and write down what a player sees and what is wrong (sizes, what is visible, whether motion and timing
  look and feel real), check the numbers against real values, and iterate until it is right. "It runs and the tests
  pass" is not done; neither is a screenshot you did not judge. Then integrate it yourself, with no need to wait for
  a person, and say in the issue what you checked. Never integrate what you have not judged this way.
- **Proven by playing.** A feature is done when someone played it as a player would and looked at the screen;
  say what you checked.
- **Plain explanations.** Every concept a player meets is explained in simple words inside the game (challenge E1-E4).

## The cycle of a version
1. The version branch collects finished pieces. Its pull request into `main` opens only when the version is complete.
   More than one line can run at once (`docs/versions/README.md` says which, today `v0.2.3` for fixes and
   `v0.3.0` for the story); pick the branch by your issue's milestone. `tools/dev/pr-when-green.sh` and `tools/dev/state.sh` default
   to the newest version branch, so for a fix pass the fix line's branch to them.
2. Every piece of work is a GitHub issue, written with `.github/ISSUE_TEMPLATE/piece.md` (what the player gets, the
   files it owns, the real values to check, the done-when list). Claim it by assigning it to your person before starting.
3. Build it on a branch of your own, made from the version branch and named after the issue:
   `git fetch origin && git switch -c work/12-rockets origin/v0.3.0`. Commit small working steps in English, with no
   version numbers, and push often (CI runs on every push and must stay green; a red check is fixed first).
4. Stay current by merging, never by rewriting: `git fetch origin && git merge origin/v0.3.0`. When your piece needs
   another piece that is not integrated yet, merge that branch into yours (`git merge origin/work/6-builder`), or
   propose yours into it with a pull request. Never rebase or force-push a pushed branch: others may have merged it.
5. When the piece works (CI green, played as a player, screenshots in the issue, every outside value cited), say so
   in its issue. A pull request into the version branch is optional (`tools/dev/pr-when-green.sh "<what it adds>"
   <body-file>`), for example to ask for a review.
6. A lead agent (or a team member) integrates it, with no need to ask: `tools/dev/integrate.sh <branch> "<what it adds>"`.
   It checks the branch's CI, merges the branch into the version branch in a scratch copy, runs `tools/dev/check.sh` on
   the result and only then pushes, as one commit named with the next step number (`0.1.6: <what it adds>`). If
   someone integrated first, it starts again on top, so numbers never collide. It comments on the branch's open pull
   request (GitHub then shows it merged into the version branch) or on its issue. It never touches `main` and never
   deletes a branch, so the piece can keep growing and be integrated again.
7. Someone who did not build a piece reviews it; findings are verified before they are fixed, and fixed at their
   cause.
8. When the version is complete and verified, its pull request into `main` opens with `tools/dev/pr-when-green.sh`. Only a
   team member merges it, never an agent. The release workflow tags it and publishes it; then someone checks the live
   game.

## Versions
- `v0.1.0` is the first playable sketch with this base, `v0.2.x` the whole mission the vision asks for, `v0.3.0` the
  story campaign. The line stays `v0.X.Y` until the team calls the game impeccable; only then `v1.0.0`.
- Only the version branch carries version numbers. Each integrated piece is one commit whose message starts with its
  step number, the patch numbers of the current line (`0.1.5`, `0.1.6`, ...), never a `-1`/`-2` suffix. The number
  is given at integration, so pieces built in parallel never collide on one. Work branches carry no numbers.
- The version itself comes from the branch name, never from memory: `tools/dev/pr-when-green.sh` puts it at the head of
  the pull request title into `main`, and the release workflow tags the merge with it.

## Pull requests
- **Into `main`: only the version pull request**, from the version branch, one per functional version, never one per
  fix. It opens only when CI is green (`tools/dev/pr-when-green.sh "<what it delivers>" <body-file>`); its title leads
  with the version (`v0.2.0: <what a player can now do>`). Only a team member merges it. CI fails any other pull
  request into `main`.
- **Into any other branch** (the version branch, someone's work branch): allowed and optional, titled with what it
  adds and no number. Lead agents integrate into the version branch with `tools/dev/integrate.sh`, never into `main`.
- Bodies follow `.github/pull_request_template.md`. Commits and pull requests carry no AI co-author lines or
  generated-by signatures (`.claude/settings.json` turns them off for Claude Code; set the same in other tools). AI
  use is disclosed in the README instead.

## Working beside other agents
- Nobody owns a part: both team members work side by side. Each piece is claimed through its issue and built on its
  own branch, so two agents never write the same branch; several agents on one machine use separate git worktrees.
- Each piece owns the files its issue lists. If your piece must change files that another open issue is
  changing, say so in both issues and agree who goes first. A change to something everyone uses (data formats, the
  mission model, `GameState`, `project.godot`, this file) is its own small piece, agreed by both team members and
  integrated first, so the others build on it.
- Files every piece touches: none by hand. The state is one note per topic in `docs/state/` (keep the notes of your
  own pieces, delete them when they stop being true) and `tools/dev/state.sh` assembles it with the steps and the open
  issues; describe your piece in its issue. `docs/sources.md` only grows: add entries at the end of the right section
  with a short unique word as ID (`S-gibs-viirs`), never a new number; git keeps both sides when two branches add
  entries at the same place.
- No shared lists or files: a piece adds its own files and never edits a list or file every piece edits, so three or
  more agents work at once without conflicts (issues #26, #28); a new thing every piece would have to register is
  found by folder instead. Its Spanish texts go in its own `i18n/<piece>.csv` (`keys,es`; `translations.csv` is the old
  base and takes no new lines); a new screen is only `scripts/screens/<id>.gd`; a new check is only `tests/ci/<name>.gd`
  with a `## check: <pattern>` line. The game and `tools/dev/check.sh` find them by folder.
- Never rewrite, reformat or revert someone else's work, and never push to someone else's branch; ask in the issue,
  or propose your change with a pull request into their branch.
- Leave every branch better than you found it: the game runs and the checks pass.

## Godot
- Godot 4.7.2, renderer GL Compatibility (it runs in browsers and on integrated GPUs). The web build is the
  single-threaded export (`export_presets.cfg`, preset "Web"), so any static host works.
- `tools/dev/godot.sh` finds the Godot binary (or set `GODOT`); `tools/dev/check.sh` runs what CI runs: import, a short
  headless run of the main scene, the fuzz test, every check in `tests/ci/`, the documentation check and the web export
  (`docs/guides/testing.md`). `tools/dev/shots.sh` plays the scripted walkthrough with
  a window and saves screenshots to `shots/` (headless runs draw nothing).
- Every pull request gets its own temporary page on Firebase Hosting, linked on the pull request by CI (it expires
  after 7 days); production (https://farpoint-horizon.web.app) is deployed only when the version pull request is
  merged into `main`.
- Commit the `.import` and `.uid` files Godot creates beside the files you add (run `tools/dev/check.sh` first: its import
  step creates them). They carry random IDs, so a file left for someone else to import collides between branches.
- One UI standard: every screen builds its interface only from `scripts/ui/kit.gd`: its type scale (`Kit.T_*`),
  spacing (`Kit.MARGIN`, `Kit.PAD`, `Kit.GAP`, `Kit.BTN_H`), colours (`Kit.C_*`, readable in both appearances) and
  components (`panel_box`, `caps`, `rule`, `segmented`/`choice`, `stat`, `readout`, `hint_box`, `btn`, `card`...).
  No loose font sizes, paddings or colours in a screen, and no need to copy another screen from a screenshot; a
  piece the kit lacks is added to the kit, for everyone.
- GDScript is Godot 4 syntax (`await`, `@onready`, `@export`, typed signals); the project's own pitfalls are in
  `docs/guides/architecture.md`. Tools that let agents drive Godot, Blender and the browser: `kb/tech/godot-agent-tooling.md`.

## What the event requires (sources: `spaceapps/rules/event-and-judging.md`, global; `spaceapps/rules/local-event.md`, the venue)
- AI tools are allowed and their use is disclosed: the README names the agents used and cites every source.
- No NASA logos, insignia, flags or mission identifiers in anything generated, and nothing implying NASA endorses us;
  crediting NASA data in text is expected.
- No image, video, voice or likeness of anyone under 18.
- No AI-generated images: models come from our scripts, textures and imagery from cited sources, so no watermark is
  needed (the venue deducts a point for an AI image without one).
- Every outside asset (code, fonts, images, sounds, models, data) is listed with its source and license.
- English by default; Spanish versions of the description and deliverables for the venue. At most 7 slides; a demo
  video of at most 30 s; every link opens in a private window.

## Layout
The map is `docs/README.md`. Three areas, each with a README that says what it holds, who uses it and when it changes;
`tools/dev/check.sh` fails when a README is missing or a document names a path that does not exist.
- **The game** (what Godot loads): `project.godot`, `scenes/`, `scripts/` (one folder per area),
  `data/`, `i18n/`, `assets/` (everything seen and heard), `tests/` (`ci/` and `look/`).
- **The team's work**: `docs/` (`guides/` how to work, `design/` what the game is, `versions/` one page per version,
  `state/` notes a piece keeps, `sources.md` the bibliography), `kb/` (research), `tools/` (`dev/` to build, test and
  integrate; `content/` to make data, credits, art and the deck), `.github/` (CI, release, templates).
- **The event**: `spaceapps/` (the challenge, the rules, the team's notes, the local pitch, the global submission).
- Names: documents and folders in lowercase words joined by hyphens; code by its language's convention.
