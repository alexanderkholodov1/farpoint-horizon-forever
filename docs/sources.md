# Sources

The bibliography of Farpoint HORIZON: every outside source of a number, formula, fact, dataset, model, image or sound
used in the game or its documents, once, with an ID. Wherever a value is used (a data field, a code comment, a
document), it cites the ID here: `[S3]`. The README and the game's credits are built from this list.

Format of an entry: **ID**, who published it, title, year, link, and what we use it for. A value we simplified says
so where it is used and cites what it simplifies. Research notes in `kb/` keep their own links; a value moves here
when the game or the pitch uses it.

New entries go at the end of their section with a short unique word as ID (`S-horizons`, `S-gibs-viirs`), never a
new number: branches built in parallel would collide on numbers. S1-S15 keep theirs. Git keeps both sides when two
branches add entries at the same place (`.gitattributes`).

## Challenge and NASA resources
- **S1** NASA Space Apps Challenge. *Space Mission Design Game* (challenge statement and resources). 2026.
  https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/ (copy in `spaceapps/challenge/`). The brief.
- **S2** NASA. *Design and Develop Science Missions*. 2025.
  https://www.nasa.gov/wp-content/uploads/2025/04/250323-design-and-develop-science-mission.pdf. The four mission
  segments (launch, space, ground, user) and the path from need to mission.
- **S3** Wessen, R. R., Borden, C., Ziemer, J., Kwok, J. (NASA Jet Propulsion Laboratory). *Space Mission Concept Development Using Concept Maturity
  Levels*. https://dataverse.jpl.nasa.gov/dataset.xhtml?persistentId=hdl:2014/44299. The game's stages follow CML 1-4.
- **S4** NASA CubeSat Launch Initiative. *CubeSat 101: Basic Concepts and Processes for First-Time CubeSat Developers*.
  https://www3.nasa.gov/sites/default/files/atoms/files/nasa_csli_cubesat_101_508.pdf. CubeSat platforms, rideshare,
  constraints.
- **S5** NASA Goddard Space Flight Center. *Mission Design Lab*.
  https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/mission-design-lab/. Inspiration for the design
  stations.
- **S6** NASA. *Build It Yourself: Webb Telescope* (game). https://science.nasa.gov/mission/webb/game-build-it-yourself/.
  Inspiration: incompatible options shown greyed with the reason; the real mission shown after the design.

## Spacecraft and physics
- **S7** Cal Poly CubeSat Program. *CubeSat Design Specification, Rev. 14*. 2022.
  https://www.nasa.gov/wp-content/uploads/2018/01/cubesatdesignspecificationrev14_12022-02-09.pdf. The 3U envelope
  (100 x 100 x 340.5 mm) and rails of the CubeSat model.
- **S8** NASA Space Science Data Coordinated Archive. *Earth Fact Sheet*.
  https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html. Earth's radius, gravitational parameter, solar
  constant.
- **S9** NASA Orbital Debris Program Office. *Frequently Asked Questions*. https://orbitaldebris.jsc.nasa.gov/faq/.
  Orbital lifetime against altitude.
- **S10** NASA Glenn Research Center. *Ideal Rocket Equation*.
  https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/ideal-rocket-equation/. Fuel needed for a change of
  velocity.

- **S-nasa-soa** NASA Small Spacecraft Systems Virtual Institute. *State-of-the-Art of Small Spacecraft Technology*.
  https://www.nasa.gov/smallsat-institute/sst-soa/. Typical mass, power, data rate, pointing and delta-v of small
  spacecraft platforms, solar arrays, batteries, radios, attitude control and propulsion (chapters on platforms,
  power, communications, guidance and navigation, in-space propulsion). The game's parts are rounded from it.
- **S-eoportal** European Space Agency. *eoPortal, Satellite Missions Directory*. https://www.eoportal.org/satellite-missions.
  Mass, power and data of the real instruments (Landsat 8 OLI and TIRS, Sentinel-2 MSI, Sentinel-1, TROPOMI, ICESat-2,
  TESS and others, listed in `kb/data/reference.json`, category instrument) that the game's instrument archetypes round.
- **S-gsfc-std-1000** NASA Goddard Space Flight Center. *GSFC-STD-1000 Rev I, Rules for the Design, Development,
  Verification and Operation of Flight Systems*, Rule 1.06 and Table 1.06-1.
  https://standards.nasa.gov/system/files/tmp/GSFC-STD-1000RevI_Approved_0.pdf. Mass margin above 10 % and power margin
  above 15 %, the margins of the Systems Engineer's goal.
- **S-ntrs-dod** NASA Glenn Research Center (NASA Technical Reports Server). *An Update on the Lithium-Ion Cell
  Low-Earth-Orbit Verification Test Program*, 2007. https://ntrs.nasa.gov/citations/20070022412. Checked 2026-11-15: the
  low-orbit cycling tests run at depths of discharge of 20 %, 30 % and 40 %. The game lets a battery give 60 % of its
  charge per eclipse: our game value, more generous than those tests, so small craft can work (a simplification).
- **S-wiki-geo** Wikipedia. *Geostationary orbit*. https://en.wikipedia.org/wiki/Geostationary_orbit. Altitude 35,786 km,
  period 1,436 min; to a ground observer it stays fixed in the sky.
- **S-wiki-dv** Wikipedia. *Delta-v budget*. https://en.wikipedia.org/wiki/Delta-v_budget. Delta-v from low Earth orbit to
  geostationary and lunar orbits.
- **S-wiki-iss** Wikipedia. *International Space Station*. https://en.wikipedia.org/wiki/International_Space_Station.
  Altitude near 400 km and inclination 51.6 degrees of the low orbit.
- **S-wiki-sso** Wikipedia. *Sun-synchronous orbit*. https://en.wikipedia.org/wiki/Sun-synchronous_orbit. Altitude near
  700 km and inclination near 98 degrees, same local solar time on every pass.
- **S-webb-orbit** NASA. *Webb's orbit*. https://science.nasa.gov/mission/webb/orbit/. The Sun-Earth L2 point, 1.5 million
  km from Earth, and why a telescope sits there.
## Launchers
- **S13** Rocket Lab. *Electron*. https://rocketlabcorp.com/launch/electron/. Figures as given in Wikipedia, *Rocket Lab
  Electron* (infobox, checked 2026-11-14), https://en.wikipedia.org/wiki/Rocket_Lab_Electron. Height 18 m, diameter
  1.2 m, nine first-stage engines: the light launcher model.
