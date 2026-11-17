# Visual identity: the palette of the horizon arc (issue #12)

The UI's colours are the brand's arc and nothing else (`scripts/ui/kit.gd`): horizon blue (`C_ACCENT`), sunrise amber
(`C_GOLD`, the one main action of a screen) and navy-tinted neutrals. Status stays inside it: fine is ice blue
(`C_OK`), attention is pale sunrise (`C_WARN`), and one red (`C_BAD`) only for what blocks the mission. No green, pink
or violet. The four stations are four points along the arc (`data/roles.json`); missions no longer carry a colour of
their own on screen.

The mission select (`scripts/screens/missions.gd`) is cards to pick: a NASA picture already in the game, the name, the
brief's first sentence and the facts as chips (`Kit.chip`, `Kit.cover`); the whole brief is the tooltip.

Look at it: `tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/identityshot.tscn` (LOOK_MODE=light for the
light appearance), shots in `shots/id_*.png`.

Left to do: the launch's pitch gauge still has a green marker (its text says "the green marker"); the map's planned
path in the flight is green; the design's left column is still text-heavy.

Since then (same branch): the menu is a list with Settings and Quit; the rocket builder is guided (one choice at a
time, only the parts that fit, a drawing and two facts per part, the rest when pointed at; `scripts/screens/builder.gd`);
the launch HUD's groups are all frosted panels of one tint (0.9) and show only the time speeds allowed now; each design
step says what to do in one line; a red board bar says in words what is wrong. The trip to the Moon has no dead ends
(`tests/look/flightsafe.tscn`).

The craft's design is guided the same way (`scripts/screens/design.gd`): six stages across the top (Orbit, Craft,
Power, Systems, Rocket, Launch), ten questions one at a time, tiles with a drawing (`scripts/ui/part_icon.gd`, shared
with the rocket builder), two facts and a mark (the best fit carries a star); the mission board is seven short
answers. The eight steps of `data/steps.json` stay underneath (who decides, the bots). The menu is a list straight on
space; playing is alone for now (the crew of friends and the ranking return in v0.3.0; `scripts/screens/team.gd` and
the ranking overlay are still in the code). Missions open in order (`scripts/core/progress.gd`), "all open" in Settings.
The guided first mission lights the new tiles and has a tip for the rocket builder.
