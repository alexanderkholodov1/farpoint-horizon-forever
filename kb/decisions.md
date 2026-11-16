# Decisions

Newest last. A decision here overrides anything older in the repository. Open items are the team's to decide;
agents bring evidence, alternatives and a recommendation.

## Decided
| Date (UTC) | Decision | Who |
|---|---|---|
| 2026-11-14 | The team enters the 2026 NASA Space Apps Challenge with the challenge "Space Mission Design Game" | Team |
| 2026-11-14 | Two human members, each with their own AI agents across several accounts, working from this GitHub repository | Team |
| 2026-11-14 | Every material is in English: the game, the repository, the pitch deck, the submission (refined below: Spanish versions too, English by default) | Team |
| 2026-11-14 | Kerbal Space Program is the main inspiration: we take what is relevant and build our own product | Team |
| 2026-11-14 | The team defines the game idea; agents help with the brainstorm and are free to propose anything | Team |
| 2026-11-14 | Firebase (the lead's account) for online multiplayer and for hosting the playable link; the Firebase project is created once the brainstorm names the game | Team |
| 2026-11-14 | Everything is frozen by 07:00 on Sunday 2026-11-15; no fixed time slots before that. The website submission (closes Sunday 23:59 local) is done as well | Team |
| 2026-11-14 | 3D, with the complete mission as in Kerbal: build the craft in a builder, plan the orbit, reach orbit, travel to the target, land. Kerbal's fail-and-retry loop and its difficulty are not taken | Team |
| 2026-11-14 | Godot, optimized for the web from the start and deployed on Firebase, is the current direction; the lead confirms it for good once he sees the complete game running on the web (a web export with a JavaScript round trip is measured in `tech/platform-options.md` section 6) | Team |
| 2026-11-14 | Disclosure: every source of information, formula and data is cited, and a disclosure section names the AI agents used; no watermarks | Team |
| 2026-11-14 | The teammate's sketch (about 70% there) is the base; it needs a stronger plot and game design, well-made 3D models and a more unique UI | Team |
| 2026-11-14 | Several mission types | Team |
| 2026-11-14 | Audience: the general public; one complete, satisfying mission, simpler than Kerbal; the main takeaway is that there is no perfect design | Team |
| 2026-11-14 | Only a person merges, the lead or the teammate; agents prepare one pull request per functional version and never merge | Team |
| 2026-11-14 | Versions: v0.1.0 is the first playable sketch with the base; steps toward the next version are 0.1.1, 0.1.2, ... on the version branch; v0.2.0 is the second version with everything corrected; tags come from the release workflow | Team |
| 2026-11-14 | Repository layout: `spaceapps/challenge/` (challenge material), `spaceapps/team/` (team notes), `docs/design/`, `docs/agents/`, `kb/`, `tools/`; one rulebook `AGENTS.md`, imported by `CLAUDE.md` | Team |
| 2026-11-14 | Vision of v0.2.0 (`docs/design/vision.md`): fun and satisfaction first, humor, explosions possible on purpose, stations including a pilot and ground control, varied missions (Earth, Moon, Mars, Venus, one-way and returning, real and imagined), launches from the equator, random extra objectives and role bonuses, in-flight failures as mini-games, a leaderboard and gallery with no head-to-head competition | Team |
| 2026-11-14 | Blender may join the pipeline for 3D models when they are needed (the teammate researched how to connect it) | Team |
| 2026-11-14 | The repository is open source under the MIT license | Team |
| 2026-11-14 | The game is called **Farpoint HORIZON** (written exactly so); the repository is `alexanderkholodov1/farpoint-horizon`; the Firebase project is `farpoint-horizon` (its service key stays outside git, in the ignored `private/` folder) | Lead |
| 2026-11-14 | Nobody owns a part: both team members work side by side, each piece claimed through its issue | Lead |
| 2026-11-14 | The first three missions: volcano watch (Earth orbit), the Moon's south pole (landing), the Grand Tour (never returns); more to come | Lead |
| 2026-11-14 | Everything from outside is cited (numbers, formulas, facts, data, assets), presentable to the judges, through one bibliography `docs/sources.md` | Lead |
| 2026-11-14 | Languages: English is the default everywhere (the repository, the game, the global platform); the platform's description and the deliverables also exist in Spanish, as the local venue requires; the live pitch in Sangolquí is in Spanish; the game offers Spanish as an option | Lead |
| 2026-11-14 | No AI-generated images: models come from our scripts, textures and imagery from cited sources (NASA first), so no watermark is needed | Lead |
| 2026-11-14 | Parallel work: each piece on its own branch with no version number; a lead agent integrates it into the version branch without asking, once CI is green, as the next numbered step (`tools/dev/integrate.sh`); pull requests into any branch other than `main` are allowed; `main` takes only the version pull request, which a person merges | Lead |
| 2026-11-14 | Four stations, to match up to four players; with fewer players, bots take the free stations, working with you as people would | Lead |
| 2026-11-14 | An online room with a code (Firebase), plus a mode on one shared screen | Lead |
| 2026-11-14 | First one complete mission playable on the web with two people; the lead approves it and corrects it before the game widens | Lead |
| 2026-11-14 | NASA data inside the game: the photos each mission returns, shown at the end; positions from JPL Horizons and constants from the NSSDC fact sheets; NASA imagery used only as decoration needs a good argument first | Lead |
| 2026-11-14 | The look: the identity and the UI are futuristic space, of the present (not a 1960s-70s control center); the graphics (craft, rockets, places) are as real as a documentary and resemble real spacecraft; characters may be stylized 3D; no Telltale-like style. The two or three characteristic colors belong to the game's brand marks (logo and what identifies the game), not to every graphic | Lead |
| 2026-11-15 | Repository layout: the game (`scripts/`, `data/`, `assets/`...), the team's work (`docs/`, `kb/`, `tools/`) and the event (`spaceapps/`), each area with a README; the map is `docs/README.md` | Team |
| 2026-11-16 | The hackathon repository (`alexanderkholodov1/farpoint-horizon`, v0.3.0) is frozen exactly as submitted: no commit, branch, issue, comment or deploy by anyone, nor to its Firebase project `farpoint-horizon` | Alexander |
| 2026-11-16 | The game continues in this repository, `farpoint-horizon-forever` (project name Farpoint HORIZON Forever until the final one), started from a byte-identical copy of v0.3.0 without its history; the two histories are never joined | Alexander |
| 2026-11-16 | The long-term path: polish the web game up to v1.0.0; after that, a far larger game for Steam and other platforms as its own product; a mobile game is an idea to study | Alexander |
| 2026-11-16 | Until the final name, the web build lives in the Firebase project `aklabs-dev`, hosting site `farpoint-horizon-forever`, with that project's Realtime Database for the online room | Alexander |
| 2026-11-16 | Alexander and Sebastian share the game 50/50; the terms (ownership, name, license of new work, income) go in a written agreement between the two | Alexander (to agree with Sebastian) |

## Open
| # | Question | Why it matters | Status |
|---|---|---|---|
| D2 | The plot and the rest of the visual direction (the identity's colors and type, the UI) | The name, the vision and the look's base are settled; these complete the design round | Design round in progress |
| D4 | Which four stations, and what each one does at each step | The stations' number and the bots are decided; the split is proposed in `docs/versions/v0.2.0.md` | To confirm with the team |