- **S14** SpaceX. *Falcon 9*. https://www.spacex.com/vehicles/falcon-9/. Figures as given in Wikipedia, *Falcon 9*
  (infobox and performance table, checked 2026-11-14), https://en.wikipedia.org/wiki/Falcon_9. Height about 70 m,
  diameter 3.7 m, fairing 5.2 m across and 13 m long, nine first-stage engines: the medium launcher model.
- **S15** SpaceX. *Falcon Heavy*. https://www.spacex.com/vehicles/falcon-heavy/. Figures as given in Wikipedia, *Falcon
  Heavy* (infobox, checked 2026-11-14), https://en.wikipedia.org/wiki/Falcon_Heavy. Height 70 m, width 12.2 m, three
  cores of 3.7 m: the heavy launcher model.

- **S-rideshare-price** New Space Economy. *SpaceX rideshare pricing as of February 2026*, 2026.
  https://newspaceeconomy.ca/2026/02/27/spacex-rideshare-pricing-as-of-february-2026-what-it-costs-whats-included-and-how-buyers-budget-a-mission/.
  As published in February 2026: $350,000 for up to 50 kg to sun-synchronous orbit, then $7,000 per kg more. The game
  uses 6,500 $/kg (our rounding, not in the source).

## Rocket parts (the builder)
- **S-merlin-model** hoahluke. *Merlin Engine* (3D model). Sketchfab, CC BY 4.0.
  https://sketchfab.com/3d-models/merlin-engine-b6725717165c4c0db0e4e2d744370a51. The sea-level engines of the large
  first stage (`assets/parts/engine_merlin_x9.glb`).
- **S-mvac-model** MartianDays. *Merlin 1D Vacuum* (3D model). Sketchfab, CC BY 4.0.
  https://sketchfab.com/3d-models/merlin-1d-vacuum-f20ebb6e857b405cbdc66568d48d2fcb. The large vacuum engine
  (`assets/parts/engine_merlin_vac.glb`).
- **S-nozzle-model** Zachary (corncob_127). *Rocket Nozzle Part* (3D model). Sketchfab, CC BY 4.0.
  https://sketchfab.com/3d-models/rocket-nozzle-part-e86374e66a4d462684b9826cedafe815. The small engines
  (`assets/parts/engine_small_x9.glb`, `engine_small_vac.glb`).
- **S-srb-model** NASA 3D Resources. *Space Shuttle Parts: Solid Rocket Booster* (3D model). Public domain (NASA media usage
  guidelines). https://github.com/nasa/NASA-3D-Resources/tree/master/3D%20Models/Space%20Shuttle%20Parts. The side
  boosters (`assets/parts/booster_srb.glb`); no insignia on its texture.
- **S-merlin** Wikipedia. *SpaceX Merlin* (infobox, checked 2026-11-14). https://en.wikipedia.org/wiki/SpaceX_Merlin.
  Merlin 1D: 845 kN at sea level, Isp 282 s (sea level) and 311 s (vacuum), 470 kg, 0.92 m; Merlin 1D Vacuum: 981 kN,
  348 s, 3.3 m nozzle.
- **S-rutherford** Wikipedia. *Rutherford (rocket engine)* (infobox, checked 2026-11-14).
  https://en.wikipedia.org/wiki/Rutherford_(rocket_engine). 25 kN at sea level, 26 kN in vacuum, Isp 311 s and 343 s,
  35 kg.
- **S-srb** Wikipedia. *Space Shuttle Solid Rocket Booster* (infobox and text, checked 2026-11-14).
  https://en.wikipedia.org/wiki/Space_Shuttle_Solid_Rocket_Booster. 45.46 m by 3.71 m, 91 t empty, 500 t of
  propellant, about 12 MN at liftoff, Isp 242 s (sea level) and 268 s (vacuum), 123 s burn.
- **S-delta-v** Wikipedia. *Delta-v budget* (checked 2026-11-14). https://en.wikipedia.org/wiki/Delta-v_budget. Earth to low
  orbit 9.3-10 km/s with losses; low orbit to the geostationary transfer orbit 2.3 km/s; translunar injection 3.20 km/s.
- [S13] and [S14] also give the stage lengths and masses the parts are cut from: Falcon 9 first stage 25.6 t empty and
  395.7 t of propellant, second stage 3.9 t and 92.67 t, fairing about 1.9 t; Electron 13.0 t at liftoff, stages of
  12.1 m and 2.4 m, fairing 44 kg.
- **S-wiki-fairing** Wikipedia. *Payload fairing* (checked 2026-11-15). https://en.wikipedia.org/wiki/Payload_fairing.
  "Once outside the atmosphere the fairing is jettisoned, exposing the payload to outer space"; "In some cases, the
  fairing is planned to separate after cutoff of the upper stage". The launch opens its fairing in two halves in orbit,
  after the engine cuts off.

## Real missions
- **S11** NASA. *Landsat 9*. https://science.nasa.gov/mission/landsat-9. Orbit and coverage of an Earth-imaging twin.
- **S12** European Space Agency, Copernicus. *Sentinel-2 mission*. https://sentiwiki.copernicus.eu/web/s2-mission.
  Orbit and coverage of an Earth-imaging twin.

- **S-sentinel5p** European Space Agency, eoPortal. *Copernicus Sentinel-5P*.
  https://www.eoportal.org/satellite-missions/copernicus-sentinel-5p. Measures gases such as SO2 (volcano scenario).
- **S-aster** Wikipedia. *Advanced Spaceborne Thermal Emission and Reflection Radiometer*.
  https://en.wikipedia.org/wiki/Advanced_Spaceborne_Thermal_Emission_and_Reflection_Radiometer. Thermal images (volcano scenario).
- **S-sentinel6** Wikipedia. *Sentinel-6 Michael Freilich*. https://en.wikipedia.org/wiki/Sentinel-6_Michael_Freilich.
  Sea level height and the Jason series it continues (ocean scenario).
- **S-smap** Wikipedia. *Soil Moisture Active Passive*. https://en.wikipedia.org/wiki/Soil_Moisture_Active_Passive.
  Microwave radiometer of the ocean scenario.
