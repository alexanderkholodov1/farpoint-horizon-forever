# Coming home: re-entry and splashdown (issue #67)

- `go("reentry", {"craft": "apollo13", "then": [...], "back": ...})`; inside the story, Apollo 13's outro plays it
  (`data/story/apollo13.json`, scene `fixed`, `"play": "reentry"`) before the splashdown film.
- Rules in `scripts/flight/reentry.gd` (tested by `tests/ci/reentry.gd`), values in `data/reentry.json`, screen
  `scripts/screens/reentry.gd`. Real: the entry speed 36,211 ft/s and the radio blackout from 0:19 to 3:38
  [S-afj13-return]; drogues at 24,000 ft, mains at 10,000 ft, USS Iwo Jima about four miles away [S-apollo13-return].
  Ours, said on screen: the corridor's edges, the drift, the 24 s of plasma.
- Never a fail screen: hands off it still splashes down (the chutes open late on their own), with one or two stars.
- Artemis I keeps its own re-entry inside `scripts/screens/artemis1.gd` (Sebastian's); moving it onto this mechanic
  is for him to decide.
