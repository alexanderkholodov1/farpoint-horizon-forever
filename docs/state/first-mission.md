# The first mission, guided (C9, #14)

- The menu's **First mission · guided by the crew** starts the Moon's south pole with the player at every station, and a
  crew member rides along (`scripts/tutorial/coach.gd`, tips in `data/tutorial.json`, Spanish in `i18n/tutorial.csv`).
- On each design step the station's bot (Skip, Rivet, Quark, Echo) says what the step is about in plain words, with
  real numbers cited in the data, and lights the option or button to press with a gold ring; in the launch, the
  flight, the landing, the operation and the report it says what is happening in the top-right corner and steps aside.
- The design it leads to was checked with `Mission.compute()`: no warning, 243 M$ of 380.
- It changes nothing in the game: it only reads the screen and points. "Got it" hides a tip; "End the guided mission"
  or going back to the menu ends it.