- **S-lro** NASA. *Lunar Reconnaissance Orbiter*. https://science.nasa.gov/mission/lro/. Real twin of the lunar scenario.
- **S-chandrayaan2** Wikipedia. *Chandrayaan-2*. https://en.wikipedia.org/wiki/Chandrayaan-2. Real twin of the lunar scenario.
- **S-hubble** ESA and NASA. *Hubble Space Telescope fact sheet*. https://esahubble.org/about/general/fact_sheet/. Low orbit
  telescope of the astronomy scenario.
- **S-pegaso** Wikipedia. *NEE-01 Pegaso*. https://en.wikipedia.org/wiki/NEE-01_Pegaso. The first Ecuadorian satellite, a
  1U CubeSat launched in 2013 (shown in the report of a CubeSat mission).
- **S-capstone** Wikipedia. *CAPSTONE*. https://en.wikipedia.org/wiki/CAPSTONE. A 12U CubeSat in lunar orbit, 2022 (shown in
  the report of a lunar CubeSat mission).
- **S-apollo13-nasa** NASA. *Apollo 13 Mission Details*. https://www.nasa.gov/missions/apollo/apollo-13-mission-details/.
  Launched April 11, 1970; oxygen tank no. 2 exploded on April 13 (Houston time), 200,000 miles from Earth; the crew
  used the lunar module as a lifeboat; the command module's square CO2 canisters did not fit the lunar module's round
  openings, and Mission Control devised an adapter of plastic bags, cardboard and tape; splashdown April 17, 1970. The
  facts the cuyes cite in chapter 1 (data/story/apollo13.json). Also from the page: the planned landing in the Fra
  Mauro area, Swigert's words "Houston, we've had a problem here.", the circle around the Moon without landing, the
  cold (38 degrees Fahrenheit, condensation on the walls), noncritical systems off and power use cut to 1/5, the
  five-minute burn near the Moon to speed up the return, launch at 1:13 p.m. CST, and splashdown in the Pacific near
  Samoa with USS Iwo Jima as recovery ship.
- **S-apollo13-mailbox** NASA. Apollo 13 photograph *AS13-62-9004*: in the lunar module, hoses and the canister of the
  "mail box", the crew's carbon dioxide adapter (public domain). Full-size file in the Apollo Lunar Surface Journal
  (NASA History Office, hosted at apollojournals.org): https://apollojournals.org/alsj/a13/AS13-62-9004.jpg. Checked
  2026-11-15 (this frame is not in the NASA Image and Video Library; frame AS13-62-8929 there shows the same mail box
  from the front: https://images.nasa.gov/details/as13-62-8929). The real adapter, shown when mission 1's adapter game
  is won (assets/photos/apollo13/as13-62-9004.jpg). The same mission page [S-apollo13-nasa] gives the game's other
  facts: the CO2 warning after a day and a half in the lunar module, and the lunar module made for two men for two
  days, asked to keep three for about four.
- **S-hubble-sm1** NASA Science. *Hubble Servicing Mission 1*.
  https://science.nasa.gov/mission/hubble/observatory/missions-to-hubble/servicing-mission-1/. Endeavour launched
  Dec 2, 1993; the mirror's flaw (spherical aberration: many foci instead of one, fuzzy first images); five
  back-to-back spacewalks totaling 35 hours and 28 minutes; the parts installed (solar arrays, their drive electronics,
  magnetometers, co-processors, two Rate Sensor Units, two gyroscope control units, the GHRS redundancy kit, WFPC2,
  COSTAR). Mission 2 (data/missions/sts61.json, data/story/sts61.json).
- **S-sts61-nasa** NASA. *STS-61*. https://www.nasa.gov/mission/sts-61/. Launch Dec 2, 1993, landing Dec 13, 1993
  (10 days, 19 hours, 58 minutes); Hubble grappled and stood upright in the bay on flight day three by Claude
  Nicollier with the robot arm; each spacewalk's crew, work and length (7 h 54, 6 h 35, 6 h 48, 6 h 50, 7 h 21).
- **S-m100-pia22913** NASA. *M100 Through 3 Cameras*, PIA22913 (NASA Image and Video Library, public domain; credit as the record prints it: "NASA, ESA, STScI and Judy Schmidt"; the record's centre is JPL).
  https://images.nasa.gov/details/PIA22913. M100 with WFPC1 in 1993, blurry from the mirror's flaw, and with WFPC2
  after STS-61, "snapped into sharp focus". Cropped for mission 2's first image
  (assets/photos/sts61/m100_wfpc1_1993.jpg, m100_wfpc2_1993.jpg).
- **S-nasa-9408670** NASA Marshall Space Flight Center. *History of Hubble Space Telescope (HST)*, image 9408670.
  https://images.nasa.gov/details/9408670. Hubble launched by Discovery (STS-31) in April 1990; two months later a
  2-micron spherical aberration found in the primary mirror, one-fiftieth of the width of a human hair.
- **S-mpf-nasa** NASA Science. *Mars Pathfinder*. https://science.nasa.gov/mission/mars-pathfinder/. Launched Dec 4,
  1996; landed July 4, 1997 at Ares Vallis, an ancient flood plain; airbags inflated about 100 m up; bounced about 15
  times, as high as 15 m, coming to rest 2.5 minutes later about 1 km away; Sojourner rolled down the rear ramp,
  tilted 20 degrees, on sol 2; 30 cm tall, 10.6 kg; the last data on Sept 27, 1997. Mission 3.
- **S-mpf-nssdc** NASA Space Science Data Coordinated Archive. *Mars Pathfinder*, 1996-068A.
  https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1996-068A. Entry at about 7300 m/s; the 12.5 m
  parachute, about 70 m/s; the 20 m Kevlar bridle; the radar's ground at about 1.6 km; four airbags, a 5.2 m ball,
  about 10 s before landing; the three solid rockets at 98 m; the bridle cut 21.5 m up; impact at 18 m/s; about 12 m
  up, then at least 15 more bounces; Ares Vallis, 19.33 N 33.55 W. Mission 3's descent and bounces.
- **S-mpf-jpl** NASA Jet Propulsion Laboratory. *Mars Pathfinder / Sojourner Rover*.
  https://www.jpl.nasa.gov/missions/mars-pathfinder-sojourner-rover/. An airbag landing system; Sojourner spent 83
  days of a planned seven-day mission, the first wheeled vehicle used on another planet.
- **S-mpf-pia00621** NASA/JPL. *Color Mosaic of Rover & Terrain*, PIA00621 (public domain).
  https://images.nasa.gov/details/PIA00621. Sojourner latched to its petal on sol 1, the airbags, Ares Vallis.
  Shown at the end of mission 3 (cropped); its colours guide the set's sky and ground.
- **S-mpf-pia00633** NASA/JPL. *Rover Tracks*, PIA00633 (public domain). https://images.nasa.gov/details/PIA00633.
  Sojourner's tracks on sol 3, from its own camera. Shown at the end of mission 3.

- **S-lcross-nasa** NASA Science. *LCROSS*. https://science.nasa.gov/mission/lcross/. Launched June 18, 2009,
  21:32 UT, with the Lunar Reconnaissance Orbiter on an Atlas V 401; the Centaur hit Cabeus at 11:31 UT; LCROSS flew
  through the plume and struck four minutes later, at 11:36 UT, at 9,000 km/h; its instruments: cameras (visible,
  near and mid infrared), spectrometers and a photometer; on Nov 13, 2009 NASA announced the data showed water near the
  Moon's south pole. Mission 4.
- **S-lcross-nssdc** NASA Space Science Data Coordinated Archive. *LCROSS Shepherding Spacecraft*, 2009-031B.
  https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2009-031B. The 2000 kg Centaur upper stage; the
  shepherding craft separated at 01:50 UT on Oct 9, 2009 and followed a few minutes behind; the Centaur hit at
  11:31:19.5 UT at about 2.5 km/s; the shepherding craft gathered data for about four minutes and hit at 11:35:36.1
  UT. Mission 4's aim and its four minutes.
- **S-cabeus-gazetteer** IAU / USGS Astrogeology Science Center (NASA-supported). *Gazetteer of Planetary
  Nomenclature*, Moon, Cabeus. https://planetarynames.wr.usgs.gov/SearchResults?Target=16_Moon&Feature%20Name=Cabeus.
  Centre 85.33 S, 42.13 W (planetographic, +East), diameter 100.58 km. Where mission 4 draws Cabeus on NASA's LROC
  mosaic (S-lroc-wac).

- **S-dart-nasa** NASA Science. *DART*. https://science.nasa.gov/mission/dart/. Launched Nov 24, 2021 (1:21 a.m.
  EST) on a Falcon 9 from Vandenberg; hit Dimorphos, 160 m across, the moon of the 780 m Didymos, on Sept 26, 2022.
  Mission 5.
- **S-dart-nasa-period** NASA. *NASA Confirms DART Mission Impact Changed Asteroid's Motion in Space* (release 22-105,
  Oct 11, 2022). https://www.nasa.gov/news-release/nasa-confirms-dart-mission-impact-changed-asteroids-motion-in-space/.
  Dimorphos's orbit around Didymos from 11 h 55 min to 11 h 23 min, 32 minutes shorter, plus or minus about 2; the
  minimum for success was 73 s; LICIACube from the Italian Space Agency. Mission 5's measurement.
