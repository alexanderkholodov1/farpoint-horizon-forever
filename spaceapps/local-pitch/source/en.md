title: Farpoint HORIZON · pitch deck
footer: Farpoint HORIZON · SK-Horizons · NASA Space Apps Challenge 2026 · Sangolquí
<!-- English deck: the one uploaded to the global platform (decks must be in English). Keep it slide for slide in
     step with es.md. Format and rules: spaceapps/local-pitch/source/README.md. Build: (script no longer in the repository) -->

---
layout: cover
label: NASA Space Apps Challenge 2026 · Space Mission Design Game

# Farpoint HORIZON
> Build your own craft, launch it from the equator, fly it to the Moon, and keep it talking to Earth.
**Team SK-Horizons** · Quito, Ecuador · Local event Sangolquí (ESPE)
Alexander Kholodov · Sebastian Amaguaya

Notes:
(15 s) Who we are, the challenge, the one-line promise of the game.

---
layout: split
label: The problem
image: assets/photos/volcano_watch/sangay_landsat8_2022-11-05_truecolor.jpg | Sangay, Ecuador, seen by Landsat 8 (2022). Every image like this is the end of a chain of hard trade-offs. NASA Earth Observatory / USGS [S-eo]

## Mission design is taught as a list, not lived as a story
- A real mission trades **mass, power, data, delta-v, budget and time** against each other; on a whiteboard those trade-offs stay invisible.
- Students meet orbits as formulas, never as a craft they built, launched and kept alive.
- Ecuador put its first satellite in orbit in 2013 (NEE-01 Pegaso, a 1U CubeSat [S-pegaso]); the next generation needs a way in.
> No design is perfect. The challenge asks players to feel that.

Notes:
(35 s) The challenge's question; why it matters here.

---
layout: wide
label: The solution · how it plays
image: shot: the craft's design, a tile chosen and the gauges moving (scripts/screens/design.gd) | 1 · Design: ten questions, real parts
image: shot: the rocket builder with a stack and its delta-v per stage (scripts/screens/builder.gd) | 2 · Build the rocket
image: shot: liftoff from the pad near Cotopaxi, time speed shown | 3 · Launch from the equator
image: shot: lunar orbit or touchdown, the celebration | 4 · Arrive, operate, celebrate

## One complete mission, from the idea to the first signal home
flow: Choose a mission -> Design the craft (CML 1-4) -> Build the rocket -> Launch -> Fly to the target -> Operate with ground control -> Celebrate
Every choice moves the shared gauges and shows on the craft itself. Missing a goal is never a failure screen: every mission that flies achieves something, and doing more earns bonuses. Four stations for up to four players (engineer, scientist, pilot, ground control), with bots in the free ones.

Notes:
(60 s) Live demo here if the room allows it; otherwise these four pictures.

---
layout: split
label: NASA data at the core
image: assets/photos/moon_south_pole/south_pole_wide_lroc_wac.jpg | The Moon's south pole from the LRO Wide Angle Camera mosaic, re-projected by our script [S-lroc-wac]

## Real NASA data drives the physics
- **JPL Horizons**: where the Moon is on launch day; the trip is timed to meet it [S-horizons].
- **NSSDC Fact Sheets**: mass, radius and gravity of every body [S-nssdc-planets].
- **GIBS, Landsat, ASTER, LRO, SRTM**: the Earth, Ecuador's volcanoes and the Moon [S-gibs] [S-eo].
flow: NASA APIs -> `tools/content/data/` -> `data/nasa/*.json` -> physics and textures
### Checked, not tuned
Our Electron-type rocket lifts **313 kg** to low orbit (real: 300 kg); Cotopaxi's summit comes out at **5,876 m** (published: 5,897 m).

Notes:
(55 s) Name the datasets, show where each one acts, say how we checked. This slide carries RCD 1.1-1.3.

---
layout: split
label: Technology · the working game
image: shot: the menu or mission cards in the web build, browser frame visible | Plays in the browser: farpoint-horizon.web.app

## Built to run anywhere a school has a browser
- **Godot 4.7**, GL Compatibility renderer: runs on integrated GPUs and in the browser; desktop build as a fallback.
- **Data apart from code**: missions, parts, launchers and texts live in `data/*.json`, each value with its source.
- **Real behavior**: gravity of every body, real constants; time runs real by default and the player speeds it visibly (×1, ×10, ×100).
- **Checked on every push**: import, a headless run, a fuzz test and the web export; each change gets its own preview page.
### Play it
Live: farpoint-horizon.web.app (released build) · v0.3.0 story: https://farpoint-horizon--pr93-v0-3-0-a59yjofm.web.app · repository: github.com/alexanderkholodov1/farpoint-horizon/tree/v0.3.0 (MIT)

Notes:
(45 s) Architecture in one breath, then the live link. IET 2.1-2.5.

---
layout: split
label: Impact · next steps
image: assets/photos/volcano_watch/cotopaxi_landsat8_2015-09-15_truecolor.jpg | Cotopaxi from Landsat 8 (2015): the "Ecuador Volcano Watch" mission flies over it [S-eo]

## From Ecuador's volcanoes to the Moon, in Spanish and English
- **For** students, teachers and anyone curious: no install, every concept explained in plain words.
- **Local**: launch from the equator (the Earth's spin is a free boost), watch Cotopaxi and Sangay, follow El Niño.
- **Missions**: the six NASA chapters (Apollo 13, STS-61, Mars Pathfinder, LCROSS, DART, Artemis I) and the free scenarios: Ecuador Volcano Watch, Ocean Guardians and El Niño, Lunar Cartographer, Eye on the Universe, Ice at the Moon's South Pole, and Free mode.
### After the hackathon
- A story campaign; play with up to three friends online.
- Classroom pilots in Ecuador are planned; no partner is confirmed yet.

Notes:
(45 s) Who it is for, why it fits Ecuador, a realistic path. IR 3.1-3.5.

---
layout: split
label: Transparency · credits · team
image: shot: the credits film over the Earth, or the sources list in the game (scripts/screens/credits.gd) | Every source is in the game's credits

## Our work, our sources, our help
- **Made by us**: the game, its 3D models (from our scripts), music and sounds. **No AI-generated images.**
- **Cited**: every source of `docs/sources.md` is in the repository and in the game's credits. No NASA logos.
- **AI disclosed**: Claude Code (code, research), Antigravity and Cursor (code, a web test); Meshy and TRELLIS (3D references, see the README's "Use of AI"). The idea and design are ours.
### Team SK-Horizons
- **Alexander Kholodov**: the mission and the flight to the Moon.
- **Sebastian Amaguaya**: the rocket builder, 3D models, look and sound.

Notes:
(25 s) Close: thank the judges, invite them to play. RCD 1.5.
