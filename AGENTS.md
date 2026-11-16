# Agent guide: Farpoint HORIZON

The one rulebook for every agent in this repository, whoever runs it (Claude Code, Codex, Cursor, Gemini or any
other), on any machine, for either team member. `CLAUDE.md` only imports this file. It holds criteria that do not
change from one day to the next; it never holds the state of the work (what is in progress, which version is next,
who holds what). That state lives in GitHub and git, and you read it there each time (see "Start of every session").

## The project
**Farpoint HORIZON** (always written this way) is a 3D space-mission game in Godot 4.7, played in the browser, by team
**SK-Horizons** (Quito, Ecuador; always with the hyphen and the final s). Alone or with up to three friends, players
build a craft, plan its route, launch it, fly it, land it or keep it talking to Earth, and enjoy what they achieved;
a story campaign with a crew of Andean guinea pigs (the *cuyes*) lives six real NASA missions. The project is called
**Farpoint HORIZON Forever** until the team picks its final name.

It was born in 39 hours at the NASA Space Apps Challenge 2026. That submission is frozen, exactly as judged, at
https://github.com/alexanderkholodov1/farpoint-horizon and in its Firebase project `farpoint-horizon`: **nobody
changes either, ever** (no commit, branch, issue, comment, setting or deploy). This repository starts from a
byte-identical copy of it (tag `v0.3.0`).

The road: polish the web game, released on Firebase, up to `v1.0.0`. Other platforms (Steam, itch.io, mobile) come
only after that and are not part of the work here.

## Who decides
- **The two team members decide**: the idea, the design, scope, what goes in a release, accounts, anything public.
  Agents bring evidence, alternatives and a recommendation, and are free to propose anything.
- **Only a person merges into `main`.** Agents merge reviewed pieces into `next` (below).
- Talk with your person in their language. The repository is in English; the game is in English with Spanish as an
  option.

## Start of every session
Before you build anything:
1. Read this file. Then read the current state, never a copy of it:
   `gh issue list --milestone "<the open milestone>"`, `gh pr list --base next`, the open milestone's description
   (`gh api repos/{owner}/{repo}/milestones`), and the latest comments of the issues and pull requests near your
   work. Other agents announce what they are doing there before they push.
2. Choose with judgment:
   - First, a pull request labeled `needs-review` that you did not build: a waiting review blocks someone else.
   - Then an issue of the open milestone that nobody holds (no open pull request says `Closes #N`), whose
     dependencies are done. Taking work whose input is not ready ("play the release" before the release is complete)
     wastes the work twice.
   - Issues without a milestone are the backlog: take one only when your person asks.
3. Tell your person what you will take, why, what you understood it asks, what you will deliver and how you will
   verify it. If the issue is not enough to start, improve it or ask; do not guess.

## How work flows
- **One release is prepared at a time**, on the branch `next`. Its GitHub milestone is named `vX.Y.Z → next`: built
  on release `vX.Y.Z`, not yet numbered. When it is released, the milestone is renamed `vX.Y.Z → vA.B.C` and closed.
- **A piece of work is an issue** (written with the issue form). Big work is a parent issue with sub-issues and an
  `area:` label; that is how two efforts with the same kind of name stay apart.
- **Claim it by opening a draft pull request** into `next` as soon as you start, from a branch named
  `from-<release it starts from>/<short-name>` (`from-v0.3.0/rocket-builder`: work on top of v0.3.0, for the release
  in preparation; the short name says what it is, and the issue is linked by `Closes #12` in the body), with your plan
  as a checklist, and who you are (tool, model, machine, for which person). The assignee field cannot tell
  agents of one account apart; the draft pull request can. A check warns if another open pull request already closes
  the same issue: the older one keeps it.
- **Push your progress as you go.** Each push is a checkpoint: if your session ends, the next agent continues from your
  branch, not from zero. Keep the checklist true.
- **A claim only goes stale when someone needs it.** If you need an issue that someone holds, look at its last push
  and comments against what the team did since; if it is unclear, ask your person, who knows whether their session is
  alive or can ask the other team member. Never take over a claim on a guess, and never release one by a timer.