- **S-dart-nssdc** NASA Space Science Data Coordinated Archive. *DART*, 2021-110A.
  https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2021-110A. Impact at about 6.58 km/s, 23:14 UT Earth
  received time, about 11.2 million km from Earth; impact mass 560 kg; DRACO, a 20.8 cm telescope with a 0.29-degree
  view and about 0.5 arcsec per pixel; DRACO and SMARTNav targeted the asteroid in the last 4 hours; the final images,
  about 2 s before impact, about 3 cm per pixel; LICIACube released on Sept 11, following about 3 minutes behind.
  Mission 5's approach and last picture.

- **S-artemis-nasa** NASA. *Artemis I*. https://www.nasa.gov/mission/artemis-i/. Launched from Launch Pad 39B at
  1:47 a.m. EST on Nov 16, 2022; Orion traveled 268,563 miles from Earth and 43,471 miles beyond the far side of the
  Moon; splashed down off the coast of San Diego at 12:40 p.m. EST on Dec 11, 2022, after 25 days, 10 hours, 53
  minutes. Mission 6.
- **S-artemis-timeline** NASA. *Artemis I Mission Timeline*. https://www.nasa.gov/reference/artemis-i-mission-timeline/.
  Solid rocket booster separation at 2 min 12 s; core stage separation at 8 min 03 s; the outbound powered flyby about
  81 miles above the Moon, from 2,128 to 5,102 mph; re-entry speed 24,581 mph (Mach 32); 1.4 million miles in all.
  Mission 6's launch, flyby and re-entry.
- **S-artemis-campos** NASA. *Public Names Moonikin Flying Around Moon on NASA's Artemis I Mission* (June 29, 2021).
  https://www.nasa.gov/news-release/public-names-moonikin-flying-around-moon-on-nasas-artemis-i-mission/. 'Commander
  Moonikin Campos', named for Arturo Campos, a key player in bringing Apollo 13 safely back to Earth; in the commander's
  seat, in an Orion Crew Survival System suit. Chapter 6.
- **S-artemis-art672** NASA. *Artemis I Flight Day 13: Orion, Earth, and Moon*, art001e000672 (Nov 28, 2022), NASA Image
  and Video Library, https://images.nasa.gov/details/art001e000672 (public domain). Orion at its farthest, 268,563 miles
  from Earth. Our processing: cropped to the Moon and the Earth (the spacecraft and its markings left out). In
  `assets/photos/artemis1/`.
- **S-dart-penultimate** NASA/Johns Hopkins APL. *DART's Penultimate View*, 2022.
  https://www.nasa.gov/image-article/darts-penultimate-view/ (checked 2026-11-16): "the last complete image of the
  asteroid Dimorphos, as seen by our Double Asteroid Redirection Test (DART) two seconds before impact", a 100-foot-wide
  patch taken by DRACO; image credit NASA/Johns Hopkins APL. Downscaled to 1024 px for the web build. The picture of
  chapter 5's card in the chapter select (issue 68).
- **S-dart-pia25329** NASA/Johns Hopkins APL. *NASA's DART at the Didymos System*, PIA25329 (illustration, Sept. 22,
  2022), NASA Image and Video Library, https://images.nasa.gov/details/PIA25329 (checked 2026-11-15 through the
  library's API: "This illustration depicts NASA's Double Asteroid Redirection Test (DART) spacecraft prior to impact at
  the Didymos binary asteroid system"). An illustration. It was the picture of chapter 5's card until DART's own camera image replaced it
  (S-dart-penultimate, issue 68).
