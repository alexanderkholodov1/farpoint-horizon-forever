# Story for v0.3.0: the cuyes who were there

Proposal (issue #41). It changes the missions, so the team decides before anything is built. Not part of the
2026-11-15 freeze.

## The idea
NASA learned by failing, bouncing and crashing, and it always came back. The player follows a small crew of cuy
astronauts (guinea pigs, the Andean *cuy*) who were "there" at six real NASA missions, in the order they happened.
History stays exactly as NASA tells it; the cuyes are slipped into the gaps, as if they had been in the room all
along. They make it a game and not an interactive documentary: they react, joke and get things wrong, while the
real numbers decide whether the mission works.

## Rules for writing it
- **Only NASA.** Every date, figure and event comes from a NASA page listed below. A figure we cannot find on a NASA
  page is not used, however well known it is (see "Not used" at the end).
- **Real, bounded missions.** Each one has a start, a climax and an end. No open-ended observatories.
- **Chronological.** The six missions are played in the order they happened; each one teaches something the next
  one needs.
- **The cuyes never change history.** They help, panic, celebrate; the outcome is NASA's.
- **The look.** Real craft and places, documentary-real (docs/design/criteria.md). The cuyes are the one stylized
  thing: stylized 3D characters with a deadpan face, our own design. The UI stays the game's dark frosted UI with the
  horizon arc.
- **Event rule to check:** no NASA logos, insignia or mission identifiers in anything we generate. We name the
  missions in text (as credit and history) but draw no patches, logos or insignia on craft, suits or screens.
- The Moon south pole mission (IM-1) is set aside; delete it later if nothing uses it.

## The crew (proposed names, to confirm)
Quechua names, short and easy to say in any language:
- **Rumi** (stone): the engineer. Fixes anything with what is at hand.
- **Killa** (moon): the scientist. Wants the data, even if it means crashing.
- **Inti** (sun): the pilot. Calm until the airbags.
- **Wayra** (wind): ground control. The voice on the radio.

## The six missions

### 1. Apollo 13 (April 1970): "Failure is part of the plan B"
- **Real history.** Launched April 11, 1970. On April 14 oxygen tank no. 2 exploded, about 200,000 miles from Earth.
  The crew moved into the lunar module, whose square CO2 canisters did not fit the command module's round openings;
  Mission Control worked out an adapter from plastic bags, cardboard and tape. Splashdown April 17, 1970.
- **Player.** Build the adapter from the parts list before the CO2 climbs, then fly the return.
- **Cuyes.** Rumi was hiding in the tape roll. "Square peg, round hole. Classic."
- **Climax.** The CO2 reading turns around.

### 2. STS-61, the first Hubble servicing mission (December 1993): "Glasses for a telescope"
- **Real history.** Endeavour launched Dec 2, 1993, for about 10 days. Hubble's mirror had a flaw; the crew made five
  back-to-back spacewalks totaling 35 hours and 28 minutes and installed, among other parts, COSTAR and WFPC2.
- **Player.** Rendezvous, then the spacewalks: pick the right part, in the right order, within the time.
- **Cuyes.** Killa insists on cleaning the lens. Nobody lets her.
- **Climax.** The first sharp image.

### 3. Mars Pathfinder (July 1997): "Land by bouncing"
- **Real history.** Launched Dec 4, 1996; landed on Mars on July 4, 1997, on airbags, and bounced about 15 times
  before coming to rest. The Sojourner rover rolled off. The mission ended Sept 27, 1997.
- **Player.** Entry, parachute, airbags; then drive Sojourner off the ramp.
- **Cuyes.** Inti, inside the airbags, counts the bounces out loud.
- **Climax.** Rest after the last bounce, and the first wheel on Mars.

### 4. LCROSS (October 2009): "The plan is to crash?" "Yes." "OK."
- **Real history.** Launched June 18, 2009, with LRO. On Oct 9, 2009 the spent Centaur stage hit the crater Cabeus at
  11:31 UT; the LCROSS shepherding spacecraft flew through the plume and hit about four minutes later, at 11:36 UT.
  On Nov 13, 2009 NASA announced that the data showed the mission had found water.
- **Player.** Aim the Centaur at Cabeus, then steer the shepherd through the plume and read the instruments before it
  hits.
- **Cuyes.** Killa: "The plan is to crash?" Wayra: "Yes." Killa: "OK."
- **Climax.** The four minutes between the two impacts.

### 5. DART (September 2022): "Push an asteroid"
- **Real history.** Launched Nov 24, 2021 (Nov 23 in Pacific time). On Sept 26, 2022 it hit Dimorphos on purpose. NASA
  confirmed that the impact shortened Dimorphos's orbit around Didymos from 11 hours 55 minutes to 11 hours 23
  minutes, a change of 32 minutes (uncertainty about plus or minus 2 minutes).
- **Player.** The final approach, aiming on the camera images; then the measurement weeks later.
- **Cuyes.** They have crashed into the Moon already; this time they crash with confidence.
- **Climax.** The 32 minutes.

### 6. Artemis I (November-December 2022), the final mission: "Everything we learned"
- **Real history.** SLS launched Nov 16, 2022, from Launch Pad 39B. Orion flew around the Moon and traveled 268,563
  miles from Earth, surpassing the distance record for a spacecraft designed to carry humans to deep space and back.
  It came back at 24,581 mph (Mach 32) and splashed down off the coast of San Diego on Dec 11, 2022, after 25 days,
  10 hours and 53 minutes. In the commander's seat sat a manikin, Commander Moonikin Campos, named after Arturo
  Campos, a key player in bringing Apollo 13 safely back to Earth.
- **Why it closes the story.** Each earlier mission comes back: the Apollo 13 engineer in the seat's name, the
  repaired-in-space attitude of STS-61, the trust in a hard landing from Pathfinder, the Moon's water from LCROSS, the
  precise aiming of DART.
- **Player.** Launch, the trip, the far point of the orbit, re-entry and splashdown.
- **Cuyes.** The whole crew rides hidden in the Moonikin's seat. At the far point, Rumi tells Campos's story.
- **Climax.** The far point, then re-entry at Mach 32 and the parachutes.

## Sources (NASA only)
- Apollo 13 mission details (tank, adapter, dates): https://www.nasa.gov/missions/apollo/apollo-13-mission-details/
- Apollo 13 (NSSDC, the tank explosion): https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1970-029A
- STS-61 / Servicing Mission 1:
  https://science.nasa.gov/mission/hubble/observatory/missions-to-hubble/servicing-mission-1/
- Mars Pathfinder: https://science.nasa.gov/mission/mars-pathfinder/ and
  https://www.jpl.nasa.gov/missions/mars-pathfinder-sojourner-rover/
- LCROSS: https://science.nasa.gov/mission/lcross/
- DART: https://science.nasa.gov/mission/dart/ and
  https://www.nasa.gov/news-release/nasa-confirms-dart-mission-impact-changed-asteroids-motion-in-space/
- Artemis I: https://www.nasa.gov/mission/artemis-i/ and https://www.nasa.gov/reference/artemis-i-mission-timeline/
- Commander Moonikin Campos:
  https://www.nasa.gov/news-release/public-names-moonikin-flying-around-moon-on-nasas-artemis-i-mission/

When a mission is built, its figures go into docs/sources.md with word IDs, as for everything else.

## Not used (not found on a NASA page yet)
- Apollo 13's distance record in miles or km, and that Artemis I beat Apollo 13 by name (NASA's timeline states the
  record without naming Apollo 13).
- How much water LCROSS found (a mass or volume figure).
- The Snoopy plush as Artemis I's zero-gravity indicator.
- Re-entry speed in km/s (only 24,581 mph, Mach 32, is NASA's figure). One timeline entry says "25,000 mph"; we use
  the 24,581 mph figure from the mission overview.

## Next
1. The team agrees the story and the crew names.
2. Design the cuyes from the story (stylized 3D, deadpan, own design).
3. Build the missions one by one, in order.
