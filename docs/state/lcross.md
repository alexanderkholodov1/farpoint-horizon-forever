# Mission 4, LCROSS: the plan is to crash (issue #48)

- `go("lcross")`; in the story, chapter 4 (`data/story/lcross.json`) hands over to it at its Your turn card. The crew
  fly it from mission control (Houston set with the whole crew): nobody rides a craft built to crash.
- The aim, at separation (01:50 UT, NASA's NSSDC): on NASA's LROC mosaic of the south pole, Cabeus drawn where the
  planetary gazetteer puts it; small burns move the impact point (a burn of v moves it v times the 9 h 41 min left).
  Outside Cabeus or on its sunlit floor: lose screen, again.
- 5,000 times faster to 6 s before the impact (said on screen), a countdown, the Centaur's flash at 11:31:19.5 UT,
  a shock ring, slow motion, the plume rising into the sunlight. The four minutes shown 4 times faster (said on
  screen), real time for the last 15 km, through the shepherding craft's camera that keeps about 46 km in frame.
- Glints of ice fly out of the plume (our simplification of clumps of ejecta): chase each with the crosshair
  (mouse or WASD), Space to catch it; combos; a press with no glint pauses the instruments; the craft wobbles now and
  then. 8 readings needed (stars at 8, 12, 16). Signal lost at 11:35:36.1 UT with static; NASA's facts close it.
- Rules: `scripts/missions/lcross/impact.gd`, tested by `tests/ci/lcross.gd`; look: `tests/look/lcrossshot.tscn`; to play the
  chapter alone: `tests/look/lcrossplay.tscn`. Set "lcross_space" (the Centaur and the shepherding craft, the Moon ahead).
