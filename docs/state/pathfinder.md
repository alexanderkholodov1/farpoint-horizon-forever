# Mission 3, Mars Pathfinder: land by bouncing (issue #47)

- `go("pathfinder")`; in the story, chapter 3 (`data/story/pathfinder.json`) hands over to it at its Your turn card.
- The descent in real time from the radar's echo at 1.6 km (NASA's NSSDC numbers): steady the lander on its 20 m
  bridle, fire the rockets (98 m), cut the bridle (21.5 m), slow motion near each mark (said on screen). Flown right it
  lands at about 18 m/s, the real figure; too fast or still on the bridle: the airbags burst, lose screen, again.
- The bounces shown 4 times faster: about 12 m up, then at least 15 more; steer away from the big rocks; Inti counts.
- The airbags pull in, the petals open, Sojourner down the 20-degree rear ramp between its rails (off the edge: lose
  screen); the first wheel on Mars, its tracks; NASA's PIA00621 and PIA00633 close it.
- Sets: "mars_approach" (the cruise stage, Mars ahead) for the story's intro, "mars" (Ares Vallis) for the landing;
  the cuyes at their true size there (`actor_scale` 0.3: as tall as Sojourner).
