# Prior art for a space-mission design game

Researched 2026-11-14. Every fact has a source URL. **(inference)** = our deduction. "Not found" = searched without result. Companion file: spaceapps/rules/event-and-judging.md (judging criteria: Impact, Creativity, Validity, Relevance, Presentation).

## A. Resources listed in the challenge

### A1. NASA Webb "Build It Yourself" telescope game
Pages: https://science.nasa.gov/mission/webb/game-build-it-yourself/ ; full transcript PDF https://science.nasa.gov/wp-content/uploads/2024/03/gametext.pdf ; result texts https://science.nasa.gov/wp-content/uploads/2024/03/level1-science.pdf (also level2-science.pdf, level3-science.pdf). Credits in transcript: author Maggie Masetti, programmer Mike Wojnarowski, artist Susan Lin. Note: game has no built-in accessibility; a full transcript is offered instead (game page).

Step by step (from the transcript PDF):
1. Start screen, then level select: Level 1, 2, 3 plus a "Need a hint" button. The menu shows black silhouettes of unidentified real spacecraft; each completed run "unlocks" (fills in) one silhouette as a collectible. Hints give a clue per silhouette (e.g. "try something that requires a scintillator", "large segmented mirror but much higher energy than optical").
2. **Science goal** (Level 1, pick 1 of 5): Black Holes, Star Formation, Early Universe, Galaxies, Exoplanets. Hovering an icon shows explanatory text; select with click; changeable until launch (back/next buttons).
3. **Wavelength** (options depend on the science goal; e.g. Black Holes offers X-ray, Gamma ray, Optical; other topics offer their own subsets, including IR/UV/microwave). Each option has text explaining why that wavelength suits that science.
4. **Instrument** (depends on wavelength): cameras, spectrometers, radiometer, counters (proportional counter), scintillator, etc. Text says e.g. a counter needs no optics.
5. **Optics** (depends on instrument and wavelength; size Sm/Med/Large): segmented mirror (Large, IR/optical/UV, "bigger mirror = heavier and more expensive to launch"), single primary mirror (Sm/Med/Large; optical/IR/microwave/UV), grazing-incidence/segmented mirrors for X-ray imaging, "no optics" for gamma ray and some X-ray detectors ("we don't yet have the technology to focus gamma rays").
6. Launch button: rocket animation (bigger rocket at higher levels), then the **result screen**: a drawing of a real satellite similar to the one built, real data resembling what the instrument would collect (e.g. a Rossi X-ray Timing Explorer light curve of black hole GRS 1915+105 for Black Holes + X-ray + proportional counter), and text describing the science result. There is a pre-written result for every permutation ("text for every possible permutation").
- Levels: L1 = 1 science goal, 1 wavelength, 1 instrument, optics. L2 = up to 2 science goals and up to 2 wavelengths, each wavelength must get at least one instrument, optics per instrument; may return more than one result (arrow to page through). L3 = 4 science goals, 3 wavelengths (one per goal), 3 instruments, adds a Webb-like segmented mirror option; biggest rocket. The game page recommends starting at Level 1.
- Constraints/incompatibilities: options are grayed out when "not scientifically or technologically viable"; the number of choices is capped per level; "if you try to combine too many uncomplimentary things, your satellite might end up a mess" (game page). Mechanism is a decision tree with pre-authored outcomes, not a numeric simulation (inference from the transcript structure).
- Real-mission comparison: the result shows a comparable real mission; the game covers missions "from the 1980s to today" (game page).
- Not present (inference): no budget, mass, power, data-rate, orbit, or launch-vehicle choice as player variables beyond text notes about mass and launch cost. This is the gap our game fills.

### A2. NASA Mission Viz
Repository and tutorials: https://nasa.github.io/mission-viz ; software catalog https://software.nasa.gov/software/MFS-34033-1 . Web-based space mission visualization (X3D/X3DOM, JavaScript, WebGL). Workflow: design trajectory in GMAT, export, convert to JSON, display in a web page (tutorial series by Daniel A. O'Neil, https://nasa.github.io/mission-viz/X3Dom/WebMissionVisualizationTutorialSeries.html). Shows a 3D scene with bodies, spacecraft and trajectories, with time animation. Weakness (inference): it is a visualizer of precomputed GMAT output, not a design/trade tool. The challenge-page link for "Mission Viz" points at the Goddard Mission Design Lab page instead (see event-and-judging.md section 6); a Goddard link to Mission Viz was not verified.
Reusable idea: trajectory export from GMAT to JSON for pre-baked orbit/transfer visuals.

