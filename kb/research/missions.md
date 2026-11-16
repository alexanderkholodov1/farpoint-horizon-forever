# Mission catalog research

Candidate missions for the game, each with a real twin and real numbers. Researched 2026-11-14. Companion data file: `kb/data/missions.json` (same ids).

## How to read this file
- Every number carries its source URL. Almost all values were read on Wikipedia mission pages (fetched 2026-11-14) because NASA pages often omit launch mass, power and cost. Per `kb/data/README.md`, a Wikipedia-sourced value is "documented" only in the sense that a cited page states it; **verify against the agency page before showing it to players**. Where a NASA or agency page was read, it is named.
- "(inference)" marks a value or claim computed or judged by us. "Not found" means no citable value was read; nothing was guessed.
- Ids in backticks match `missions.json`. Launch from the equator is a game rule (spaceport such as Kourou, 5.2 N, https://en.wikipedia.org/wiki/Guiana_Space_Centre; Alcantara, 2.3 S, https://en.wikipedia.org/wiki/Alc%C3%A2ntara_Launch_Center). Many real twins launched from higher latitudes; the game's equator rule is a simplification that makes every orbit reachable (inference).
- Equator fact usable in the builder: from Kourou the minimum reachable inclination is about 6 degrees, against 28.5 degrees from Cape Canaveral, and a Soyuz that lifts 1.7 t to GTO from Baikonur lifts 2.8 t from Guiana (https://en.wikipedia.org/wiki/Guiana_Space_Centre).

---

## 1. Volcano Watch (`volcano_watch`)
**Question.** Which volcano is about to wake up, and how much ash and gas will it throw into the sky? Eruptions can ground airplanes, bury towns and even cool the whole planet for a year or two.

**Route.** Earth orbit, sun-synchronous (about 700 km), no landing, no return. Launched directly to orbit; no transfer. Lifetime of years.

**Twins.**
- Landsat 9 (NASA/USGS, 2021): Atlas V 401 from Vandenberg, 27 Sep 2021; 2,711 kg; 4,300 W; 705 km sun-synchronous, 98.2 deg; instruments OLI-2 (9 bands, 30 m, pan 15 m) and TIRS-2 (thermal infrared); 16-day revisit; build contract US$129.9 M. https://en.wikipedia.org/wiki/Landsat_9
- Suomi NPP (NASA/NOAA, 2011): Delta II 7920-10C; 2,128 kg; about 2 kW; about 833 km sun-synchronous. https://en.wikipedia.org/wiki/Suomi_NPP
- Context event: Mount Pinatubo 1991 put about 15 million tons of SO2 into the stratosphere and cooled the Earth by about 0.6 C over 15 months (NASA Earth Observatory; other NASA pages say 17 to 20 million tons, so the figure is approximate). https://earthobservatory.nasa.gov/IOTD/view.php?id=1510 and https://ntrs.nasa.gov/citations/19990021520
- Data rate and ground network for Landsat 9 and Suomi NPP: not found in the pages read.

**Extra objectives.**
1. "Sulfur cloud": carry a UV/IR gas instrument to track the SO2 plume. Inspired by Pinatubo's SO2 haze and 0.6 C cooling. Source: https://earthobservatory.nasa.gov/IOTD/view.php?id=1510
2. "Hot spot": a thermal infrared sensor (like TIRS-2) sees the glow of lava under cloud-free night skies. The sensor is documented (https://en.wikipedia.org/wiki/Landsat_9); that it finds lava is our inference.
3. "Sharper eyes": a 15 m panchromatic band (OLI-2) resolves a new lava flow field. Source: https://en.wikipedia.org/wiki/Landsat_9
4. "Early warning": shorter revisit through a second satellite (design choice, inference); the real revisit is 16 days for one Landsat.

**Fun.** Pilot: precise insertion into a sun-synchronous orbit (inclination near 98 deg). Ground control: reading thermal images to spot which volcano is warming; a download window mini-game. Risk: orbit mistakes mean fewer passes. Humor: the volcano has a name like "Mount Grumble" that sulks in the clouds.

**Difficulty: easy.** Simple orbit, no landing, no return; and sun-synchronous orbits teach the builder's power and eclipse gauges.

---

## 2. El Nino Watch (`el_nino_watch`)
**Question.** Is the Pacific Ocean getting a fever? A warm pool that drifts east changes rain, floods and droughts around the world, so measuring the sea's height tells farmers and cities what is coming.

**Route.** High Earth orbit around 1,336 km, 66 deg inclination, 10-day repeat; no landing, no return. Radar altimeter measures sea height; height is a proxy for heat.

**Twins.**
- TOPEX/Poseidon (NASA/CNES, 1992): Ariane 42P from Kourou, 10 Aug 1992; about 2,400 kg; 1,340 km, 66 deg, 112 min; sea surface height of 95% of the ice-free ocean to 3.3 cm; cost and power not found. https://en.wikipedia.org/wiki/TOPEX/Poseidon
- Sentinel-6 Michael Freilich (NASA/ESA/EUMETSAT/NOAA, 2020): Falcon 9 Block 5 from Vandenberg, 21 Nov 2020; 1,192 kg; 891 W; 1,336 km, 66 deg, 10-day repeat; Poseidon-4 altimeter, AMR-C radiometer (NASA), GNSS-RO. Sea level record from 1992 continues to at least 2030. https://en.wikipedia.org/wiki/Sentinel-6_Michael_Freilich
- NASA findings: the 1997-98 El Nino warm pool peaked on 10 Nov 1997 and was about 1.5 times the size of the continental US; sea level rose as much as 16 inches in the eastern equatorial Pacific; the western Pacific stayed about 30 cm below normal in May 1998. https://eospso.gsfc.nasa.gov/sites/default/files/publications/1998_El_Nino.pdf

**Extra objectives.**
1. "Warm pool tracker": watch the warm pool cross the Pacific over months; sea height as heat proxy. https://eospso.gsfc.nasa.gov/sites/default/files/publications/1998_El_Nino.pdf
2. "Centimeter club": reach about 3.3 cm height accuracy with the radiometer that corrects atmospheric delay (TOPEX Microwave Radiometer / AMR-C). https://en.wikipedia.org/wiki/TOPEX/Poseidon
3. "Where am I exactly": add a GPS or DORIS orbit receiver to pin the satellite's position; TOPEX/Poseidon proved GPS could do it. https://en.wikipedia.org/wiki/TOPEX/Poseidon
4. "Tide map": spend a season on global tides and currents, as the real twin did. https://en.wikipedia.org/wiki/TOPEX/Poseidon

**Fun.** Ground control: a map of the Pacific turning red as the warm pool grows, then a "farmers' forecast" the team sends. Spectacle: 1,336 km is a high orbit, so the pilot sees a big blue Earth. Humor: a fish-shaped mascot reports "I swam east, sorry."

**Difficulty: easy.** Circular orbit, one big instrument; the challenge is the higher orbit's fuel and radiation, a good lesson.

---

## 3. Wildfire Watch (`wildfire_watch`)
**Question.** Where is the forest burning right now, and where will the smoke go? Fast alerts help firefighters and keep families out of danger.

**Route.** Sun-synchronous LEO (about 700-830 km); no landing, no return; speed of the downlink matters more than the orbit.

**Twins.**
- Suomi NPP with VIIRS (NASA/NOAA, 2011): see mission 1 numbers; VIIRS data "will also be used to observe active fires". https://en.wikipedia.org/wiki/Suomi_NPP
- Landsat 9 thermal sensor TIRS-2, 705 km. https://en.wikipedia.org/wiki/Landsat_9
- NASA FIRMS delivers fire detections in near real time; the commonly quoted latency is about 3 hours from observation. This came from secondary sources; no official NASA number was found. The 375 m VIIRS product name is documented on https://catalog.data.gov/dataset/viirs-s-npp-i-band-375-m-active-fire-product-nrt-vector-data-6f751 (404 on 2026-11-16)

**Extra objectives.**
1. "Under the smoke": thermal infrared sees fire through smoke. Source (instrument): https://en.wikipedia.org/wiki/Landsat_9; claim is inference.
2. "Three-hour alert": get the fire map to the ground within about 3 hours, as FIRMS does (secondary, https://africa-knowledge-platform.ec.europa.eu/dataset/fires-last-72-hours (blocks automated checks; open in a browser)).
3. "Night eyes": VIIRS-class sensors work at night; the 375 m product improved nighttime performance (NASA Earthdata, via search summary). https://www.earthdata.nasa.gov/learn/find-data/near-real-time/firms
4. "Burn scar": a 30 m optical sensor maps the burned area afterward. https://en.wikipedia.org/wiki/Landsat_9

**Fun.** Ground control: a race, a fire appears on the map and the downlink pass must be caught before it passes; the faster the data, the more hectares saved. Humor: "marshmallow" alerts for campfires.

**Difficulty: easy to medium.** Simple orbit, but the data-latency puzzle rewards good ground station choice.

---

## 4. Hurricane Hunter (`hurricane_hunter`)
**Question.** How strong is the wind inside a hurricane, where planes cannot safely fly? Better forecasts of storm strength save lives on coasts.

**Route.** Low-inclination LEO (35 deg, about 500 km), a constellation of 8 small satellites; launched together by one air-launched rocket; no landing, no return.

**Twins.**
- CYGNSS (NASA, 2016): Pegasus XL air-launched from the Stargazer aircraft about 201 km off Cape Canaveral, 15 Dec 2016; 8 microsatellites of 28.9 kg and 34.7 W each; 35 deg inclination, 514 x 536 km; delay Doppler instrument reads GPS signals bounced off the ocean; revisit about 7 hours; wind uncertainty about 1.4 m/s at low and moderate winds and about 11% inside cyclones; NASA sponsored it for US$152 M (2012). https://en.wikipedia.org/wiki/Cyclone_Global_Navigation_Satellite_System
- Data rate and ground network: not found.
- A low-inclination orbit revisits the tropics often (inference).

**Extra objectives.**
1. "Eye of the storm": measure winds in the inner core, even under heavy rain, using GPS reflections. https://en.wikipedia.org/wiki/Cyclone_Global_Navigation_Satellite_System
2. "Flood map": the same sensor maps flooded land, even under forest. https://en.wikipedia.org/wiki/Cyclone_Global_Navigation_Satellite_System
3. "Soil thirst": estimate soil moisture over land. Same source.
4. "Free steering": space the 8 satellites using only drag, with no fuel, as CYGNSS did (differential drag). Same source.

**Fun.** Spectacle: the air-launch is unique; in the game a variant could be "launch from a plane over the equator" (design idea). Pilot: deploy 8 sats and space them. Ground control: a storm map where the winds appear as colored rings. Humor: each microsat gets a silly name.

**Difficulty: medium.** Eight craft to manage, but each one is tiny.

---

## 5. Ice Sentinel (`ice_sentinel`)
**Question.** How fast are the ice sheets and sea ice melting, and how much will the sea rise? Rising seas threaten coastal cities.

**Route.** Near-polar LEO, 92 deg inclination, about 480-496 km; no landing, no return. High inclination means the equatorial boost helps less (inference).

**Twin.**
- ICESat-2 (NASA, 2018): Delta II 7420-10C (its last flight), Vandenberg, 15 Sep 2018; 1,514 kg; 1,200 W; 92 deg; ATLAS laser altimeter, green 532 nm, 10 kHz, six beams, one elevation every 70 cm along track. Goals: ice-sheet change, sea-ice thickness, canopy height. https://en.wikipedia.org/wiki/ICESat-2
- Cost, data rate and ground network: not found.

**Extra objectives.**
1. "Tree top": the same laser measures forest height. https://en.wikipedia.org/wiki/ICESat-2
2. "Sea ice thickness": measure floating ice thickness. Same source.
3. "Inland water": rivers and lakes heights. Same source.
4. "Six beams": adding extra beams widens the swath (design choice; the real ATLAS uses three pairs).

**Fun.** Ground control: build an ice-height map line by line. Pilot: precisely hold a polar orbit. Humor: a penguin nervously asks for the data.

**Difficulty: medium.** Polar orbit needs far more delta-v from a low-latitude spaceport (inference), a lesson in plane changes.

---

## 6. Air Quality Stare (`air_quality_stare`)
**Question.** How dirty is the air over a city this hour? Hourly pollution maps warn people with asthma and show where smog comes from.

**Route.** Geostationary orbit, 91 deg W; no landing, no return. A good fit for an equatorial spaceport; the real TEMPO flew as a hosted payload on a commercial satellite.

**Twin.**
- TEMPO (NASA, 2023): Falcon 9 Block 5 from Cape Canaveral, 7 Apr 2023, hosted on Intelsat 40e at 91 deg W; spectrometer 290-740 nm, 0.6 nm spectral resolution; hourly ozone, nitrogen dioxide and formaldehyde over North America. Mass, power, cost, data rate not found. https://en.wikipedia.org/wiki/Tropospheric_Emissions:_Monitoring_of_Pollution

**Extra objectives.**
1. "Rush hour": see the hourly rise of NO2 over cities. Same source.
2. "Ozone watch": add the ozone band. Same source.
3. "Formaldehyde": a sign of fires and plants. Same source (listed species).
4. "Hosted ride": share a satellite and save mass (the real mission did); cost saving not found.

**Fun.** Ground control: the stare, a movie of pollution through the day. Pilot: GTO transfer and circularization. Humor: a smog "monster" shrinks as the team fixes it.

**Difficulty: medium.** GEO needs a transfer burn; no landing.

---

## 7. Moon South Pole Lander (`moon_south_pole`)
**Question.** Is there water ice in the dark craters at the Moon's south pole? Water means drinking water and rocket fuel for future explorers.

**Route.** Earth to Moon transfer, orbit, then powered descent and landing near 69 S; one-way. Chandrayaan-3: 40 days from launch to landing.

**Twins.**
- Chandrayaan-3 (ISRO, 2023): LVM3 M4, Sriharikota, 14 Jul 2023; 3,900 kg; lander Vikram 1,726 kg, rover Pragyan 26 kg, propulsion module 2,148 kg; power 758 W (propulsion), 738 W (lander), 50 W (rover); landed 23 Aug 2023 at 69.373 S; about 40 days; cost about US$80 M (initial request); first in-situ sulfur detection at the south pole; surface 355 K peak, and 70 C near the surface was "not expected"; rover drove 101.4 m. https://en.wikipedia.org/wiki/Chandrayaan-3
- LRO (NASA, 2009): Atlas V 401, 18 Jun 2009; 1,916 kg; 1,850 W; polar orbit about 20 x 165 km; instruments LOLA, LAMP, LEND, Diviner, LROC (0.5 m/px), Mini-RF; US$583 M including LCROSS ($79 M); more than 192 TB. https://en.wikipedia.org/wiki/Lunar_Reconnaissance_Orbiter
- LCROSS impact at Cabeus, 9 Oct 2009: water ice 5.6 +/- 2.9% by mass, 155 +/- 12 kg of water vapor and ice in view. https://pubmed.ncbi.nlm.nih.gov/20966242/ (Science abstract, via search)
- Delta-v and data rate: not found.

**Extra objectives.**
1. "Dig for ice": a neutron detector (LEND) maps hydrogen. https://en.wikipedia.org/wiki/Lunar_Reconnaissance_Orbiter
2. "Look into the dark": UV mapping of permanently shadowed craters (LAMP). Same source.
3. "Hot ground": thermal probe measures temperature in the top 10 cm (ChaSTE). https://en.wikipedia.org/wiki/Chandrayaan-3
4. "Moonquakes": a seismometer (ILSA). Same source.
5. "Sulfur": an element-analysis instrument on the rover (LIBS). Same source.

**Fun.** Pilot: the descent and hover, the star moment. Ground control: waiting for a signal at 69 S. The spectacle: dust on landing; the "pragyan" rover rolls out. Humor: the lander's hop test, a nervous little hop of 40 cm.

**Difficulty: hard.** Landing needs exact fuel and hovering.

---

## 8. Mars Rover and Scout Helicopter (`mars_rover`)
**Question.** Did Mars ever have life, and what do the rocks of an old lake say? A helicopter scout shows the rover where to drive.

**Route.** Direct Earth-Mars transfer, about 29 weeks cruise, entry, parachute and sky crane landing; one-way.

**Twin.**
- Perseverance (NASA, 2020): Atlas V 541, 30 Jul 2020; launch mass 4,060.5 kg (https://en.wikipedia.org/wiki/Mars_2020); rover 1,025 kg; MMRTG about 110 W; landed 18 Feb 2021 in Jezero Crater; cruise about 29 weeks; relay UHF up to 2 Mbit/s and X-band 800 bit/s; 7 science instruments; cost about US$2.75 B (hardware $2.2 B, launch $243 M, operations $291 M); landing within 7.7 x 6.6 km using terrain relative navigation; MOXIE made 122 g of oxygen; ancient lake and delta, a "possible biosignature" rock (2024). https://en.wikipedia.org/wiki/Perseverance_(rover) . C3: not found.
- Ingenuity helicopter (NASA, 2021): 1.8 kg; rotor 1.21 m at 2,400-2,900 rpm; 350 W motor power; first flight 19 Apr 2021 (about 3 m, 40 s); 72 flights up to 167 s, altitude 24 m; 17.2 km total; about US$80 M to build; air density about 1/100 of Earth's. https://en.wikipedia.org/wiki/Ingenuity_(helicopter)

**Extra objectives.**
1. "Make air": a MOXIE-type oxygen experiment (5.37 g/hour best). https://en.wikipedia.org/wiki/Perseverance_(rover)
2. "Hear Mars": microphones record slow, quiet sound. Same source.
3. "Scout flight": launch a helicopter; fly 90 s ahead of the rover. https://en.wikipedia.org/wiki/Ingenuity_(helicopter)
4. "Rock radar": ground-penetrating radar (RIMFAX) maps layers below the wheels. Same source (instrument list).
5. "Ancient lake": drill and cache a core from the delta. Same source.

**Fun.** Pilot: the entry and sky crane landing, the best spectacle in the game. Ground control: commands with delay; autonomous helicopter flights. Humor: the rover names rocks.

**Difficulty: hard.** Entry, descent and surface, with a power budget.

---

## 9. Mars Orbiter and Relay (`mars_orbiter`)
**Question.** Where did Mars's air and water go? Understanding a world that lost its atmosphere teaches us how fragile ours is.

**Route.** Direct transfer to Mars (about 10 months, MAVEN arrived 22 Sep 2014 after launch 18 Nov 2013, so about 308 days (inference)); orbit insertion; no landing, no return; later a relay for rovers.

**Twins.**
- MAVEN (NASA, 2013): Atlas V 401, 18 Nov 2013; 2,454 kg; 1,135 W; orbit 180 x 4,500 km; 8 instruments (STATIC, IUVS, NGIMS, SWEA, LPW, SWIA, SEP, MAG); US$582.5 M through the prime mission; UHF relay up to 2,048 kbit/s; contact lost 6 Dec 2025. Found that the solar wind stripped Mars's atmosphere and that loss surges in solar storms. https://en.wikipedia.org/wiki/MAVEN
- MRO (NASA, 2005): Atlas V 401; 2,180 kg; orbit about 250 x 316 km; HiRISE 0.3 m resolution; up to 6 Mbit/s to Earth; US$716.6 M prime mission. https://en.wikipedia.org/wiki/Mars_Reconnaissance_Orbiter

**Extra objectives.**
1. "Solar wind check": particle and field instruments. https://en.wikipedia.org/wiki/MAVEN
2. "Storm day": measure the surge in loss during a solar storm. Same source.
3. "Relay duty": carry a UHF radio and relay another team's rover (online co-op idea). Same source (MAVEN relayed rovers).
4. "Sharp eye": a 0.3 m camera finds rover tracks. https://en.wikipedia.org/wiki/Mars_Reconnaissance_Orbiter

**Fun.** Ground control: the relay, passing a lander's data up and down. Pilot: orbit insertion burn. Humor: the orbiter as a radio "taxi".

**Difficulty: medium.**

---

## 10. Venus: Radar Mapper and Cloud Balloon (`venus_explorer`)
**Question.** Why did Earth's twin turn into an oven under thick clouds, and what is on its surface? It shows what a runaway greenhouse looks like.

**Route.** Transfer to Venus, orbit, optional atmospheric balloon or entry probe. No return.

**Twins.**
- Magellan (NASA, 1989): Space Shuttle Atlantis STS-30 with an IUS, 4 May 1989; 3,445 kg; about 1,030 W; arrived 10 Aug 1990; 3.7 m radar antenna; mapped about 98% of the surface, resolution about 101-250 m per pixel; data 268.8 kbps X-band; 1993 aerobraking to a 180 x 540 km orbit; found lava channels over 6,000 km long, few craters (surface under about 800 million years old), no plate tectonics. Cost: not found. https://en.wikipedia.org/wiki/Magellan_(spacecraft)
- Vega 1 and 2 balloons (USSR/France, 1985): a 21 kg assembly with 6.9 kg gondola floating at about 54 km, working over 46 hours, measuring temperature, pressure, wind and aerosols. https://en.wikipedia.org/wiki/Vega_program
- DAVINCI (NASA, planned): launch listed December 2030; 63-minute descent; mass spectrometer, laser spectrometer, descent imager; status "back on track" as of Nov 2026 (Wikipedia). https://en.wikipedia.org/wiki/DAVINCI
- VERITAS (NASA, planned): radar mapper, launch listed 2032. Same source.

**Extra objectives.**
1. "Volcanoes today": look for active volcanism with a radar mapper (Magellan found huge volcanic domes). https://en.wikipedia.org/wiki/Magellan_(spacecraft)
2. "Brake with air": aerobrake to save fuel, as Magellan tested in 1993. Same source.
3. "Float with the clouds": a balloon at 54 km. https://en.wikipedia.org/wiki/Vega_program
4. "Taste the air": a mass spectrometer during a 63-minute descent. https://en.wikipedia.org/wiki/DAVINCI
5. "Rendezvous with a comet": the Vega spacecraft went on to Halley (8,030-8,890 km flybys, 1,500 images). https://en.wikipedia.org/wiki/Vega_program

**Fun.** Pilot: aerobraking, skimming the atmosphere. Spectacle: a balloon drifting among yellow clouds. Humor: "Venus: the planet that really wants to be your next hot tub."

**Difficulty: medium.** Heat and power, but no landing.

---

## 11. Grand Tour: One-Way to the Stars (`grand_tour`)
**Question.** How far can a machine we build travel, and what is out there between the stars? It shows what we are made of and how far we reach.

**Route.** Escape trajectory with planetary gravity assists; one-way; keeps calling home for decades.

**Twins.**
- Voyager 1 (NASA, 1977): Titan IIIE from Cape Canaveral, 5 Sep 1977; 815 kg; 3 RTGs, 470 W at launch; 11 instruments; Jupiter 5 Mar 1979 (349,000 km from center); Saturn 12 Nov 1980 (124,000 km above clouds); crossed the heliopause on 25 Aug 2012 at about 121 AU; speed 16.9 km/s; 173 AU from Earth in Nov 2026; signal takes over 23 hours; DSN at 2.3 or 8.4 GHz; found Io's volcanoes. https://en.wikipedia.org/wiki/Voyager_1
- Voyager program: planetary alignment about once every 175 years; power fell to about 268 W by 2011; data rate about 115,000 bits/s at Jupiter, halved by Saturn; golden record. https://en.wikipedia.org/wiki/Voyager_program
- New Horizons (NASA, 2006): Atlas V 551; 478 kg; 245.7 W RTG; speed about 16.26 km/s; Jupiter assist on 28 Feb 2007 added about 4 km/s and saved about 3 years; Pluto 14 Jul 2015 at 12,500 km; light time about 4 h 25 min; about 1 kbit/s; about US$700 M. https://en.wikipedia.org/wiki/New_Horizons
- Program cost and C3: not found.

**Extra objectives.**
1. "Io's volcanoes": a camera at Jupiter sees active volcanoes. https://en.wikipedia.org/wiki/Voyager_1
2. "Edge of the Sun": a plasma and magnetic field instrument detects the heliopause. Same source.
3. "Gravity slingshot": use Jupiter for +4 km/s. https://en.wikipedia.org/wiki/New_Horizons
4. "Message to the stars": carry a golden record. https://en.wikipedia.org/wiki/Voyager_program
5. "Nitrogen heart": a Pluto flyby. https://en.wikipedia.org/wiki/New_Horizons (only the flyby is sourced).

**Fun.** Ground control: reading a whisper that takes 23 hours; the long wait. Spectacle: the slingshot. Humor: sending a postcard that will arrive in 40,000 years (inference).

**Difficulty: medium.** Needs routing, but nothing to land.

---

## 12. Asteroid Sample Return (`sample_return`)
**Question.** Do space rocks carry the ingredients of life, and what are planets made from? A grain of an ancient rock brought home answers it.

**Route.** Transfer to a near-Earth asteroid, rendezvous, touch and go, return, capsule re-entry; returning, no landing (touch only).

**Twins.**
- OSIRIS-REx (NASA, 2016): Atlas V 411, 8 Sep 2016; 2,110 kg; 1,226-3,000 W; arrived Bennu 3 Dec 2018; sample about 121.6 g, landed in Utah 24 Sep 2023; cost about US$800 M plus US$183.5 M launch; hydrated clays, 14 of 20 amino acids and all 4 nucleobases found. https://en.wikipedia.org/wiki/OSIRIS-REx
- Hayabusa2 (JAXA, 2014): H-IIA 202; 600 kg; 2.6 kW at 1 AU; ion engines 28 mN; arrived Ryugu 27 Jun 2018; impactor fired a 2.5 kg copper projectile; MASCOT 9.6 kg lander; sample about 5.4 g, landed 5 Dec 2020; about 16.4 billion yen (about US$104 M, 2010). https://en.wikipedia.org/wiki/Hayabusa2

**Extra objectives.**
1. "Crater maker": fire an impactor to expose fresh rock. https://en.wikipedia.org/wiki/Hayabusa2
2. "Hopper": drop a small lander. Same source.
3. "Laser map": laser altimeter maps the surface. https://en.wikipedia.org/wiki/OSIRIS-REx
4. "Clean sample": avoid contamination (a returned Ryugu sample showed microbes from Earth). https://en.wikipedia.org/wiki/Hayabusa2
5. "Amino acid hunt": keep enough sample mass. https://en.wikipedia.org/wiki/OSIRIS-REx

**Fun.** Pilot: the touch-and-go, a few seconds' contact. Ground control: re-entry capsule tracking. Spectacle: the capsule's fireball and parachute. Humor: the sample is "a pinch of space dust, handle with kindness."

**Difficulty: hard.** Return and re-entry add steps.

---

## 13. Space Telescope at L2 (`telescope_l2`)
**Question.** What did the first galaxies look like? The farthest light shows how everything began.

**Route.** Direct to Sun-Earth L2, about 1.5 million km away; about a month of transit; halo orbit; no landing, no return.

**Twin.**
- JWST (NASA/ESA/CSA, 2021): Ariane 5 ECA+ VA256 from Kourou, 25 Dec 2021; 6,500 kg; 2 kW; arrived L2 24 Jan 2022; Ka-band science downlink up to 28 Mbit/s; S-band uplink 16 kbit/s, downlink 40 kbit/s; 159 L hydrazine and 79.5 L oxidizer; about US$9.7 B; instruments NIRCam, NIRSpec, MIRI, FGS/NIRISS. https://en.wikipedia.org/wiki/James_Webb_Space_Telescope and https://science.nasa.gov/mission/webb/ . Delta-v: not found.

**Extra objectives.**
1. "Deep field": a long exposure. https://en.wikipedia.org/wiki/James_Webb_Space_Telescope
2. "Hidden planet": find an exoplanet. https://science.nasa.gov/mission/webb/
3. "Far flash": measure the distance to the farthest fast radio burst. Same source.
4. "Cold eyes": a mid-infrared instrument needs a cooler (MIRI). Same source.

**Fun.** Ground control: unfolding the sunshield step by step, with many things that can go wrong. Pilot: the L2 insertion burn. Humor: "Please do not touch the mirror."

**Difficulty: medium.**

---

## 14. Asteroid Bowling (`asteroid_bowling`)
**Question.** If an asteroid were heading to Earth, could we nudge it? DART showed we can.

**Route.** Direct transfer to the Didymos pair, a kinetic impact at about 6.6 km/s; one-way.

**Twin.**
- DART (NASA, 2021): Falcon 9 Block 5 from Vandenberg, 24 Nov 2021; 610 kg (LICIACube 14 kg); 6.6 kW; DRACO camera; impact 26 Sep 2022; shortened Dimorphos's orbit by about 32-33 minutes; momentum boost factor about 3.6; cost US$330 M; Italian CubeSat LICIACube passed within 56.7 km. https://en.wikipedia.org/wiki/Double_Asteroid_Redirection_Test

**Extra objectives.**
1. "Witness": release a CubeSat. Same source.
2. "Ground-based watch": the telescope network. Same source.
3. "Autopilot": the camera steers the craft in the last hours. Same source (DRACO).
4. "Ejecta bonus": a bigger kick. Same source.

**Fun.** Pilot: the last minutes of guided aim, the best "stunt" in the game. Humor: bowling pins on the asteroid. 

**Difficulty: medium.**

---

## 15. Ocean Moon Clipper (`ocean_moon_clipper`)
**Question.** Is there an ocean under Europa's ice, and could it host life?

**Route.** Gravity assists around Mars and Earth, then Jupiter orbit insertion and about 49 flybys of Europa; no landing.

**Twins.**
- Europa Clipper (NASA, 2024): Falcon Heavy (expendable), 14 Oct 2024; 6,065 kg including 2,750 kg of propellant; 600 W; 9 instruments, about 82 kg combined; Mars assist 1 Mar 2025 at 884 km; Earth assist 3 Dec 2026; Jupiter arrival April 2030 (about 5.5 years, inference); 49 flybys at 25-2,700 km; cost about US$4.25 B (2020 estimate); the Falcon Heavy saved about US$2 B. https://en.wikipedia.org/wiki/Europa_Clipper
- Galileo (NASA, 1989): STS-34, Venus and Earth assists, Jupiter arrival 7 Dec 1995; 2,560 kg; its magnetometer found an induced field, evidence of an ocean (indirect). https://en.wikipedia.org/wiki/Galileo_(spacecraft) and https://pubmed.ncbi.nlm.nih.gov/9796812/

**Extra objectives.**
1. "Magnetic echo": a magnetometer measures Europa's induced field; NASA calls the evidence indirect. https://pubmed.ncbi.nlm.nih.gov/9796812/
2. "Ice radar": REASON, 9 and 60 MHz, to about 30 km. https://en.wikipedia.org/wiki/Europa_Clipper
3. "Taste the plume": a dust or mass spectrometer. Same source.
4. "Gravity check": tide measurement, per NASA. https://astrobiology.com/2000/08/25/more-evidence-of-an-ice-covered-ocean-on-europa/

**Fun.** Pilot: flying through Jupiter's radiation. Humor: "Please do not land on Europa."

**Difficulty: hard.**

---

## 16. Touch the Sun (`touch_the_sun`)
**Question.** What heats the Sun's outer atmosphere to millions of degrees, and what drives solar wind?

**Route.** Venus gravity assists (7) to a close solar orbit; no landing, no return.

**Twin.**
- Parker Solar Probe (NASA, 2018): Delta IV Heavy and Star 48BV; 685 kg; 343 W at perihelion; 24 orbits with 7 Venus flybys; closest approach 24 Dec 2024 at 6.16 million km at about 191 km/s; heat shield about 1,370 C outside, instruments near 29 C; entered the corona on 28 Apr 2021; about US$1.5 B. https://en.wikipedia.org/wiki/Parker_Solar_Probe

**Extra objectives.**
1. "Switchbacks": FIELDS magnetometer. Same source.
2. "Dust-free zone." Same source.
3. "Sungrazing comets": 20 found. Same source.
4. "Solar storm ride": plasma instrument. Same source.

**Fun.** Spectacle: the heat shield glowing. Humor: "Hot take."

**Difficulty: hard.** Needs planning, the opposite of most flights.

---

## Summary table

| id | Destination | Returns | Lands | Twin | Difficulty |
|---|---|---|---|---|---|
| volcano_watch | Earth SSO | no | no | Landsat 9 | easy |
| el_nino_watch | Earth 1,336 km | no | no | TOPEX/Poseidon, Sentinel-6 | easy |
| wildfire_watch | Earth SSO | no | no | Suomi NPP | easy |
| hurricane_hunter | Earth LEO 35 deg | no | no | CYGNSS | medium |
| ice_sentinel | Earth polar | no | no | ICESat-2 | medium |
| air_quality_stare | Earth GEO | no | no | TEMPO | medium |
| moon_south_pole | Moon | no | yes | Chandrayaan-3, LRO | hard |
| mars_rover | Mars | no | yes | Perseverance, Ingenuity | hard |
| mars_orbiter | Mars | no | no | MAVEN, MRO | medium |
| venus_explorer | Venus | no | no | Magellan, Vega | medium |
| grand_tour | Interstellar | no | no | Voyager 1, New Horizons | medium |
| sample_return | Asteroid | yes | no (touch) | OSIRIS-REx, Hayabusa2 | hard |
| telescope_l2 | Sun-Earth L2 | no | no | JWST | medium |
| asteroid_bowling | Asteroid | no | impact | DART | medium |
| ocean_moon_clipper | Jupiter | no | no | Europa Clipper, Galileo | hard |
| touch_the_sun | Sun | no | no | Parker | hard |

## Gaps
- Costs, data rates and ground networks missing for several twins (Landsat 9, Suomi NPP, ICESat-2, TEMPO, CYGNSS data rate, TOPEX power and cost, Voyager cost).
- Delta-v and C3 were found for none of the missions. A consistent delta-v table needs a cited source (or computation from `kb/domain/tradeoffs.md`).
- Light times to Mars, Venus and Jupiter weren't fetched.
- Volcano and wildfire have no NASA mission page read with numbers on the volcano/fire detection itself; needs ECOSTRESS or EMIT pages (the EMIT page returned 404).
- Wildfire alert latency is from secondary sources only.
- Landing mini-game data: Moon descent delta-v, Mars entry values.
- No missions yet from the invented or playful category beyond DART. Seeds to research: solar sail, asteroid mining demo, a "cheese run" to the Moon, a comet chaser.
- No discoveries of ICESat-2 (ice loss numbers) were found.
- An equatorial-only launch rule means polar and sun-synchronous missions need a plane-change cost model (inference).
