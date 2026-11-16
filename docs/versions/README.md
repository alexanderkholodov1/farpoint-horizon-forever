# Versions

One page per version: what it was meant to be and what shipped. The version branch's history holds every
integrated step (`tools/dev/state.sh` lists them); the GitHub issues hold what is open.

| Version | What a player got | Where |
|---|---|---|
| [v0.1.0](v0.1.0.md) | The first playable sketch, and the base to build on | `main`, #1 |
| [v0.2.0](v0.2.0.md) | The whole mission, designed, launched, flown, landed; then v0.2.1 and v0.2.2 polished it | `main`, #61, #88, #89 |
| v0.2.3 | Phones drawn as on a laptop | branch `v0.2.3`, #92 (waits for review) |
| [v0.3.0](v0.3.0.md) | The story campaign: six NASA missions with the cuyes | branch `v0.3.0`, #93 |

## The lines open today (15 November 2026)

- A fix to the released game goes on `v0.2.3` (`git switch -c work/<issue>-<name> origin/v0.2.3`, and
  `tools/dev/pr-when-green.sh "<what>" body.md v0.2.3`); everything else on `v0.3.0`, the tools' default.
- `v0.2.3` is not in `v0.3.0` yet: when #92 is merged, `v0.3.0` merges `main`.
- The branch `v0.2.2` is merged and can be deleted by a team member.

Update this page when a version branch opens or is merged. The version the game shows on its menu is
`application/config/version` in `project.godot`: set it on the version branch when the branch opens.
