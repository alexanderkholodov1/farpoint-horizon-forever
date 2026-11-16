# The pilot's flight to the Moon (#8): what is real and checked

Kept by the lead agent of alexanderkholodov1. Everything below runs in real time by default, with the flight panel's
time warp (×1 to ×100,000, keys `,` `.`; at most ×100 with an engine on; real time only near the ground).

- **Launch** (`scripts/flight/ascent.gd`, `scripts/screens/launch.gd`): about eight minutes to orbit, as a real
  climb; the climb's look is the teammate's (#12). `tests/ci/flight.gd` flies it with a bot, a lazy, an idle and a wild pilot.
- **The climb's look and guidance** (2026-11-15): the globe below is drawn as a planet six times smaller seen from
  the true height, so the ground slides by at its true rate seen from the craft (about 2.5 degrees a second in orbit)
  and the drawn height only grows (checked frame by frame: no drop at staging, no ceiling). The guidance lies flat by
  96 km and aims at 190 km over a minute and a half: hands-off and bot climbs reach about 172 km with no overshoot
  (it used to climb 50 km too high and fall back) and the nose stays between 70 and 90 degrees above 60 km. High up
  the camera watches from the side of the flight's plane. In orbit the clock keeps running, the stage turns prograde,
  the fairing opens in two halves (after cutoff, as some rockets do [S-wiki-fairing]), the craft is pushed off and
  unfolds its wings (`tests/look/separationshot.tscn`).
- **Trip** (`scripts/flight/transfer.gd`, `scripts/screens/flight.gd`): the Earth's and the Moon's pull, the Moon from
  JPL Horizons, as a map at true scale. Mission control plans the departure (phasing); the pilot burns at the mark,
  cuts, fires the mid-course correction and brakes into lunar orbit. Checked in `tests/ci/flight.gd` against real
  values: low orbit 87.7 min; plan 110 km over the Moon, trip 82 h (Apollo 11: 76 h); burn 371 s to 10.78 km/s;
  correction about 36 m/s; capture about 836 m/s in 346 s into a 93 × 157 km orbit.
- **Landing** (`scripts/flight/terrain.gd`, `descent.gd`, `scripts/screens/landing.gd`): NASA LOLA ground at Shackleton's
  rim, the Moon's gravity, real time.
- **Engines** (`data/engines.json`, issue #94): every burn follows the rocket equation, so the push grows as the tanks
  empty. The departure stage is Apollo 11's S-IVB with its spacecraft (135 t, Isp 421 s): 6.4 m/s² at ignition,
  13.6 at cutoff, 347 s like Apollo 11's TLI, leaving at 10,826 m/s (real 10,843). The braking is the craft's own
  engine (Apollo's SPS, 91 kN on 43.6 t): about 350 s for about 840 m/s (Apollo 11's LOI-1: 362 s for 889 m/s).
- Simplified, and said in the code: all in the plane of the ecliptic, no Sun's pull, the engine always along or
  against the motion, the small mid-course correction applied at once.
