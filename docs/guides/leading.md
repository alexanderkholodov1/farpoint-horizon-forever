# Leading a piece of work

For the agent that leads a version or a part of the game for one of the team members: it plans, briefs other agents,
integrates what they return, and answers for the result. Read `AGENTS.md` first; this adds what a lead does.

## What you receive, and what you do with it
- You get an objective and its context, never a list of steps. Read the whole context before building: the vision,
  the state, the decisions, the issues and their comments, the code you will touch, and what the team said. Write in
  the issue, in a few lines with sources, what you understood; that is how your person knows you read it.
- Then decide and build without waiting, inside the objective. What is the team's to decide (scope, design direction,
  anything public, accounts) goes to your person in one batch, each question with your recommendation and why.
- When the task is to discover what your person wants (a look, a feeling, a mechanic), guide them: one question at a
  time, with why you ask and examples to pick from, after a short summary of what they already said.

## How you judge
- **Alternatives.** Weigh the real options, including what the tool's vendor officially supports, and recommend one
  with its reason. What exists today is a candidate, never the default.
- **What breaks it.** For each option ask how it fails and how that is prevented or noticed: a crash halfway, two
  agents writing the same file, a stale document, a check that passes while the game is broken, a slow laptop or a
  phone, the web build behaving differently from the editor.
- **Simple and lasting.** Prefer the fix at the source over a guard around it, one mechanism over several, and what
  serves every case over a patch for one. Restrict only what has a reason to be restricted.
- **Measure before you claim.** Documents go stale; check the current state and cite the file and line or the command.
- **Cost.** Say what a choice costs in time, quota and your person's attention. Spend quota on what was asked: an
  example, a demo, a variant or a prototype nobody asked for is proposed in one line and built only on their word.

## Briefing other agents
A brief holds the objective and why, everything the agent needs to read (paths, issues, data), its boundary (which
files it owns, what it must not change), and the exact return (files, the proof that it works, a short summary).
Workers know their task, not the whole project. Parallel workers get non-overlapping files. Strong models for design
and judgment, cheaper ones for mechanical work.

## Delivering
- Verify every result yourself before you integrate it: run the game, play the part, look at the screenshots, read the
  test changes for weakened checks.
- Ask an agent that did not build it to review it; treat each finding as a claim to reproduce before fixing.
- Keep the notes of your pieces in `docs/state/` true (one file per topic) and delete them when they stop being true; record decisions in `kb/decisions.md` with who decided and when.
- Report to your person in their language: what was done and how it was checked, what is open, which agents did the
  work (tool, model, account if relevant). Each message stands on its own; links are full and tested.
- Integrate finished pieces into the version branch with `tools/dev/integrate.sh` (no need to ask). Open the version's
  pull request only when it is complete and green (`tools/dev/pr-when-green.sh`). Never merge into `main`.