- **S-moon-kit** NASA Goddard Space Flight Center, Scientific Visualization Studio. *CGI Moon Kit* (2019).
  https://svs.gsfc.nasa.gov/4720. LRO LROC WAC colour map (`lroc_color_poles_4k.tif`, colour enhanced from LROC and Kaguya) and
  LOLA elevation (`ldem_16.tif`, 16 pixels per degree); the game's Moon colour and relief (`assets/textures/moon_color.jpg`, `moon_normal.jpg`, made by
  `assets/source/planet_textures.py`). Credit: "NASA/GSFC/Scientific Visualization Studio, LRO". NASA media guidelines.
- **S-gibs-earth** NASA GIBS WMS (see S-gibs), whole globe at 4096 x 2048: `BlueMarble_NextGeneration` and
  `BlueMarble_ShadedRelief` (August 2004, NASA Earth Observatory, Reto Stockli, MODIS), `VIIRS_Black_Marble` (2016,
  Suomi NPP VIIRS) and `VIIRS_SNPP_CorrectedReflectance_TrueColor` of 2024-08-31 (the day of the volcano photos). The
  Earth by day, its relief, its city lights and its clouds (`assets/textures/earth_*.jpg`, `assets/source/planet_textures.py`).
  Replaces the former Earth texture (earth_albedo.jpg), whose source was unknown. Credit: "NASA Earth Observatory / NASA GIBS".
- **S-gibs-region** NASA GIBS WMS (see S-gibs), the same three layers (Blue Marble, shaded relief, VIIRS of 2024-08-31)
  over 92-68 W, 12 N-12 S at 2048 x 2048 (about 1.3 km per pixel): the sharper Earth under the climb from Ecuador
  (`assets/textures/earth_region_*.jpg`, `assets/source/planet_textures.py` `region()`).
- **S-terrain-tiles** Mapzen/Tilezen. *Terrain Tiles* on the Registry of Open Data on AWS,
  https://registry.opendata.aws/terrain-tiles/ (terrarium encoding), which in the Andes is NASA SRTM elevation (NASA/
  USGS, public domain); attribution as the registry asks. Sixteen zoom-11 tiles around Cotopaxi; the launch site's
  relief (`assets/textures/terrain_cotopaxi.png`, `assets/source/terrain_cotopaxi.py`). Our check: the summit comes out at
  5,876 m against the published 5,897 m [S-cotopaxi-height].
- **S-cotopaxi-height** Wikipedia. *Cotopaxi* (infobox and text). https://en.wikipedia.org/wiki/Cotopaxi. Elevation 5,897 m
  (19,347 ft), the summit used in our relief check [S-terrain-tiles].
- **S-cotopaxi-belts** Our simplification of the altitude belts painted on that relief: valley farmland, paramo grass
  from about 3,500 m, volcanic sand from about 4,500 m, glacier from about 4,850 m (`assets/shaders/terrain.gdshader`). To be
  checked against a published source; the glacier line of Cotopaxi is near 4,800-5,000 m in recent surveys.
- The launch site (`assets/source/launch_site.py`) and the craft components (`assets/source/craft_kit.py`) are our own
  models after photographs of the East Coast pads and of real spacecraft hardware; their sizes are our estimates.

## Software, fonts and services (the engine, the build, the data scripts and the web)
Licences were read on the owners' pages on 2026-11-16 (the link in each entry).
- **S-tool-godot** Godot Engine 4.7, the game engine and its web export template. MIT License.
  https://godotengine.org/license/. Used by every scene and script of the game (`project.godot`, `export_presets.cfg`).
