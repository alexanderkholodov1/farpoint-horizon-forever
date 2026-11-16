# The rocket builder (C1, #6)

- From the launcher step ("Build your own rocket"), the player stacks real parts (`data/parts.json`, models in
  `assets/parts/`): engines, tanks, stage separators, fairings and a pair of side boosters. Gauges update live: payload
  to the mission's orbit against the craft's mass, delta-v per stage, thrust to weight at liftoff, cost, and what still
  stops it from flying. "Fly this rocket" makes it the mission's launcher (`custom`), which the mission model reads like
  any catalog launcher (`scripts/craft/rocket_design.gd`).
- The launch screen flies the assembled rocket: the boosters fall away, then the first stage separates and the second
  stage's engine takes over.
- Checked against the real vehicles, with no tuning: the Electron-type preset carries 313 kg to low orbit (real
  300 kg), the Falcon 9-type 17.2 t (real about 17.5 t reusable) and 5.3 t toward GEO (real about 5.5 t).
- The builder's text is English; the rest of the game is still Spanish until B2.

## The craft, assembled (C1, #6)
- In the design steps the craft is put together part by part: a part just chosen flies in from outside and snaps
  into place with a click (`scripts/craft/craft_view.gd`, called by `world.rebuild_ship()`).
- The consequence shows on the craft: the part a check comes from glows and gets a breathing ring, red when it blocks
  the launch, amber when it costs science (the platform when the craft outweighs it or has too many instruments, an
  instrument too big for it, the solar wings when power or battery fall short, the antenna when the data does not
  fit down the link, the attitude control when pointing is too coarse, the engine when the delta-v does not reach the
  orbit). Each chosen part sits in its own holder in `scripts/world/ship_builder.gd` with a `part_key` meta.
