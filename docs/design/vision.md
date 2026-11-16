# Vision

What the game will be and what it will have. Agreed by the team on 2026-11-14 as the direction for `v0.2.0`; details
are settled in the design round and recorded in `kb/decisions.md`. The sketch (`v0.1.0`) is a base to build on, not a
design to follow blindly: everything in it can be adjusted.

## What it will be
**In one sentence.** A 3D space-mission game where you, alone or with up to three friends, build your own craft, plan
its route, launch it, fly it to its destination, land it or keep it talking to Earth, and celebrate what it achieved.

- **The feeling: satisfaction and fun.** Wonder and the pride of an author: watching the craft you built lift off,
  unfold its panels, arrive and touch down. That satisfaction is carried by sound effects, animation and visual
  effects at every step, from snapping a part into place to the first signal from the destination.
- **Never a lost opportunity.** What you could not fit is not a failure and not a search for an unreachable best
  design. Every mission that flies achieves something, and doing more is rewarded with bonuses. The lesson of the
  challenge, that no design is perfect, shows as many good designs, never as a verdict against yours.
- **Humor.** Friendly, warm humor in the spirit of Kerbal Space Program: characters, reactions, small jokes in
  events. Blowing up a rocket is possible and fun when someone does it on purpose, and hard to do by accident.
- **Accessible, but with real craft.** For the general public: a complete, satisfying mission, simpler than Kerbal,
  where every concept is explained in plain words inside the game.
- **A team, each with a job.** Players take stations, and each station plays differently. Some decide (what to
  build, where to go, what to spend), some need skill: the pilot flies launch, maneuvers and landing with control
  panels and reflexes; ground control follows the mission from the control center and the map and reads the
  signals that come back. There are four stations; with fewer players, bots take the free ones and work with you as
  people would.
- **Together, never against.** Teams can see other teams' missions, watch them try, and appear on a leaderboard, but
  nobody wins by making someone else lose.

## What we take from Kerbal Space Program
The builder; planning the route and the orbits; the whole journey to the end; the freedom to invent; the humor; the
spectacle of launch and landing. Not its difficulty, and not its fail-and-retry loop.

## The flow of a mission
1. **Choose a mission** from a varied set (see below), at home and abroad, real and imagined.
2. **The brief.** Who asks for it and why, the destination, the budget and the time. Each mission offers extra
   objectives, drawn at random from a pool, and the team chooses which to pursue.
3. **The team.** Solo or up to four online (Firebase), each player at a station.
4. **The builder.** Assemble the craft and its rocket from parts in 3D; every part moves the shared gauges (mass,
   power, battery, data, communications, fuel, money, time) and you see the consequence travel through the craft.
5. **The route.** Plan orbits, transfers and the landing site on a 3D map, with the fuel you need against the fuel you
   have, travel time and the distance to Earth's antennas.
6. **The review.** Each station signs off; serious problems stop the launch, risks can be accepted knowingly.
7. **Launch.** From a spaceport on the equator (the Earth's spin gives a free boost there), with the pilot at the
   controls, stage separations and the craft's first deployment.
8. **The journey.** Maneuvers, arrival, and for landers the descent and touchdown, flown by the pilot.
9. **The mission.** Science, events and in-flight failures to solve, inspired by real ones; ground control keeps the
   signal and reads the data. Missions that come home end with re-entry and recovery; others, like Voyager, keep
   going and keep calling home.
10. **The celebration.** What the mission achieved, the bonuses earned by the team and by each station, the real
    mission most like yours, and the leaderboard. Then another mission, or a better version of this one.

## What it will have
**Core of `v0.2.0`.**
- A varied set of missions to choose from: Earth observation (volcanoes, El Niño and others), the Moon with a
  landing, Mars, Venus, a deep-space flyby that never returns, a sample-return mission, a space telescope, and
  invented or playful ones; launches from the equator, missions of every nation and imagined ones.
- Extra objectives per mission, random and chosen by the team (for example, data that only a special instrument can
  get), and bonus points for each station's achievements, so doing more always adds and never subtracts.
- The 3D builder with parts based on real values, every value cited.
- The live mission gauges, with consequences visible on the craft.
- Route and orbit planning on a 3D map, with the launcher and orbit compatibility check.
- Stations: at least the decision stations of the sketch, a pilot who flies launch, maneuvers and landing, and ground
  control with the control center, the map and signal-reading mini-games.
- Launch, journey and landing in 3D, with sound and effects; explosions that are hard to cause by accident.
- In-flight failures inspired by history, solved through mini-games, worth bonus points.
- Returning and one-way missions.
- The celebration screen, the real twin mission, and an online leaderboard and gallery of other teams' missions.
- Online play for up to four through Firebase, plus play on one shared screen.
- A first mission that teaches as you play; plain explanations everywhere; a credits screen with every source,
  formula and dataset and the AI agents used.
- English throughout; the web build on Firebase Hosting, and a desktop build as a fallback.

**If time allows.** More missions and parts, saved and shared designs, dialogue for the characters, a sandbox.

## How it looks and sounds
See `docs/design/criteria.md`. In short: a futuristic space identity and UI of the present; craft, rockets and places
as real as a documentary, modeled with real geometry and recognizable materials; characters that may be stylized;
soft light and depth, space lit by the Sun; a UI of its own, tactile, showing the few things that matter; two or
three characteristic colors, one warm, for the game's brand marks; sound with character, quiet by default.

## How it answers the challenge
The full mission from objective to operation (C7), resources that react to every decision (C3, C8, R1-R3), stations
for up to four (C4, C9, T1-T4), simulation and a report that explains why (C5, C6, G4, E4), several missions and
difficulties (F1, F3), random events (F2), real-time gauges (F6), a leaderboard and gallery (F7), and the real twin
mission (NASA data at the core). IDs from `kb/challenge/requirements.md`.
