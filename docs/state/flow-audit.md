# Flow audit: speeds and times (#57)

Played on 2026-11-15 on `v0.3.0` (0.2.1), Godot 4.7.2, Windows, a window of 1600 x 900, through real clicks and keys
on the desktop (no state set by hand). Two missions from the menu to the report: Ecuador Volcano Watch (rideshare to
sun-synchronous orbit) and Ice at the Moon's South Pole (Falcon 9 type, the design's own best fits, opened with
Settings > All open), then the Moon trip a second time with time speeds picked by hand. A probe logged the screen, the
phase, how fast time ran and the mission clock every half second of real time; the numbers below come from that log.
Screenshots: `docs/state/flow-audit/`. The computed durations are checked in `tests/ci/flowaudit.gd`.

## Phase by phase

| Phase | What the player sees | Real value | In game (mission time · real time) | Verdict |
|---|---|---|---|---|
| Countdown and liftoff | T-10 at ×1, the rocket clears the tower at ×1, then "Auto · ×10 · engine on" | real time | 15 s of mission in 14 s | Right |
| Climb to orbit | Height, speed, Max-Q, staging, CRAFT AWAY | about 9 min to SECO-1 [S-nasa-crew10] | 8:07 (rideshare), 7:55 (Falcon 9 type); 463-475 s in the test · about 80 s at the automatic ×10 | Right |
| Climb at ×1 picked by hand | the clock and the world at real time | real time | 31.4 s of mission in 30.6 s | Right |
| Parking orbit | 165.7 km at 7.81 km/s | 7.80 km/s circular at that height (Kepler) | as real | Right |
| Parking orbit to 700 km SSO | "From this low parking orbit it climbs on to its own", then month 0 | a transfer of about 47 min | not flown, not shown, no time | Skipped in silence (`03`) |
| Operation, Earth orbit | "A month every 1.2 s: 2.2 million times faster", "laps its orbit every 99 min" | 98.6 min at 700 km (Kepler) | 24 months in 30 s at ×1, as said | Right |
| Plan of the trip | waits at ×1 for the player; trip 3 d 13 h | about 3 days [S-apollo11] | waits as long as the player wants | Right |
| Wait for the burn | "Ready", then time runs to the countdown | real wait 38 min | 36 min in 2.6 s (×907) | Right (the panel at that moment not screenshotted) |
| Countdown to the burn | 10 s countdown | real time | 18.7 s in 13 s | Right |
| Burn to the Moon (TLI) | "Six minutes of burning, sped up", the ring to cut | Apollo's S-IVB: about 6 min, 3.1-3.2 km/s | 3150 m/s in 370 s; ×50 then ×10 for the cut | Right as a chemical stage; wrong for the ion engine the design chose (`08`) |
| Speed shown during the burn | "×10" lit, "Time runs 50 times faster" | — | the button lit is not the speed | Wrong (`08`) |
| Coast to the correction | "ON YOUR WAY TO THE MOON", ×1k lit, "8,640 times faster" | about 5.6 h | 5.6 h in 3.7 s | Too fast to watch; wrong button lit (`10`) |
| Mid-course correction | countdown, 52-56 m/s | Apollo made small corrections | real time countdown | Right |
| Coast to the Moon | "Nothing to do: you coast", ×100k | about 2.5 days | 60 h in 2.5 s (SEGMENT_S 2.5) | Reads as a jump: three days pass before the player can look or pick a speed (`09`) |
| Whole trip | burn to the closest pass | about 73 h burn to lunar orbit [S-apollo11] | 78-82 h (82.4 h in the test) | Right |
| Capture burn (LOI) | BRAKING, "×10" lit, "25 times faster", then ×5 for the cut | about 6 min [S-afj-a11-loi] | 860-880 m/s in about 100 s (BURN_ACCEL 8.5 m/s2) | A third of the real length; wrong button lit (`11`) |
| Capture at ×1 picked by hand | the brake at real time | real time | 23.5 s in 23.5 s | Right |
| Lunar orbit | "a lap about every two hours", ×100, 25 s, then the landing by itself | 117.8-118.8 min at 100-110 km (Kepler) | 42 min of orbit shown (a third of a lap) | Right; the grades say "Cut LATE · Orbit LATE" for the computer's own cut (`12`) |
| Orbit to the landing | a fade, then the lander at 393 m over Shackleton's rim | Apollo's powered descent: about 12.5 min from 15 km | starts 430 m up, 620 m from the target (`data/scenarios.json`); the descent from orbit is cut | Skipped in silence (`13`) |
| Landing | ×1, "near the ground" | real time | 72.7 s of mission in 72.7 s | Right |
| Operation on the Moon | "A month every 1.2 s", the Sun "0.9 turns a second ... held still" | 29.5-day lunar day | 12 months in 15 s | Right |
| Report | after the celebration | — | — | Right |

## Findings that need code (each is an issue in milestone v0.3.0)
Recorded on 0.2.1. Since then (0.2.9) the burns follow the rocket equation with Apollo 11's engines, so the capture
burn's length is no longer the upper stage's; the rest are re-checked in issue #57.
- The time panel lights a speed that is not the one time runs at: ×10 lit at ×50 and ×25 (burns), ×1k at ×8,640 (an
  automatic wait). `scripts/flight/flight_hud.gd` `_show_warp`, `scripts/screens/flight.gd` `BURN_WARP`,
  `_time_to`.
- The coast to the Moon passes in 2.5 to 4 real seconds at ×8,640 and ×100,000 (`SEGMENT_S` 2.5 in
  `scripts/screens/flight.gd`): three days of the trip go by before a player can look at them or pick a speed.
- The engine chosen in the design does not change the flight: the south pole mission's own best fit is the electric
  (ion) engine, and the flight still makes a 6-minute 3,150 m/s burn and a 100-second capture, which an ion engine
  cannot do (it would take months and could not land).
- The capture burn takes about a third of a real one (`BURN_ACCEL` of the upper stage reused for the craft).
- Two legs are cut without a word: the climb from the parking orbit to the mission's orbit, and the descent from the
  lunar orbit to 430 m over the target.
- The flight computer's own cut is graded LATE.
- Following the design's defaults: Continue with no instrument reaches a blocked launch; the rocket stays on a
  rideshare that "lifts 0.0 kg" with no best fit; a best fit can turn another part red.
- Small things on screen: labels under panels, two notices stacked, a log event repeated.

## Not checked
- The other four missions (El Niño, Lunar Cartographer, Eye on the Universe, Free mode), and the speeds a player picks
  with `,` `.` (synthetic key presses from the desktop harness did not reach the design screen; clicks did).
- The web build.