### A3. NASA Mission Design Lab (MDL) and Concept Maturity Levels
Challenge-provided descriptions (spaceapps/challenge/resources.txt): MDL study types Office Hours, Concept Development, Trade Studies, Point Design; CML 1-4 from idea to point design. Official page: https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/mission-design-lab/ . (inference) The four MDL study depths and CMLs map naturally to game difficulty levels or campaign stages (idea, feasibility, trade study, point design).

### A4. CSA digital games
Page: https://www.asc-csa.gc.ca/eng/youth-educators/digital-games-and-activities.asp . Per search results: **Mission: Astronaut** (grades 3-6, dozens of short activities across eight missions: astronaut training, living in space, robotics, the Moon; includes a Lunar Rover easy coding minigame) and **Tomatosphere Adventure** (Minecraft Education game about growing tomatoes on Mars). Sources: https://www.asc-csa.gc.ca/eng/youth-educators/activities/game-mission-astronaut.asp , https://asc-csa.gc.ca/eng/youth-educators/activities/tomatosphere-adventure-minecraft-education-game-featuring-extraterrestrial-agriculture.asp . Pattern: many short, themed minigames with teacher resources; they teach one topic each, not a whole mission (inference). Whether a full system-design game exists in the CSA collection: not found.

### A5. 2023 Space Apps "Visualize a Space Mission Using Virtual Reality"
Challenge page: https://www.spaceappschallenge.org/2023/challenges/visualize-a-space-mission-using-virtual-reality/ (summary in spaceapps/challenge/resources.txt: VR app showing mission concept, orbital trajectories, mission timeline, 3D visualization). Projects found (not verified as winners):
- Team Robust: VR experience following Hubble Servicing Mission 1; page labelled "Global Nominee" (also shows "Global Finalist Honorable Mention" text, so status ambiguous). https://www.spaceappschallenge.org/2023/find-a-team/team-robust/
- PocketSpaceShip (team ThunderBees, Guanajuato local event): https://github.com/FuanitoMH/PocketSpaceShip
- Tycho Station: https://github.com/dilansolart/tychoStation_AppsChallenge2023
Global winner for this challenge: not found (official winners page https://www.spaceappschallenge.org/2023/awards/global-winners/ is JS-rendered; search did not show a VR winner; 2023 Global Winners were announced Jan 23, 2024 from 5,556 submissions per https://science.nasa.gov/directorates/smd/2023-nasa-international-space-apps-challenge-announces-10-global-winners). Lesson (inference): VR submissions are visual-heavy and need hardware judges may not have; our challenge is judged from a link and a demo, so a browser-playable build is safer.

## B. Other games and tools

### B1. Kerbal Space Program 1 (KSP)
- Modes: Science mode (no economy), Career mode adds Funds, Reputation, Contracts; contracts reward science/funds/reputation, missed deadlines penalize; reputation gates contract quality (https://wiki.kerbalspaceprogram.com/wiki/Career , https://wiki.kerbalspaceprogram.com/wiki/Science_mode ). Science mode was designed to ease new players in and not overwhelm them (https://wiki.kerbalspaceprogram.com/wiki/0.24 ; First Contract update July 2014, https://www.pcgamer.com/kerbal-space-program-devs-hope-to-add-budgets-reputation-in-2014 ).
- Engaging: build, fail, iterate loop with real physics; funds/contracts turn it into mission goals.
- Weaknesses: steep learning curve; player complaints that contracts are repetitive/cannot be customized and funds only from contracts (anecdotal, https://forum.kerbalspaceprogram.com/topic/167147-ocd-alert-i-want-to-get-around-the-contracts-system (blocks automated checks; open in a browser) ). Focuses on flight/orbital mechanics, not instrument/data/comms trade-offs (inference).
- Education: KerbalEdu (simplified interface, pre-made lessons, launched 2014 by TeacherGaming/Squad; https://www.engadget.com/2014/01/24/kerbal-space-program-plots-course-for-the-classroom/ ). Controlled learning-outcome studies: not found; a physics-course abstract describes using KSP for orbital dynamics without measured outcomes (https://archive.aps.org/aaptsm/2025/a02/1 (404 on 2026-11-16) ).

### B2. Kerbal Space Program 2
Early Access launched Feb 2023 with bugs, performance problems and missing features; developer Intercept Games reportedly closed mid-2024 (Take-Two did not confirm; Bloomberg-reported) and no content updates since Dec 2023 per Windows Central (https://www.windowscentral.com/gaming/kerbal-space-program-2-hasnt-had-an-ounce-of-content-for-over-a-year ; https://www.pcgamer.com/games/sim/kerbal-space-program-2-developer-intercept-games-may-be-closing-as-part-of-take-twos-big-layoff-plan ). Lesson (inference): ambition outran delivery; a small complete vertical slice beats a broad unfinished sandbox, which matters for a one-day hackathon.

### B3. JPL Team X / concurrent engineering (inspiration for team roles)
Typical Team X study: about 15 subsystem "chairs" (up to 20; as few as 8 for small studies), 1-2 point designs over three sessions, seated like an operations center for fast communication; a Risk Chair was added in 2001 because risks were raised late; Team X began 1995 (https://www.iceaaonline.com/wp-content/uploads/2017/09/RSK06-Hihn.pdf ). Pre-session: set roles, develop requirements with a subset, then the combined session (https://tfaws.nasa.gov/TFAWS02/Data/Interdisciplinary/Miyake.pdf ). Subsystems named: ACS, power, propulsion, thermal, structure, communications, etc. A single authoritative role list: not found.
Design use (inference): four-player roles such as Mission/Systems lead (requirements, budget), Spacecraft engineer (power, mass, structure), Payload/Science lead (instruments, data volume), Comms/Operations lead (data link, orbit, ground). Add a "risk reviewer" flavor event to avoid late surprises.

### B4. ESA games
- ESA "The Space Game" (2010): design interplanetary trajectory to Jupiter minimizing time and propellant (https://www.esa.int/Education/Compete_and_find_your_way_to_Jupiter ). Technical, narrow.
- JUICE scenario in Juno: New Origins (Jundroo, with ESA): sandbox with real JUICE craft, plan burns and gravity assists to Ganymede/Callisto/Europa; author reports learning gravity turns and difficulty of space travel; formal educational goals not stated (https://nextgov.com/emerging-tech/2023/04/esa-lets-people-plan-and-execute-juice-spacecraft-missions-new-video-game/385341 ).
- ESAKids app (ages 3-10, assembling/coloring activities) and Moon Camp Challenge (classroom design project with 3D modelling tools) (https://apps.apple.com/us/app/-/id1527436992 ; https://esa.int/ESA_Multimedia/Images/2018/10/Moon_camp_key_visual ). No ESA game found that covers whole-mission design (searched).

### B5. NASA Eyes on the Solar System
Web app with 3D renderings of about 126 NASA spacecraft (2022 count) and trajectory view with "Draw Mission"; shows predicted and reconstructed data, not live telemetry; supports embedding with custom options (https://www.nasa.gov/solar-system/explore-the-solar-system-with-nasas-new-and-improved-3d-eyes ; https://science.nasa.gov/blogs/eyes/2026/04/30/trajectory-view-feature-goes-live/ ). Use (inference): link out to or embed Eyes for real-mission context rather than building a 3D engine.

### B6. NASA/JPL "Marsbound! Mission to the Red Planet" (card/board simulation)
Grades 3-5, 3 sessions of 45 min; teams design a Mars mission with Equipment Cards and a Design Mat under budget, mass and power constraints, aiming at significant science return; includes a Spacecraft Design Log, an engineering design cycle worksheet, and pre/post ideas worksheets; a digital edition exists (https://www.jpl.nasa.gov/edu/pdfs/marsbound-fullguide.pdf ; https://jpl.nasa.gov/edu/teach/activity/marsbound ). Strengths: three constraints plus a science-return goal, team collaboration, explicit iterate-and-compare step. Weakness (inference): static card values, no simulated outcome or failure events.

### B7. Leaving Earth (board game)
Players complete missions scored by complexity; each maneuver has a difficulty approximating delta-v, required thrust = mass x difficulty, spent rockets are discarded; cost vs. duration trade-offs (ion thrusters). The author notes real mission planning becomes a constraint-satisfaction problem with non-obvious solutions and built a Z3 solver (https://bosth.github.io/pages/leaving-earth/ via http://www.jaxartes.net/pages/leaving-earth/ ; rules https://tekeli.li/leaving-earth/Leaving%20Earth%20-%20rules%20v4n.pdf ). Engaging: simple formula, deep choices, "no single perfect solution", which matches the challenge text. Weakness (inference): hard to learn for newcomers.

### B8. Past Space Apps game-oriented challenge: "Space Quest: The Game" (2021)
Example project "Decks to Orbit" (team The Martians): digital card game in Python/Pygame; pick a mission (Lunar/Martian) with stages, a mass allowance and fuel limit; build a deck of spacecraft part cards up to the mass allowance; draw 5-6 cards per stage, cards cost fuel; win by completing all stages; leaderboards; card effects based on real components (ring laser gyroscope, star tracker) from NASA references. It was a demo with incomplete game logic (https://2021.spaceappschallenge.org/challenges/statements/space-quest-the-game/teams/the-martians-8 ; repo https://github.com/hsfalsharif/Space-Card-Game ). Lesson (inference): a clean core loop beats breadth; unfinished logic is visible to judges. Past global winners among game challenges: not found.

### B9. Other
- ESA Clean Space board game (hidden environmental cost of missions): https://esa.int/spaceinimages/Images/2016/04/Clean_Space_board_game . Detail not read.
- GMAT (challenge resource): high-fidelity trajectory/orbit tool, open source (https://software.nasa.gov/software/GSC-19468-1). Too heavy to embed; use for pre-computed orbit/delta-v tables (inference).

## C. Design patterns to take / pitfalls to avoid

Take:
1. **Unlock-based progressive levels** with 1, 2, 4 goals (Webb game levels; Team X/MDL study depths as stages). Start easy, add constraints per level. Matches challenge "different difficulty levels".
2. **Grey out incompatible options with an explanation** instead of silently blocking (Webb game: unviable choices grayed, text says why). Use the same for launcher vs. mass/orbit (challenge text asks for this check).
3. **Show a real comparable mission after the result** with real data/imagery (Webb game result screen). This is a direct way to satisfy Relevance (NASA data core) and gives the pitch a memorable moment.
4. **Collectible/mystery silhouettes and hints** to encourage replays (Webb game unlockable missions, hint button).
5. **Few, legible resources** shown live: budget, mass, power, data, comms, time (Marsbound's budget/mass/power; Leaving Earth's mass x difficulty = thrust simple formula). Use simple transparent formulas so each failure is explainable.
6. **Science return as the goal, constraints as the limit** (Marsbound). Score on science value per resource, not only success/failure.
7. **No single perfect solution**: several viable designs with different trade-offs (Leaving Earth, challenge text). Show alternative designs side by side in the final report.
8. **Roles for four players modeled on Team X chairs** plus a risk reviewer (Team X). Make roles hold different information, forcing negotiation.
9. **Easy on-ramp mode** that removes the economy (KSP Science mode vs Career) and a sandbox; optional contracts/scenarios for goals.
10. **Post-mission explanation** of why it succeeded or failed, tied to the cause (challenge text; Webb result texts explaining the science). Add a design log to iterate (Marsbound Spacecraft Design Log).
11. **Link out for 3D context** instead of building an engine (Eyes on the Solar System, Mission Viz).
12. **Browser-playable, link-only access** so judges need no install (2023 VR projects' hardware dependence; Submission Guide needs a public link with no login).

Avoid:
1. **Pre-authored outcome table only** (Webb game): no real numeric trade-offs, so it cannot show how decisions interact; do the numbers.
2. **Overscoping** (KSP2; Decks to Orbit demo with unfinished logic): ship one complete mission loop, then add scenarios.
3. **Steep learning curve / no tutorial** (KSP; Leaving Earth complexity): include short explanations and a guided first mission, since tag is Beginner/Youth.
4. **Repetitive contracts/goal generator** (KSP contract complaints): vary mission objectives and events.
5. **Static card values with no simulated failure** (Marsbound, inference): include a simulation step with failure causes and random events.
6. **No accessibility** (Webb game provides only a transcript): provide keyboard use, readable text, colorblind-safe indicators.
7. **Using NASA logos or presenting AI-generated visuals without disclosure** (event-and-judging.md section 5).
8. **Claiming realism you do not have**: label simplified models and cite sources for parameters (Validity criterion).