- **S-tool-firebase** Google Firebase: Hosting (the live web game and every pull request preview) and Realtime Database
  (the crew's room, `web/room_bridge.js`). Terms: https://firebase.google.com/terms/.
- **S-tool-firebase-js** Firebase JavaScript SDK 10.14.1 (pinned in `web/build_head.py`), Apache License 2.0.
  https://github.com/firebase/firebase-js-sdk/blob/master/LICENSE. Loaded by `web/build_head.py` and used by `web/room_bridge.js`.
- **S-tool-blender** Blender, GNU GPL 2 or later (SPDX list: https://github.com/blender/blender/blob/main/doc/license/SPDX-license-identifiers.txt;
  project page https://www.blender.org). Builds the 3D models of `assets/source/*.py` (its Python API: bpy, bmesh, mathutils).
- **S-tool-python** Python, Python Software Foundation License. https://www.python.org/psf/license/. Runs every script in `tools/` and `assets/source/`.
- **S-tool-numpy** NumPy, BSD 3-Clause (https://github.com/numpy/numpy/blob/main/LICENSE.txt). Computes the music
  (`tools/content/audio/compose_music.py`) and the terrain and planet textures (`assets/source/planet_textures.py`,
  `assets/source/terrain_cotopaxi.py`).
- **S-tool-pillow** Pillow, the Pillow license (HPND, https://github.com/python-pillow/Pillow/blob/main/LICENSE). Image
  processing for the decks' backgrounds, the NASA photos' cropping and the Earth and Cotopaxi textures
  (`assets/source/planet_textures.py`, `assets/source/terrain_cotopaxi.py`).
- **S-tool-ffmpeg** FFmpeg, LGPL 2.1 or later (GPL parts not used; https://ffmpeg.org/legal.html). Encodes the music
  (`audio/music_horizon.ogg`) and the 30-second demo (`tools/content/video/make_trailer.py`).
- **S-tool-pptx** python-pptx, MIT License (https://github.com/scanny/python-pptx/blob/master/LICENSE). Built the decks
  (by scripts no longer kept in the repository).
- **S-tool-lxml** lxml, BSD License (https://github.com/lxml/lxml/blob/master/LICENSE.txt). XML editing of
  the deck (by a script no longer kept in the repository).
- **S-font-inter** Inter typeface, Rasmus Andersson, SIL Open Font License 1.1 (https://github.com/rsms/inter/blob/master/LICENSE.txt;
  project page https://rsms.me/inter/). The game's text font: `assets/fonts/Inter-Regular.otf`, `Inter-SemiBold.otf`,
  `InterDisplay-Bold.otf`.
- **S-model-sketchfab** The four outside engine and booster models in `assets/source/vendor/` are the Sketchfab models
  cited above (S-merlin-model, S-mvac-model, S-nozzle-model) and NASA's booster (S-srb-model), used as they are; the
  Sketchfab licence is CC BY 4.0 (credit each author as above).
- Our own, not from outside: the music (`tools/content/audio/compose_music.py`, no samples), the sounds (synthesised in
  the game's code), the launchers, CubeSat, launch site and craft models (`assets/source/`), the cuy crew (`assets/source/crew_cuy.py`,
  Blender; Rumi's body from TRELLIS, see the README's "Use of AI"). The only outside images are the NASA and NASA-partner
  pictures listed above.

## NASA data used by the mission photos and the route numbers (issue 19; pipeline in `tools/content/data/`)
All checked 2026-11-14. NASA media are used under the NASA Media Usage Guidelines
(https://www.nasa.gov/nasa-brand-center/images-and-media/): no NASA logo or insignia, no implied endorsement.
- **S-gibs** NASA ESDIS, Global Imagery Browse Services (GIBS), NASA Worldview, WMS
  https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi. Tested for the volcano photos (VIIRS 250 m) and replaced by
  S-eo for being soft; kept as the source of the Earth texture recommended in `kb/research/nasa-data.md`
  (layer `BlueMarble_NextGeneration`). Credit: "NASA GIBS / Worldview".
- **S-eo** NASA Earth Observatory (science.nasa.gov/earth/earth-observatory), image pages with their full-size files:
  Sangay (Landsat 8 OLI, 5 Nov 2022, https://science.nasa.gov/earth/earth-observatory/a-line-of-ash-from-sangay-150650/),
  Cotopaxi (Landsat 8 OLI, 15 Sep 2015, https://science.nasa.gov/earth/earth-observatory/cotopaxi-volcano-ecuador-86618/),
  Tungurahua (EO-1 ALI natural and short-wave infrared, 1 Jan 2011,
  https://science.nasa.gov/earth/earth-observatory/ongoing-eruption-of-tungurahua-ecuador-48337/). In
  `assets/photos/volcano_watch/`. Credits as the pages print them: "NASA Earth Observatory images by Lauren
  Dauphin / Jesse Allen, using Landsat data from the U.S. Geological Survey" (Landsat data are public domain, USGS);
  "NASA Earth Observatory image created by Jesse Allen, using EO-1 ALI data provided courtesy of the NASA EO-1 team and
  the U.S. Geological Survey". Our processing: cropped to the volcano, resized.
- **S-nasa-science** NASA Science (science.nasa.gov) resource and image pages, for the Moon: Shackleton crater rim,
  credit "NASA/GSFC/Arizona State University" (https://science.nasa.gov/resource/shackleton-craters-illuminated-rim-shadowed-interior/);
  Shackleton floor seen by ShadowCam, a NASA instrument on the Korean KPLO orbiter, credit as printed "NASA, ShadowCam,
  Korea Aerospace Research Institute, Arizona State University" (https://science.nasa.gov/image-article/apod-2023-may-5-shackleton-from-shadowcam/);
  the Korean partner is named in the credit; no separate terms found. In `assets/photos/moon_south_pole/`.
- **S-lroc-wac** NASA/GSFC/Arizona State University, Lunar Reconnaissance Orbiter Camera (LROC) Wide Angle Camera global
  mosaic (100 m), served by NASA Moon Trek, https://trek.nasa.gov/tiles/Moon/EQ/LRO_WAC_Mosaic_Global_303ppd_v02/1.0.0/WMTSCapabilities.xml.
  Photos in `assets/photos/moon_south_pole/`. Credit: "NASA/GSFC/Arizona State University, LRO". Our processing:
  tiles joined and re-projected to a view from above the south pole.
- **S-nasa-images** NASA Image and Video Library, https://images.nasa.gov (API https://images-api.nasa.gov), records
  PIA00022 (Jupiter, Voyager 1), PIA01374 (Saturn, Voyager 1), PIA18182 (Uranus, Voyager 2), PIA00049 (Neptune,
  Voyager 2); catalogued by NASA/JPL Photojournal. Of these, the game keeps Neptune, the picture of Eye on the Universe (`assets/photos/telescope/`); the Grand Tour mission was dropped (issue #10). Credit: "NASA/JPL-Caltech".
  Our processing: resized. Also the ASTER pictures in `assets/photos/volcano_watch/`: PIA23914 (Sangay, night
  thermal infrared, 11 Jun 2020, credit "NASA/METI/AIST/Japan Space Systems, and U.S./Japan ASTER Science Team") and
  PIA15151 (Cotopaxi, false colour, 22 Aug 2015, credit "NASA/GSFC/METI/ERSDAC/JAROS, and U.S./Japan ASTER Science
  Team"); ASTER is a joint Japanese (METI) and NASA instrument on Terra, hence the credit.
- **S-horizons** NASA/JPL Solar System Dynamics. *Horizons System API*. https://ssd-api.jpl.nasa.gov/doc/horizons.html
  (endpoint https://ssd.jpl.nasa.gov/api/horizons.api). The Moon around the Earth for a month from 2026-11-15, in
  `data/nasa/horizons_moon.json` (the planets' orbits, fetched for the dropped Grand Tour, were removed). Credit: "NASA/JPL Horizons".
- **S-nssdc-planets** NASA Space Science Data Coordinated Archive. *Planetary Fact Sheets*.
  https://nssdc.gsfc.nasa.gov/planetary/factsheet/ . Mass, radius, gravity, escape velocity, orbit radius and day length
  of the planets and the Moon, in `data/nasa/nssdc_factsheets.json`. Credit: "NASA NSSDC Planetary Fact Sheets".

## The pilot's flight and the Moon's south pole (issue 8)
All checked 2026-11-14.
- **S-lola** Smith, D. E., et al. (NASA Goddard Space Flight Center), Lunar Orbiter Laser Altimeter (LOLA) on the Lunar
  Reconnaissance Orbiter. *LRO-L-LOLA-4-GDR-V1.0, product LDEM_875S_20M* (south polar elevation map, 20 m per pixel,
  version 2.0, 2017), NASA Planetary Data System, Geosciences Node.
  https://pds-geosciences.wustl.edu/lro/lro-l-lola-3-rdr-v1/lrolol_1xxx/data/lola_gdr/polar/img/ldem_875s_20m.lbl.
  The ground of the landing: a 12 km square around the south pole and Shackleton's rim, averaged to 60 m, in
  `data/nasa/lola_south_pole.json` (made by `tools/content/data/fetch_lola_terrain.py`). Credit: "NASA/GSFC LOLA team, NASA PDS".
- **S-svs-south-pole** NASA Scientific Visualization Studio. *Shadows near the Moon's South Pole*, 2021.
  https://svs.gsfc.nasa.gov/4893. At the poles the Sun is never more than 1.5 degrees above or below the horizon;
  places it never reaches are permanently shadowed and trap water ice.
- **S-chandrayaan3** Wikipedia. *Chandrayaan-3* (infobox and text). https://en.wikipedia.org/wiki/Chandrayaan-3.
  Launched 14 July 2023 on LVM3 M4, landed 23 August 2023 at 69.373 S; lander Vikram 1,726 kg; the hop of about 40 cm
  (3 September 2023, as cited there; ISRO announced it on 4 September). Real twin of the south pole mission.
- **S-im1** Wikipedia. *IM-1* (text). https://en.wikipedia.org/wiki/IM-1. Intuitive Machines' Odysseus, launched
  15 February 2024 on Falcon 9, landed 22 February 2024 at Malapert A (80.13 S); landed faster than planned on a
  12-degree slope, broke a leg, tipped onto its side and kept returning data until the lunar night, about a week.
  Real twin of the south pole mission; the game's tipping slope.
- **S-apollo11** Wikipedia. *Apollo 11* (mission timeline). https://en.wikipedia.org/wiki/Apollo_11. Launched
  16 July 1969 13:32 UTC, entered lunar orbit 19 July 17:21 UTC (about 76 hours), landed 20 July; the 1201 and 1202
  alarms began about five minutes into the descent burn. The trip time of the coast to the Moon.
- **S-alsj-1202** Adler, P. *Apollo 11 Program Alarms*, Apollo Lunar Surface Journal (NASA), 1998.
  https://www.nasa.gov/wp-content/uploads/static/history/alsj/a11/a11.1201-pa.html. What the 1202 alarm meant (no free
  core sets for new jobs), why the computer kept steering after its restarts, and why Mission Control could call go.
  The descent alarm the pilot and ground control face.
- **S-apollo-gear** Rogers, W. F. (NASA Johnson Space Center). *Apollo Lunar Module Landing Gear*, 1972. NASA Technical
  Reports Server 19730010151, https://ntrs.nasa.gov/citations/19730010151. A landing is decided mainly by the touchdown
  speed and the slope of the ground under the legs; the game's touchdown bands use those two (their values are ours).
- **S-afj11-tli** Woods, W. D., et al. *Apollo 11, Day 1 part 2: Earth Orbit and Translunar Injection*, Apollo Flight
  Journal (NASA History Office, hosted at apollojournals.org).
  https://apollojournals.org/afj/ap11fj/02earth-orbit-tli.html. Checked 2026-11-15. "Duration of the burn expected to
  be 5 minutes, 47 seconds"; inertial velocity at cutoff 35,575 ft/s (10,843 m/s); "an orbital weight of the combined
  vehicles of 297,914 pounds" in the parking orbit. The departure stage of the trip (`data/engines.json`).
- **S-afj11-loi** Woods, W. D., et al. *Apollo 11, Day 4 part 2: Entering Lunar Orbit*, Apollo Flight Journal.
  https://apollojournals.org/afj/ap11fj/12day4-loi1.html. Checked 2026-11-15. LOI-1: "duration 6 minutes, 2 seconds",
  delta-v 2,917 ft/s (889 m/s), weight before the burn 96,012 lb (43,550 kg), resulting orbit about 113 x 313 km. The
  craft's engine of the trip (`data/engines.json`) and `tests/ci/flight.gd`.
- **S-j2** Wikipedia. *Rocketdyne J-2* (infobox). https://en.wikipedia.org/wiki/Rocketdyne_J-2. Checked 2026-11-15.
  Vacuum thrust 1,033.1 kN (232,250 lbf), vacuum specific impulse 421 s. The departure stage's Isp.
- **S-apollo-csm** Wikipedia. *Apollo command and service module* (Service Propulsion System).
  https://en.wikipedia.org/wiki/Apollo_command_and_service_module. Checked 2026-11-15. SPS thrust 91.19 kN
  (20,500 lbf), specific impulse 314.5 s. The craft's engine of the trip.

## Ground control: the Deep Space Network and the in-flight alarms (issue 9)
All checked 2026-11-14; the research behind them is `kb/research/in-flight-failures.md`.
- **S-dsn-facts** NASA Jet Propulsion Laboratory. *Eight Essential Facts about NASA's Deep Space Network*.
  https://www.jpl.nasa.gov/news/eight-essential-facts-about-nasas-deep-space-network/. Three complexes, Goldstone
  (California), near Madrid (Spain) and near Canberra (Australia), about 120 degrees apart, so as the Earth turns one
  of them always sees a far craft; each has a 70 m dish.
- **S-dsn-sites** Wikipedia. *NASA Deep Space Network* (coordinates of the complexes and the bands). 
  https://en.wikipedia.org/wiki/NASA_Deep_Space_Network. Goldstone 35.42667 N 116.89 W, Madrid 40.43139 N 4.24806 W,
  Canberra 35.40139 S 148.98167 E; S, X and Ka bands (2, 8 and 32 GHz). The stations ground control picks from.
- **S-usno-gast** U.S. Naval Observatory. *Computing Greenwich Apparent Sidereal Time*. https://aa.usno.navy.mil/faq/GAST.
  Not readable on 2026-11-16 (the connection was reset from both networks), so the formula is not re-checked against the page. The constants
  are the mean sidereal time at 2000 January 1 12h UT (18h 41m 50.55s = 18.6973746 h) and the sidereal rate (1.00273790935 x 24 h =
  24.0657098 h per day), which agree with the Earth's rotation; open the page in a browser to confirm before pasting.
  GMST = 18.697374558 + 24.06570982441908 D hours (D: days since 2000 January 1, 12h UT); the tilt of the Earth's axis,
  about 23.44 degrees. Which way each dish faces at each moment of the flight.
- **S-codata-c** NIST. *CODATA value: speed of light in vacuum*. https://physics.nist.gov/cgi-bin/cuu/Value?c.
  299 792 458 m/s, exact. The light time to the craft and its Doppler shift.
- **S-jpl-lighttime** NASA Science. *Basics of Space Flight, Chapter 1-1: The Realm of the Sun*.
  https://science.nasa.gov/learn/basics-of-space-flight/chapter1-1/. Checked 2026-11-16: this page is the course's
  solar-system chapter and does not print a light-time table (the older JPL table at www2.jpl.nasa.gov/basics no longer
  opens). The light time to the Moon in the game is our computation: 384,400 km (its mean distance, S-nssdc-planets' Moon
  data) divided by the speed of light [S-codata-c], about 1.28 s.
- **S-descanso-bands** Taylor, J. (ed.), *Deep Space Communications*, DESCANSO series vol. 4, ch. 10, JPL.
  https://descanso.jpl.nasa.gov/monograph/series4/Mono4_Ch10.pdf. S, X and Ka are the deep-space bands (this chapter). The
  8.4 GHz tone of the X-band downlink in "Find the carrier" is our own figure; this chapter does not print it.
- **S-jpl-voyager2** NASA Jet Propulsion Laboratory. *NASA Mission Update: Voyager 2 Communications Pause*, 2023.
  https://www.jpl.nasa.gov/news/nasa-mission-update-voyager-2-communications-pause/. The Deep Space Network heard
  Voyager 2's carrier when it was too faint to carry data: the idea of "Find the carrier".
- **S-soho-recovery** NASA/ESA. *SOHO Mission Interruption and Recovery*. https://soho.nascom.nasa.gov/about/Recovery/.
  The page records the loss of contact on 25 June 1998 and the recovery updates from 24 June to 20 November 1998;
  the game's "Find the carrier" follows that story (the date of the first detection is not on the page).
- **S-usno-sun** U.S. Naval Observatory. *Approximate Solar Coordinates*. https://aa.usno.navy.mil/faq/sun_approx
  (read through the Internet Archive on 2026-11-15; the site did not answer). g = 357.529 + 0.98560028 D,
  L = q + 1.915 sin g + 0.020 sin 2g, about 1 arcminute within two centuries of 2000. Where the Sun is, so where L2 is
  (opposite it) for "Hand it over" (issue 63).
- **S-afj12-launch** Apollo Flight Journal. *Apollo 12: Launch and Reaching Earth Orbit*.
  https://apollojournals.org/afj/ap12fj/01launch_to_earth_orbit.html. Checked 2026-11-15: lightning at 36.5 s knocked out
  the Signal Conditioning Electronics' power supply, so Mission Control received garbled data; John Aaron recognised
  the pattern from a pad test and CapCom Carr called "Try SCE to Auxiliary" at 000:01:36. A case of "Read the squiggles".
- **S-jpl-voyager1-fds** NASA Jet Propulsion Laboratory. *NASA's Voyager 1 Resumes Sending Engineering Updates to Earth*,
  2024. https://www.jpl.nasa.gov/news/nasas-voyager-1-resumes-sending-engineering-updates-to-earth/. Checked 2026-11-15:
  unreadable data from 14 November 2023; one failed chip of the flight data subsystem's memory; the code split and
  moved elsewhere, sent 18 April 2024, health data back 20 April. A case of "Read the squiggles".
- **S-kepler-k2** NASA. *Kepler's Second Light: How K2 Will Work*.
  https://www.nasa.gov/image-article/keplers-second-light-how-k2-will-work. Checked 2026-11-15: Kepler lost the second of
  four reaction wheels in May 2013; sunlight's pressure balanced with the two left as a "third wheel". A case of
  "Read the squiggles".
- **S-afj13-return** Apollo Flight Journal. *Apollo 13, Day 6, part 8: The Blackout, Splashdown and Recovery*.
  https://apollojournals.org/afj/ap13fj/29day6-returnhome.html. Checked 2026-11-16: velocity at Entry Interface
  (400,000 ft) 36,211 ft/s; the communications blackout from 0:19 to 3:38 after Entry Interface. The speed and the
  blackout of "Coming home" (issue 67).
- **S-apollo13-return** NASA History. *Apollo 13 Crew Returns Safely to Earth*.
  https://www.nasa.gov/history/apollo-13-crew-returns-safely-to-earth/. Checked 2026-11-16: two drogue parachutes at
  24,000 feet, three mains at 10,000 feet; the recovery ship USS Iwo Jima about four miles away. The parachute marks of
  "Coming home" (issue 67).
- **S-nasa-crew10** NASA. *NASA's SpaceX Crew-10 Launch Day Milestones*, Commercial Crew blog, 12 March 2025.
  https://www.nasa.gov/blogs/commercialcrew/2025/03/12/nasas-spacex-crew-10-launch-day-milestones. Falcon 9 liftoff
  7:48 p.m., Max Q 7:49 p.m., second stage engine cutoff (SECO-1) 7:57 p.m.: a climb to orbit of about nine minutes,
  the bound of the flow audit's climb (`tests/ci/flowaudit.gd`).
- **S-afj-a11-loi** NASA History Office. *Apollo 11 Flight Journal, Day 4: Lunar Orbit Insertion*.
  https://www.nasa.gov/history/afj/ap11fj/12day4-loi1.html. The LOI-1 burn ran from 075:49:51 to 075:55:49 ground
  elapsed time, about six minutes: the real length of the capture burn the flow audit compares with the game's.
- **S-afj-loi** O'Brien, F. *Lunar Orbit Insertion*, Apollo Flight Journal (NASA History Office, hosted at apollojournals.org). https://apollojournals.org/afj/loiessay.html. The crew had to "perform and monitor the burn on the far side of the Moon, without assistance from the ground": the trip's loss of signal when the braking burn happens behind the Moon.
- **S-eo-orbits** Riebeek, H. *Catalog of Earth Satellite Orbits*, NASA Earth Observatory, 2009.
  https://earthobservatory.nasa.gov/features/OrbitsCatalog. Low, Sun-synchronous and geostationary orbits in plain
  words: the glossary of the game (issue #69) and the plain names of its orbits.
- **S-noaa-scales** NOAA Space Weather Prediction Center. *NOAA Space Weather Scales*, and the pages *Coronal Mass
  Ejections* and *Solar Radiation Storm*. https://www.swpc.noaa.gov/noaa-scales-explanation,
  https://www.swpc.noaa.gov/phenomena/coronal-mass-ejections, https://www.swpc.noaa.gov/phenomena/solar-radiation-storm.
  The space weather alerts of the operation (issue #90): G4 about 100 and G5 about 4 storms per 11-year cycle, S3
  about 10 and S4 about 3; their effects on spacecraft (surface charging, orientation problems, drag on low orbits,
  memory upsets, noise in images, worn solar panels); the fastest coronal mass ejections reach the Earth in 15 to 18
  hours and slower ones take several days; protons cross from the Sun in tens of minutes, and a radiation storm lasts
  hours to days.
