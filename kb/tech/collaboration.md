# Collaboration: two humans, many AI agents, one repo (as of 2026-11-14)

Items marked "(inference)" are recommendations or reasoning, not sourced facts.

## 1. One instruction file: AGENTS.md
- AGENTS.md is an open "README for agents" (plain Markdown, no required sections), stewarded by the Agentic AI Foundation under the Linux Foundation. Nested files in subfolders are supported; the nearest file wins; explicit chat instructions override files. Source: https://agents.md/ (fetched).
- Who reads it (verified on each vendor's docs):
  | Tool | Behaviour | Source |
  |---|---|---|
  | Codex | Walks from repo root to cwd; per directory checks `AGENTS.override.md`, then `AGENTS.md`; closer files override; combined cap `project_doc_max_bytes` = 32 KiB default (keep files short!) | https://learn.chatgpt.com/docs/agent-configuration/agents-md |
  | Cursor | Supports root and nested AGENTS.md; nested are combined, more specific wins. Rules in `.cursor/rules` must be `.mdc` (plain `.md` ignored) | https://cursor.com/docs/context/rules |
  | GitHub Copilot | Reads AGENTS.md anywhere in repo (nearest wins), or a single CLAUDE.md/GEMINI.md at root; also `.github/copilot-instructions.md` and `.github/instructions/*.instructions.md` | https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions |
  | Claude Code | Reads AGENTS.md ONLY if no CLAUDE.md exists in or above the working dir (needs v2.1.277+); if a CLAUDE.md exists it reads only that, so import: put `@AGENTS.md` in CLAUDE.md | https://code.claude.com/docs/en/memory |
  | Gemini CLI | Default file GEMINI.md; set `context.fileName` in settings.json to include `AGENTS.md`; supports `@file.md` imports. Doc page notes Gemini CLI was replaced by Antigravity CLI on 18 Jun 2026 | https://geminicli.com/docs/cli/gemini-md/ |
  | Antigravity | Official rules page lists AGENTS.md or GEMINI.md plus `.agents/rules/`; third-party guides say AGENTS.md support arrived in v1.20.3 (5 Mar 2026) and disagree on precedence (unverified) | https://antigravity.google/docs/rules.md (via search) |
- **Recommendation (inference):** keep ONE canonical `AGENTS.md` at the root (< ~150 lines, well under Codex's 32 KiB cap) and a `CLAUDE.md` containing only `@AGENTS.md` (plus any Claude-only notes). Add short nested `AGENTS.md` files per module (`/src/ui/AGENTS.md`, `/data/AGENTS.md`) stating that module's owner and rules. Do not duplicate content across Cursor/Copilot files; if you add `.cursor/rules` or `.github/copilot-instructions.md`, make them one-line pointers to AGENTS.md.
- Suggested AGENTS.md contents: project one-liner and chosen stack; exact commands (install, dev, test, build, lint); folder ownership table; "do not edit" paths; data-file schema rules; commit/PR conventions; definition of done; where the task queue lives.

## 2. Ownership split (inference unless noted)
- **Split by folder/module, not by feature across all layers.** Example for a web stack: Person A owns `/src/ui/**` and `/src/multiplayer/**`; Person B owns `/src/sim/**` (physics, scoring) and `/data/**`. Shared contract files (`/src/types/**`, `/data/schema/**`) change only via small dedicated PRs that both approve.
- **Define the interface first** (TypeScript types or JSON schema for spacecraft config, mission state, events, score report). With the contract fixed in hour 1, the sim and UI agents work independently against fixtures.
- **Game content as data, not code:** `/data/instruments.json`, `launchers.json`, `orbits.json`, `events.json`, `roles.json`, one file per entity type (or one file per entity if many). Content agents add entries; code agents never inline stats. Validate with a schema and a CI test. JSON is line-diff friendly (inference); keep it pretty-printed with stable key order and a trailing newline to avoid whole-file diffs.
- **Godot variant:** scenes (`.tscn`) are text but node/resource ids make merges noisy and Godot docs offer no merge guidance (https://docs.godotengine.org/en/stable/engine_details/file_formats/tscn.html ); give each scene exactly one owner and keep data in JSON/`.tres` per entity.
- Lockfiles and generated files (`package-lock.json`/`pnpm-lock.yaml`, build output) are collision magnets: one person adds dependencies, or dependency PRs merge first; never commit `dist/` or Godot `.godot/` (the latter per https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html ).

## 3. Branches and PRs: speed vs safety (inference)
- Fast mode: trunk-based. `main` always deployable; short-lived branches `<person>/<agent>-<topic>` (for example `a/codex-timeline`), each agent in its OWN git worktree or clone (never two agents in one working directory); PRs under ~300 lines; squash-merge; rebase on `main` before opening; merge at least hourly.
- Safety nets worth the 5 minutes: branch protection on `main` with 1 required approval and a CI check (build + data-schema validation + lint). Add "Require review from Code Owners" so a PR touching the other person's area needs their approval. GitHub merge queue is optional; it needs `merge_group` trigger in workflows and no wildcard branch patterns (https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue ; availability by plan not stated on that page).
- Late-hackathon freeze: from T-3 h only bug-fix PRs; tag a release candidate; deploy from a tagged commit.
- Hotfix escape hatch: either human may push directly after announcing in chat, only for the deploy config.

## 4. CODEOWNERS
Source: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners (fetched).
- File location: `.github/CODEOWNERS`, root, or `docs/`; must be on the PR base branch. Gitignore-style patterns; last matching pattern wins; owners need explicit write access; invalid lines are silently skipped. Auto-requests reviewers on PRs that touch owned paths (not on drafts). To enforce, enable "Require review from Code Owners" in branch protection or a ruleset. Also give `/.github/CODEOWNERS` an owner.
- Plan limits for private repos are not stated on that page (unverified); a public repo is simplest.
- Example (inference):
  ```
  *                    @humanA @humanB
  /src/ui/             @humanA
  /src/sim/            @humanB
  /data/               @humanB
  /src/types/          @humanA @humanB
  /.github/            @humanA @humanB
  ```
  Note: with only two people and each opening PRs, each PR needs the other's approval, which can bottleneck at night; consider requiring approvals only for shared paths, or let agents be reviewed by the other human's agent first (inference).

## 5. Shared task queue
- GitHub Issues are the single source of truth; a GitHub Project board (Todo / In progress / Review / Done) is optional. Labels: `area:ui`, `area:sim`, `area:data`, `area:multiplayer`, `agent-ok`, `blocked`. Every issue: goal, acceptance criteria, files likely touched, owner. Agents claim an issue by assigning it and opening a draft PR immediately that references it (`Closes #n`). The `gh` CLI is installed on this machine (`C:\Program Files\GitHub CLI\gh.exe`), so any agent can list/claim issues from the shell (inference; auth not checked).
- The GitHub MCP server failed to connect in this session (400, "Authorization header is badly formatted"), so do not assume agents have GitHub MCP; use `gh` (inference).
- Keep a `docs/STATUS.md` or pinned issue as a short "who is doing what now" log (inference); update on every PR.

## 6. Conventions that stop agents rewriting each other's work (inference)
1. "Touch only what the issue names." Agents must not reformat, rename, or reorganise files they do not own; no repo-wide formatting runs after hour 1 (configure formatter once, commit once).
2. Do not delete or rewrite another module's code; open an issue or a PR comment instead.
3. Shared contracts (types, schemas, data keys) are append-only during the hackathon: add fields, do not rename.
4. Pull/rebase before starting and before pushing; resolve conflicts by preserving both intents, never by `--force` on shared branches. Never `git push --force` to `main`.
5. Each agent runs the project's test/build command before opening a PR; PR description says what was verified.
6. Every agent session begins by reading AGENTS.md and the relevant issue; ends by updating the issue/PR with what changed and what is left.
7. Different vendors, same repo: do not let two vendors' agents edit the same file concurrently; assign by folder in the CODEOWNERS table above.
8. Secrets (API keys, Firebase config with admin rights, Cloudflare tokens) never committed; use env files in `.gitignore` and repo secrets for CI.
9. Dates and numbers in game data come from cited sources (see kb); mark placeholder values with a `"source": "TODO"` field so they are not mistaken for facts.