- **Stay current by merging** `origin/next` into your branch; never rebase or force-push a pushed branch.
- **When it is done** (see "Done"), mark the pull request ready for review; it gets the `needs-review` label.
- **The review** is done by someone who did not build it, ideally another vendor's model, by playing it (see "Review").
  When it passes, the reviewer sets the approval on the exact commit and merges into `next` with a merge commit (the
  piece's history stays). A new commit after the approval needs a new approval.
- **The release**: when the milestone has no open issue (each one closed as done, or closed as not planned or moved to
  the next milestone, always with the reason written in it), someone opens the pull request `next → main` titled
  `vA.B.C: <what a player gets>`. The team decides the number from what the release contains: a patch (`0.3.1`) when
  it is the same game made better, however many fixes and improvements that is; a minor (`0.4.0`) when the game is in
  a clearly different state; `1.0.0` when the team calls the web game impeccable. A person merges it; the release
  workflow tags it, builds it, publishes it to Firebase and renames the milestone; then `main` is merged into `next`
  and the next milestone `vA.B.C → next` opens.

## Done
"It runs and the tests pass" is never done. Before you mark a piece ready:
- **Play it as a player would**, in the web build (`tools/dev/export-web.sh`, then open it), at each speed of time, in
  both languages, at desktop and phone size, both appearances. Play it wrong too: idle, fast clicks, wrong choices,
  Esc at every step. Look at every screenshot and write down what a player sees.
- **Ask the questions of your area**: where can this fail, and under what use? Many players at once, a room mixing a
  phone and a computer, a phone 5 to 10 years old, a slow connection, a lost connection, an empty or very long name,
  the free limits of Firebase. Measure what you can; label a guess as a guess.
- **Fix what you see**, inside the files your piece owns, at its cause. Never stack a workaround on top of something
  broken (a retry around a crash, a delay around a race, a special case around a wrong value): find why and fix that.
  What is outside your piece becomes an issue.
- **Write your change note** in `changes/<short-name>.md` (see `changes/README.md`).
- Say in the pull request what you played and checked, with screenshots.

## Review
- Check out the branch, build it (`tools/dev/export-web.sh`), and play it in a real browser on your machine, against
  the issue's "Done when" and against "Done" above. A script passing is evidence about what that script checks, no
  more: read what a check really asserts before trusting it.
- Each finding goes in the pull request with its evidence: what you did, what you expected, what you saw, a screenshot
  or a recording, the device size. Reproduce a finding before anyone fixes it.
- Fix it yourself when it is mechanical, unambiguous and inside the piece's files (a cut text, a wrong key, an
  overflow), then re-check. Send it back to the author when it is about design or logic: they hold the context to fix
  it at its cause. If the same findings come back round after round, tell your person.
- What only people can judge (whether the music is good, whether it is fun) goes to the team in the pull request.
- To approve, set the status on the commit you reviewed, then merge:
  `gh api repos/{owner}/{repo}/statuses/<sha> -f state=success -f context=review -f description="<who reviewed>"`
  then `gh pr merge <n> --merge`.

## What the game must be (applies to every piece)
- **Fun and satisfaction first.** The player should feel the pride of watching their own craft lift off, deploy,
  arrive and land. Missing something is never a failure screen; achieving more is rewarded. Kerbal Space Program
  inspires the builder, route and orbit planning, the whole journey, freedom to invent, humor and the spectacle of
  launch and landing; not its difficulty or its fail-and-retry loop.
- **Clear and friendly.** A player never gets lost and never wonders what to do next. No wall of text: say the
  essential in a few words and put the rest behind a hover, a click or a "more". Every concept a player meets is
  explained in simple words inside the game. Works with a mouse, keys and touch.
- **Real behavior, never a drawing of it.** Launch, orbits, transfers and landings follow real physics with real
  constants and ephemerides; paths come from the physics, never from a hand-drawn curve. Speeds, periods, burn
  lengths, trip times and distances are the real ones or follow from real physics. Where we simplify, the code says
  what and why.
- **Real time, said on screen.** Simulations run in real time by default; faster time is a visible control and the
  screen always says how fast time runs, with a clock of the true mission time. Time never compresses silently and
  the player never waits for nothing: it runs by itself to the next moment that needs the player and slows for it.
  With an engine on, at most ×100; near the ground, real time only.
- **True scale, made readable.** Sizes and distances keep their true proportions; what is too small to see gets a
  marker of constant screen size and a label, never a larger drawing. What the player must act on is in view.
- **Mechanics before content.** A new mission waits until every mechanic it uses is right and real.
- **Nothing that looks AI-made.** `docs/design/criteria.md` holds the team's design criteria for models, UI, motion,
  sound and copy.

