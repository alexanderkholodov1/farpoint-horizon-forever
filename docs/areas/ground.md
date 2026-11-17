# Ground control in the operation (issue #63)

- Two mini-games open over the months of operation, from `scripts/minigames/desk.gd`; the operation's time-lapse waits
  while one is open (`desk.busy`, read by `scripts/screens/operation.gd`). A slow frame no longer skips months
  (the operation caps its step at 0.1 s), so a game always gets its month.
- **Hand it over** (`scripts/minigames/handoff.gd`): in the first month, only for a craft the Deep Space Network
  follows (Moon orbit or landed, L2). Real station places and sidereal time (`dsn.gd`); the Moon's direction from JPL
  Horizons rows (held at the last day of data), L2 opposite the Sun [S-usno-sun]. Opens at a calm moment (a dish 40°
  up and rising); one turn of the Earth takes 30 s, said on screen. Three handoffs win: 40 each when the old dish still
  had the craft, 15 when picked up after a gap. A handoff before the dish starts setting (below 25° and sinking) is
  refused with the reason.
- **Read the squiggles** (`scripts/minigames/telemetry.gd`, cases in `data/ground_telemetry.json`): after the first
  month whose log has a trouble with a case (storm, power, wheel), or by 45 % of the mission with the Apollo 12 case.
  Step 1 find the wrong line, step 2 send the fix; 120, minus 30 per wrong pick, at least 40. The real story shows
  at the end (Apollo 12 [S-afj12-launch], Voyager 1 [S-jpl-voyager1-fds], Kepler [S-kepler-k2]). The waveforms are
  drawn by the game, not real data.
- A bot at the station: Wayra does both and says so (no bonus). The bonus goes to `flight.ground` and, for a landed
  mission already settled at touchdown, straight to `flight.bonus`.
- Played as a player (2026-11-16) through the Moon (landed: +120 handoff, +90 squiggles, 210 in the report) and the
  volcano (SSO: squiggles after a G4 storm in month 8); tests in `tests/ci/ground.gd`.
- Known limit: a space-weather answer re-simulates the later months, which drops a ground entry logged after it from
  the mission log (the bonus stays).
