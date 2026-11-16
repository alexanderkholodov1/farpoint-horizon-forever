# Credits (C9, #14)

- The menu's **Credits** plays the credits as a short film (`scripts/screens/credits_film.gd`, about 90 s, Skip or
  Esc to the end): the camera flies the game's own Earth and Moon (a sunrise over the limb, Quito, the Moon, an
  Earthrise at true scale through a long lens) while title cards track in and type themselves out: the title, the two
  of us, the crew bots, what it is made with, the NASA data, the AI that helped, and every source rolling up. Its end
  card opens the full list below.
- The full list (`scripts/screens/credits.gd`, overlay "credits"): the team, what the game is built with (engine, font, Blender, outside
  models, NASA data, synthesized sounds), the AI agents used, and every source of `docs/sources.md` by section, with
  links that open in the browser (`scripts/screens/credits.gd`).
- They are built from the bibliography and the README by `python tools/content/credits.py` into `data/credits.json`;
  `tests/ci/credits.gd` fails when a source is missing from the credits, so after adding a source run the script.
- Still open in #14: the first mission that teaches while you play.