## Sources and rights
- **Everything from outside is cited.** Every number, formula, fact, dataset, image, model or sound that comes from
  outside carries its source where it is used (a data field, a code comment) and is listed once in `docs/sources.md`
  with a short unique ID (`S-gibs-viirs`); entries are added at the end of their section, never renumbered. Our own
  simplifications say so and cite what they simplify. The credits are generated from that list.
- **No NASA logos, insignia, flags or mission identifiers**, and nothing implying NASA endorses us
  (https://www.nasa.gov/nasa-brand-center/brand-guidelines); crediting NASA data in text is expected.
- **No AI-generated images**; models come from our scripts, textures and imagery from cited sources. AI use is
  disclosed in the README. No image, voice or likeness of anyone under 18.
- Every outside asset (code, fonts, images, sounds, models, data) is listed with its source and license.

## Working beside other agents
- Each piece owns the files its issue lists. If you must change a file another open pull request is changing, say so
  in both and agree who goes first. A change to something everyone uses (data formats, the mission model,
  `GameState`, `project.godot`, this file) is its own small issue, agreed by both team members and merged first.
- No shared lists: a piece adds its own files and never edits a list every piece edits. Its Spanish texts go in its
  own `i18n/<piece>.csv` (`keys,es`); a new screen is only `scripts/screens/<id>.gd`; a new check is only
  `tests/ci/<name>.gd` with a `## check: <pattern>` line; change notes are one file per piece. The game and the tools
  find them by folder.
- Never rewrite, reformat or revert someone else's work, and never push to someone else's branch: comment, or propose
  a pull request into their branch.

## Leading and briefing
When you split work for other agents, the brief is the work: an incomplete brief produces work fit only to be thrown
away. Each brief, usually an issue, gives the agent:
- who it is in this piece and why the piece exists (what the player gets, what comes after it and expects from it);
- exactly what to read, by path, and what it does not need to read;
- the files it owns and the ones it must not touch;
- the exact deliverable and its shape;
- "Done when" as observable checks, including what to play and on which devices, and how to verify each;
- the criteria to apply (this file) and where to ask (the issue's comments, its person).
Parallel workers get files that do not overlap. Match the model to the task: strong models for design and judgment,
cheaper ones for mechanical work. Verify every result yourself before it is merged.

## Engineering
- Godot 4.7.2, renderer GL Compatibility (browsers and integrated GPUs); the web build is the single-threaded export
  (`export_presets.cfg`, preset "Web"). `tools/dev/godot.sh` finds the Godot binary (or set `GODOT`).
- `tools/dev/check.sh` runs the automatic checks (`docs/guides/testing.md` says what they prove and what they do not);
  CI runs them on every pull request into `next`. `tools/dev/export-web.sh` builds the web game into `build/web/` with
  its version from git. `tools/dev/shots.sh` plays the scripted walkthrough with a window and saves screenshots.
- The version is never written by hand: it comes from the git tag at build time (`v0.3.1` for a release,
  `v0.3.1-7-g1a2b3c4` for any other build: 7 commits after v0.3.1).
- Data apart from code: missions, parts, launchers, orbits, events and texts live in `data/` and the catalogs, so
  content and balance change without touching logic.
- One UI standard: every screen builds its interface only from `scripts/ui/kit.gd` (type scale, spacing, colours,
  components); a piece the kit lacks is added to the kit, for everyone.
- Commit the `.import` and `.uid` files Godot creates beside the files you add (they carry random IDs).
- GDScript is Godot 4 syntax; the project's pitfalls are in `docs/guides/architecture.md`.
- The web build lives on Firebase project `aklabs-dev`, hosting site `farpoint-horizon-forever`; the online room uses
  that project's Realtime Database with the rules in `database.rules.json`. Firebase's free plan has daily and monthly
  limits; anything that loads the game or uses the room counts against them, so review on your machine, not on the
  hosted site.
- Commits and pull requests in English, small and working, with no version numbers and no AI co-author lines.

## Layout
The map is `docs/README.md`. The game: `project.godot`, `scenes/`, `scripts/` (one folder per area), `data/`, `i18n/`,
`assets/`, `tests/` (`ci/` automatic checks, `look/` screenshot harnesses). The team's work: `docs/` (`guides/` how
to work on it, `design/` what the game is, `areas/` what each part of the game does and what was checked about it,
`sources.md`), `kb/` (research; `kb/challenge/` is the challenge the game was born from), `tools/` (`dev/` to build
and check, `content/` to make data, credits and art), `changes/` (change notes of the release in preparation),
`.github/`. Names: lowercase words joined by hyphens; code by its language's convention.
