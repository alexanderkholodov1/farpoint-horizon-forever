# Mission 5, DART: push an asteroid (issue #49)

- `go("dart")`; in the story, chapter 5 (`data/story/dart.json`) hands over to it at its Your turn card. The crew fly
  it from mission control.
- Through DRACO, DART's camera (black and white, its real 0.29-degree view): the dot splits in two, the player picks
  the small moon and locks it (locking Didymos: lose screen). Steer with thruster pulses; drift alarms now and then
  (our simplification); the scope shows where DART will hit. Time 1,500, 300, then 6 times faster, real time for the
  last 20 s (said on screen). The last picture: SPACE as late as possible, its cm per pixel from DRACO's 0.5 arcsec
  pixel (the real last images: about 3 cm, NSSDC). Missing Dimorphos: lose screen.
- Weeks later, a rhythm game: the pair's light scrolls by (3 hours each second, said on screen); SPACE on each deep
  dip, before and after the impact; the orbit comes out about 11 h 55 and 11 h 23: 32 minutes shorter (NASA).
- Rules: `scripts/missions/dart/approach.gd`, tested by `tests/ci/dart.gd`; look: `tests/look/dartshot.tscn`. Set
  "dart_space" (DART, LICIACube, the rubble-pile pair; the impact's flash and ejecta).
