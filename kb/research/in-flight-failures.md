# In-flight failures and deep-space communication: material for the ground-control station

Research for the ground-control station of SK-Horizons (vision: `docs/design/vision.md`, steps 9 and "Stations").
Written 2026-11-14. Tone target for every seed below: warm, funny, never a punishment; solving is a bonus, missing it
costs nothing (the real failures below are told as stories of clever people, not as verdicts).

How to read the sourcing:
- Each fact carries the URL where it was read. "(inference)" marks my reasoning, not a source. "(background)" marks a
  well-known fact I did not re-verify in this session; confirm it before it goes into the game or the credits.
- NASA and agency pages come first. Where I only found a secondary source, I say so.
- Dates and numbers not found in a source are left out rather than guessed.
- No NASA logos or mission patches in the game (event rules in `AGENTS.md`); naming real missions in text and crediting
  NASA data is expected.

---

## Part 1. Historical failures and their fixes (17)

Each entry: what happened, how people noticed, how it was solved, how long, source. Seeds are in Part 2 under the same number.

### 1. Apollo 11: the 1202 alarms during descent (1969, NASA)
- **What happened.** During the lunar descent the guidance computer raised program alarms 1202 (and 1201). 1202 means
  "executive overflow": no free core sets (work slots) were left. Repeated unneeded rendezvous-radar jobs, caused by the
  radar switch configuration, were filling the slots.
- **How it was noticed.** The alarm lights and codes on the crew's display; the ground saw them in the flight data.
- **How it was solved.** The software shed low-priority jobs and restarted the critical ones instead of crashing; MIT's
  restart capability had been extensively tested, so Mission Control knew the descent could go on. Flight controller
  Charlie Duke gave the go ("We're go on that alarm"). Afterwards the radar circuit breakers were pulled for ascent
  (secondary source for that last step).
- **How long.** Seconds to minutes per alarm; decided on the spot.
- **Source.** NASA Apollo Lunar Surface Journal: https://www.nasa.gov/wp-content/uploads/static/history/alsj/a11/a11.1201-pa.html
  (the credit to the radar breaker step: https://maketecheasier.com/?p=861662, secondary, treat as a lead).

### 2. Apollo 12: lightning strike and "SCE to AUX" (Nov 14, 1969, NASA)
- **What happened.** Lightning struck the vehicle shortly after liftoff; the three fuel cells dropped off the main power
  bus and telemetry on the flight controllers' screens became garbage. A second event about 52 s in took the guidance
  system offline.
- **How it was noticed.** The EECOM (John Aaron) saw his data scramble into a pattern he remembered from a simulation a
  year earlier.
- **How it was solved.** Aaron called "Try SCE to Auxiliary". The Signal Conditioning Equipment (it turns sensor signals
  into telemetry) was switched to its auxiliary supply, and readouts came back. The fuel cells were then reconnected.
  At about 1 min 36 s Houston told Conrad to switch; he confirmed about 14 s later; fuel cells reconnected by 2 min 22 s
  (per the post-flight mission report, as quoted in the Flight Journal).
- **How long.** About a minute to the switch; under 3 minutes to full recovery.
- **Source.** Apollo Flight Journal: https://www.nasa.gov/history/afj/ap12fj/01launch_to_earth_orbit.html ;
  NASA lightning analysis: https://sma.nasa.gov/SignificantIncidents/assets/analysis-of-apollo-12-lightning-incident.pdf (error 500 on 2026-11-16) ;
  story: https://www.nasa.gov/history/55-years-ago-apollo-12-makes-a-pinpoint-landing-on-the-moon/

### 3. Apollo 13: the CO2 "mailbox" (April 1970, NASA)
- **What happened.** An oxygen tank exploded in the Service Module; three astronauts used the Lunar Module (LM) as a
  lifeboat. The LM had round lithium hydroxide canisters sized for two people for about two days; the Command Module's
  spare canisters were square and did not fit the LM's round sockets.
- **How it was noticed.** Rising CO2 readings in the LM cabin (inference from how scrubbers are monitored; the cited
  pages do not quote the gauge).
- **How it was solved.** Ground engineers at the Manned Spacecraft Center designed and tested an adapter on the ground
  from items the crew had (plastic bags, cardboard, tape, hoses), then talked the crew through building it (the
  "mailbox") so the Command Module canisters could purge CO2 from the LM.
- **How long.** Hours of design on the ground, then a step-by-step read-up to the crew (exact times not in the pages
  read here).
- **Source.** NASA: https://www.nasa.gov/image-article/putting-square-peg-round-hole ; Ed Smylie obituary (led the
  fix): https://www.space.com/space-exploration/apollo/nasa-engineer-ed-smylie-who-led-carbon-dioxide-fix-on-apollo-13-dies-at-95
- **Dates (background).** Explosion April 13, 1970; splashdown April 17, 1970.

### 4. Skylab: the lost sunshield and the jammed solar wing (May 1973, NASA)
- **What happened.** Skylab launched on May 14, 1973. The micrometeoroid shield, which was also the thermal shield, tore
  away during ascent, and its debris pinned one solar array wing while the other was lost. The workshop overheated.
- **How it was noticed.** Telemetry showed low power and high temperatures right after launch (inference from the
  described effects; sources list the symptoms as overheating and low power).
- **How it was solved.** The Skylab 2 crew (Conrad, Kerwin, Weitz) launched May 25, deployed a parasol sunshade through the
  science airlock, then on June 7 Conrad and Kerwin cut the debris strap and freed the jammed wing. Interior cooled to
  about 75 F (secondary source).
- **How long.** About 11 days to the first crew, then days to the wing repair; the "We can fix anything" crew.
- **Source.** NASA: https://www.nasa.gov/history/skylab-2-we-can-fix-anything ; Smithsonian:
  https://airandspace.si.edu/stories/editorial/saving-skylab

### 5. Galileo: the high-gain antenna that never opened (launched 1989, antenna fault 1991, JPL)
- **What happened.** On the way to Jupiter the main (high-gain) antenna did not fully unfurl, leaving only the
  low-gain antenna for the whole mission. Spaceflight Now ties the fault to the spacecraft's cross-country ground trip
  (likely lubricant loss; this is that site's reading).
- **How it was noticed.** The antenna's deployment telemetry and an uneven, fluctuating gain pattern.
- **How it was solved.** Engineers could not free the ribs (many attempts), so they redesigned the data path: lossy
  compression onboard (some data reduced to as little as 1/80 of the original volume), upgraded ground receivers at
  Canberra, and arraying of antennas. One source cites a raise from 10 bps to about 300 bps (single source, treat with
  care).
- **How long.** Years of software and ground work before arrival at Jupiter (1995).
- **Source.** NASA APPEL: https://appel.nasa.gov/2011/05/13/galileos-rocky-road-to-jupiter/ ; NASA NTRS paper:
  https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/19930015365.pdf ; history:
  https://spaceflightnow.com/galileo/030921galileohistory.html

### 6. Hubble: the flawed mirror and the first servicing mission (1990 to 1993, NASA/ESA)
- **What happened.** Hubble's primary mirror had spherical aberration, a polishing error (a faulty measuring device),
  about 1/50 the thickness of a human hair.
- **How it was noticed.** Blurry images of point-like stars after launch in 1990.
- **How it was solved.** On servicing mission STS-61 (December 1993) astronauts installed COSTAR (corrective optics in
  front of three instruments) and a new camera, WFPC2, that carried its own correction. Five spacewalks, a record at the
  time.
- **How long.** About three years from launch to fix.
- **Source.** NASA: https://science.nasa.gov/mission/hubble/overview/hubbles-mirror-flaw ; ESA/Hubble:
  https://esahubble.org/about/history/servicing_mission_1/ and https://esahubble.org/about/history/aberration_problem/

### 7. SOHO: lost for weeks and found again (June to Sept 1998, ESA/NASA)
- **What happened.** On June 25, 1998 contact was lost after a gyro calibration and momentum-management sequence went
  wrong; an ESA/NASA board blamed a "calamitous sequence" of operational errors, not the spacecraft.
- **How it was noticed.** The spacecraft stopped answering; ground lost telemetry.
- **How it was solved.** A radar echo and a faint carrier were hunted for; a carrier was detected (the date given here, 3 August, is not on the NASA page cited in docs/sources.md; six weeks
  after the loss. Then thaw (the frozen hydrazine lines), power, attitude recovery; on September 16 the spacecraft
  faced the Sun again. Instruments recovered Oct 5 to Oct 24, 1998. One gyro later failed, and new gyroless software
  made SOHO the first 3-axis stabilised spacecraft to operate without a gyroscope (by Feb 1999).
- **How long.** About 6 weeks to first signal; about 3 months to Sun-pointing and recovery of instruments.
- **Source.** ESA: https://www.esa.int/Newsroom/Press_Releases/SOHO_is_pointing_at_the_Sun_again ; NASA SOHO recovery
  log: https://soho.nascom.nasa.gov/about/Recovery/
- **Note.** "Frozen hydrazine" is background knowledge and not in the pages read; verify before using.

### 8. Mars Pathfinder: the priority-inversion resets (July to Sept 1997, JPL)
- **What happened.** After landing on July 4, 1997, the lander computer began rebooting itself mid-mission. A high-priority
  task waited on a mutex held by a low-priority task that was preempted by a medium-priority task (priority inversion).
- **How it was noticed.** Repeated resets and lost data each time; the watchdog fired.
- **How it was solved.** JPL reproduced it on a ground replica using a trace mode, saw the inversion, and used the
  VxWorks C interpreter left on board to flip the mutex's priority-inheritance flag from the ground.
- **How long.** Days of diagnosis on the replica; resets stopped after the patch.
- **Source.** Cornell archive of the JPL account ("What really happened on Mars Rover Pathfinder"):
  https://www.cs.cornell.edu/courses/cs614/1999sp/papers/pathfinder.html ; Glenn Reeves interview:
  https://www.drdobbs.com/a-conversation-with-glenn-reeves/184411097?pgno=1 (these are secondary; I did not find a
  NASA-hosted page).

### 9. Mars Climate Orbiter: pounds versus newtons (1999, NASA)
- **What happened.** Ground software gave thruster impulse in pound-force seconds where the interface file required
  newton-seconds, a factor of about 4.45. The orbiter approached Mars too low (about 110 km measured versus the
  planned 226 km; survivable minimum 80 km) and was lost.
- **How it was noticed.** In hindsight, navigation tracking showed small, growing offsets that were not escalated
  ("slipped through the cracks").
- **How it was solved.** It was not; a Mishap Investigation Board named the root cause and process changes followed.
  The game can make it a "rescue in time" version (inference).
- **How long.** Months of drift in cruise; investigation report dated Nov 10, 1999.
- **Source.** NASA Phase I Board report: https://llis.nasa.gov/llis_lib/pdf/1009464main1_0641-mr.pdf ; NASA
  safety message: https://sma.nasa.gov/docs/default-source/safety-messages/safetymessage-2009-08-01-themarsclimateorbitermishap.pdf (404 on 2026-11-16)

### 10. Spirit: the flash-memory reboot loop (Jan 2004, JPL)
- **What happened.** On January 21, 2004 (about sol 18) Spirit stopped sending useful data and kept rebooting. Too many
  files in flash memory stopped the computer from accessing it, so every boot failed.
- **How it was noticed.** Beeps (carrier only), then repeated resets, and almost no data.
- **How it was solved.** The team commanded a "cripple" mode that did not use flash, then deleted thousands of files and
  reformatted flash; science resumed in early February (JPL status dated Feb 5, 2004; one timeline gives Feb 6).
- **How long.** About two weeks.
- **Source.** JPL status: https://www.jpl.nasa.gov/news/mars-exploration-rover-mission-status-8/ ; Spaceflight Now:
  https://spaceflightnow.com/mars/mera/040201spirit.html ; Reeves and Neilson paper "The Mars Rover Spirit FLASH
  Anomaly" (cited in search results, not read).

### 11. Opportunity: the global dust storm (June 2018 to Feb 2019, JPL)
- **What happened.** A Mars-wide dust storm blocked sunlight; the solar-powered rover's batteries ran down and it went to
  sleep. Last contact June 10, 2018.
- **How it was noticed.** Telemetry showed falling voltage and then silence; orbiters later imaged the storm.
- **How it was solved.** Not solved, but a lovely persistence story: over about eight months the team sent more than
  1,000 recovery commands (JPL; one secondary source says 835 in the last phase), hoping wind would clean the panels.
  Mission ended Feb 13, 2019, after the final try through the 70 m Goldstone antenna.
- **Source.** JPL: https://www.jpl.nasa.gov/news/nasas-opportunity-rover-mission-on-mars-comes-to-end/
- **Game note (inference).** Because the vision forbids a "mission lost" verdict, the seed uses the storm as a waiting
  game with a happy ending ("it woke up").

### 12. Kepler: the second reaction wheel and K2 (May 2013 onward, NASA)
- **What happened.** In May 2013 the second of four reaction wheels failed, ending precise pointing.
- **How it was noticed.** Pointing errors rose and the planet-hunting stare could not be held.
- **How it was solved.** Engineers balanced the spacecraft so that sunlight pressure acted as a "third wheel" with the two
  working wheels, aiming along the orbital path in the ecliptic. This became the K2 mission with observing campaigns
  about 75 days long; thrusters still did the fine work.
- **How long.** Months of study and tests to turn it into K2 (details of the months not read here).
- **Source.** NASA: https://www.nasa.gov/image-article/keplers-second-light-how-k2-will-work ; NASA Exoplanet newsletter:
  https://exoplanets.nasa.gov/exep/newsletters/issue14/k2update/

### 13. Hayabusa: ion engines paired across the broken halves (Nov 2009, JAXA)
- **What happened.** On Nov 4, 2009 one ion engine stopped on detecting a high neutralizer voltage; others had already
  degraded, leaving no single working engine.
- **How it was noticed.** The engine shut itself down; telemetry showed the neutralizer voltage limit.
- **How it was solved.** Engineers cross-connected the working ion source of one engine with the working neutralizer of
  another, a "virtual engine"; JAXA announced on Nov 19, 2009 that thrust above 5 mN was restored. The capsule landed
  June 13, 2010.
- **How long.** 15 days to the announced fix.
- **Source.** JAXA: https://global.jaxa.jp/press/2009/11/20091119_hayabusa_e.html (blocks automated checks; open in a browser) and
  https://www.isas.jaxa.jp/e/topics/2009/1119.shtml ; engine labels vary between reports, so the game should name the
  parts generically.

### 14. New Horizons: safe mode ten days before Pluto (July 4, 2015, NASA / APL)
- **What happened.** The main computer was compressing science data while a large command load for the flyby was being
  uploaded; a timing conflict in the command sequence overloaded it, it switched to the backup computer and entered
  safe mode. No hardware or software fault.
- **How it was noticed.** Loss of contact with Earth on July 4; communications regained at 3:15 p.m. EDT.
- **How it was solved.** Ground restored the spacecraft to normal science and set a restart-without-safe-mode safeguard;
  full science resumed July 7 at 12:34 p.m. EDT. About 30 observations (under 1% of planned science for July 4 to 16)
  were lost; the July 14 flyby kept its schedule.
- **How long.** About 3 days to normal science.
- **Source.** NASA: https://www.nasa.gov/missions/new-horizons-team-responds-to-spacecraft-anomaly/ and
  https://www.nasa.gov/missions/nasas-new-horizons-plans-july-7-return-to-normal-science-operations/

### 15. Ingenuity, flight 6: the lost camera frame (May 22, 2021, JPL)
- **What happened.** About 54 s into flight 6 one navigation-camera image was lost; every following image carried a wrong
  timestamp, so the navigation estimate was "corrected" for errors that did not exist and the helicopter oscillated
  (roll and pitch above 20 degrees).
- **How it was noticed.** Flight data downlinked afterward showed large control inputs and power spikes.
- **How it was solved.** The design's stability margin and the choice to stop using navcam images during final descent
  let it level out and land about 5 m from the target. A timing vulnerability was flagged to be fixed later.
- **How long.** Seconds in flight; analysis afterward.
- **Source.** NASA: https://science.nasa.gov/?p=357799 (page of the NASA Ingenuity blog, flight 6 update).

### 16. Voyager 2: the antenna turned 2 degrees away (July to Aug 2023, JPL)
- **What happened.** Commands sent July 21, 2023 pointed Voyager 2's antenna 2 degrees away from Earth; no data came
  back. The craft was more than 12.3 billion miles (19.9 billion km) away.
- **How it was noticed.** Data stopped; on Aug 1 the Deep Space Network, using several antennas, detected only a carrier
  signal, enough to show the craft was alive but too faint to carry data.
- **How it was solved.** The team sent a command from a Deep Space Network dish in Canberra, Australia, at maximum power
  (the "interstellar shout") telling the craft to point back at Earth. One-way light time was 18.5 hours, so it took 37
  hours to learn whether it worked. The backup was the craft's own automatic reorientation in mid-October.
- **How long.** About two weeks of silence; communications restored Aug 4, 2023 at 12:29 a.m. EDT.
- **Source.** JPL: https://www.jpl.nasa.gov/news/nasa-mission-update-voyager-2-communications-pause/ ;
  https://www.jpl.nasa.gov/news/nasa-contacts-voyager-2-using-upgraded-deep-space-network-dish/

### 17. Voyager 1: the memory chip in the flight data subsystem (Nov 2023 to 2024, JPL)
- **What happened.** In November 2023 Voyager 1 began sending unreadable data. About 3% of the flight data subsystem
  (FDS) memory was corrupted; a single chip that stores part of the affected memory had failed (cause unknown: an
  energetic particle or age after 46 years).
- **How it was noticed.** The telemetry stream turned into a repeating pattern that could not be decoded.
- **How it was solved.** A "poke" command on March 1, 2024 made the craft return a memory readout; engineers could not
  repair the chip, so they split the affected code into pieces stored in different parts of memory. They sent it on
  April 18; with a 22.5 h one-way light time they waited 45 h for the answer; usable engineering data returned April 20
  (first time since November). Science data followed in May 2024 (secondary source).
- **How long.** About 5 months to engineering data.
- **Source.** NASA blog: https://science.nasa.gov/blogs/voyager/2024/04/04/engineers-pinpoint-cause-of-voyager-1-issue-are-working-on-solution/ ;
  NASA/JPL: https://www.jpl.nasa.gov/news/nasas-voyager-1-resumes-sending-engineering-updates-to-earth/ and
  https://www.jpl.nasa.gov/news/engineers-solve-data-glitch-on-nasas-voyager-1/ ;
  timeline summary: https://science.nasa.gov/blogs/voyager/2023/12/12/engineers-working-to-resolve-issue-with-voyager-1-computer-2/

---

## Part 2. Mini-game seeds (30 to 90 seconds each)

Format: **Sees** / **Does** / **Success** / **Funny** / **Teaches**. All seeds are friendly: a miss shortens the bonus
and offers a hint; it never ends the mission. "Hint tokens" are free.

**1. Apollo 11 "1202! Is that bad?" (triage).** Sees: a shower of jobs falling into a small tray (4 slots); alarm lights; a
flight director voice asking "go or no-go?". Does: drag low-priority jobs (radar data, display tidying) off the tray
before it overflows; keep the "land the ship" job glowing. Success: tray never full for 40 s; the desk shouts "We're go
on that alarm". Funny: the jobs are tiny characters with sticky notes ("I am VERY important (not)"). Teaches: a good
computer drops the unimportant work and keeps the critical work.

**2. Apollo 12 "Try SCE to Aux" (pattern from memory).** Sees: telemetry panels turn to wavy noise after the strike; a
shelf of switches and a notebook of "pretty patterns you have seen in the simulator". Does: match the noise shape to the
one in the notebook (the player saw it earlier in a tutorial "sim run"), then call the right switch from a labeled
panel; the crew flips it. Success: panels re-sharpen one by one under 30 s. Funny: the crew answers "which switch
again?"; the correct switch has a tiny cat sticker. Teaches: knowing your instrument's "failure signature" can save a
launch; a backup power supply can clean garbled data.

**3. Apollo 13 "Square peg" (build from the junk drawer).** Sees: a table of bags, cardboard, hoses, tape, one round
and one square canister. Does: drag parts into a chain so air flows from the cabin through the square canister; each
link lights up as the airflow meter rises, and the voice of Houston reads instructions the player can follow or ignore.
Success: CO2 gauge falls to green. Funny: the player can add duct tape to anything, which always "also works". Teaches:
adapt what you have; the ground and the crew solve it together.

**4. Skylab "Parasol" (careful deployment).** Sees: a hot station diagram and a folded sunshade stuck at an angle, an
airlock hatch. Does: line up the shade by sliding two sliders to push it through the hatch, then crank to open; mind the
temperature dial. Success: dial falls to comfy. Funny: a thermometer wearing sunglasses. Teaches: thermal shields keep
stations livable.

**5. Galileo "Squeeze the picture" (compress the data).** Sees: a bar of images waiting and a very skinny pipe labeled
"low-gain". Does: choose compression per image (more squeeze = smaller, less detail) so the best image fits the pass
window; the most valuable pictures need less squeeze. Success: pass completes with all must-have pictures. Funny:
over-squeezed pictures become cute pixel dinosaurs. Teaches: when the antenna is small, smarter data beats bigger data.

**6. Hubble "Fix the blur" (focus puzzle).** Sees: a blurry star image and a stack of tiny mirrors. Does: tilt mirrors
until the star's fuzzy halo collapses into a point (the ring pattern guides you). Success: a sharp star pops. Funny: the
"before" picture is of a very confused moon. Teaches: small shape errors in a mirror blur an image, and corrective
optics can undo them.

**7. SOHO "Where did it go?" (hunt for a whisper).** Sees: a waterfall plot of noise with a faint line; a radio dial.
Does: tune and adjust bandwidth until the line stands out of the noise, then send "wake up" commands in the right order
(power, warm, point). Success: a steady carrier appears, then the Sun image returns. Funny: the craft "answers" with a
sleepy yawn sound. Teaches: finding a very weak signal means listening longer and narrower.

**8. Pathfinder "Who waits for whom?" (priority inversion).** Sees: three tasks (tall, medium, small) in a queue and a
shared key. Does: reorder or lend the key (priority inheritance) so the tall job finishes before the watchdog timer
runs out. Success: no reboot. Funny: the watchdog is a dog that wears out a bell. Teaches: a high-priority job can be
blocked by a low one; give the lower job a temporary boost.

**9. Mars Climate Orbiter "Check the units" (find the odd one).** Sees: a table of numbers from two teams. Does: spot the
mismatched unit tags (lbf-s vs N-s) before the burn, drag the converter. Success: orbit height meter reads right.
Funny: the converter is a blender. Teaches: always check units; keep a shared interface rule.

**10. Spirit "Clean the closet" (file cleanup under reboot).** Sees: a storage grid full of files and a spinning reboot
wheel. Does: during the short window between reboots delete the biggest unneeded files first (data from last week), keep
the vital ones. Success: the boot completes. Funny: files are socks. Teaches: full memory can stop a computer from
starting; safe mode without it gives time.

**11. Opportunity "Wake up, buddy" (patience game).** Sees: a dusty solar panel icon and a sleepy rover; each wind gust
clears a few pixels. Does: send gentle wake commands at the right times (when gusts hit) rather than spamming. Success:
panel clears; rover wakes with a short sunrise. Funny: it wakes with a sigh and a little rover dance. Teaches: power from
sunlight depends on dust; waiting and trying again is real engineering.

**12. Kepler/K2 "Balance on sunbeams" (physics balance).** Sees: a craft with a sun-shield "keel" and a beam of photons;
two wheels you can spin. Does: rotate to find the angle where light pressure balances and the telescope stops drifting.
Success: a steady star view for 30 s. Funny: the craft gets a surfer pose. Teaches: sunlight pushes; a craft can use it
instead of a broken wheel.

**13. Hayabusa "Mix and match engines" (wiring puzzle).** Sees: four engines each with two ports (source, neutralizer);
two of the ports glow broken. Does: wire a working source to a working neutralizer, any pair, to light a thrust gauge.
Success: gauge above 5 mN. Funny: the wiring diagram is spaghetti with sauce. Teaches: parts can be recombined to make a
working whole.

**14. New Horizons "Not two things at once" (schedule collision).** Sees: a timeline with command loads and data
compression blocks colliding. Does: slide blocks so they never overlap on the single computer before the flyby clock
hits zero. Success: flyby starts on time. Funny: the computer is a juggler with two balls and a cat. Teaches: schedule
conflicts can trip safe mode even when nothing is broken.

**15. Ingenuity "Fix the clock" (timestamp alignment).** Sees: a stream of camera frames along a time ruler, one missing.
Does: slide the later frames back to the right timestamps so the helicopter's tilt settles. Success: the wobble line
flattens. Funny: the helicopter wobbles like a toddler and then does a victory spin. Teaches: navigation needs accurate
timing, and robust control tolerates mistakes.

**16. Voyager 2 "The shout" (aim and wait).** Sees: a dish icon, a tiny ghost spacecraft with its antenna tilted 2
degrees, and a clock showing the light-time delay. Does: aim the ground dish, pick the highest-power transmitter, send
the "turn to Earth" command, then wait out the delay (a skippable countdown filled with a quiz or fun fact). Success:
telemetry lights up. Funny: the command is delivered by a megaphone, with the shout text "HELLO??". Teaches: you can
still speak to a craft that cannot be heard, with a powerful dish.

**17. Voyager 1 "Move the code" (memory Tetris).** Sees: a memory grid with a broken block and a stack of code pieces.
Does: split the code into fragments and place them into the free gaps around the dead block. Success: the telemetry
changes from gibberish to readable. Funny: the broken block is labeled "retired after 46 years (sorry)". Teaches: if
hardware fails, software can be moved around the damage.

---

## Part 3. How deep-space communication really works

### 3.1 The Deep Space Network (DSN)
- Three facilities: Goldstone (California), near Madrid (Spain), near Canberra (Australia), about 120 degrees apart
  around the Earth; each has several dishes and one 70 m dish ("230 feet"). Source:
  https://www.jpl.nasa.gov/news/eight-essential-facts-about-nasas-deep-space-network/
- Why 120 degrees: 360 / 3 = 120, so as Earth rotates one site always sees a given far-away spacecraft and tracking is
  handed off from one site to the next. Source for the purpose: Physics Today
  https://physicstoday.aip.org/features/the-deep-space-network-at-50 (it says continuous contact needs at least three
  antennas roughly 120 degrees apart in longitude) and NASA Webb page
  https://science.nasa.gov/mission/webb/science-overview/science-explainers/how-do-we-communicate-with-webb/
- Sizes: 70 m, 34 m and 26 m dishes; for Webb the 34 m dishes are used with 70 m as backup. Same Webb page.
- Load: the DSN supports almost 40 missions (Webb page); schedules go out up to six months ahead, with the first
  eight weeks fixed unless there is an emergency (same page). In 2013 it spoke to 33 spacecraft, in 1963 to 3
  (JPL "eight essential facts").
- Contact length and rhythm for a telescope near Earth: at least 2 to 3 contacts per 24 hours, mostly 2 to 6 hours each
  (Webb page). Voyager gets about 6 to 8 hours of real-time tracking per day (NASA:
  https://science.nasa.gov/mission/voyager/interstellar-science/).
- Only one DSN antenna can send commands to Voyager 2 (and they say Canberra's DSS-43 in a secondary source,
  https://maketecheasier.com/?p=861389: weak source; confirm with NASA before using it).

### 3.2 Light time (one-way, from Earth)
| Target | One-way light time | Source |
|---|---|---|
| Moon | about 1.3 s (range about 1.28 to 1.36 s); JPL rounds to about 1.5 s | https://science.nasa.gov/mission/voyager/voyager-1/voyager-1-what-is-a-light-day/ ; https://www.nasa.gov/history/alsj/a12/A12Audio_Moon_Houston.html ; https://www2.jpl.nasa.gov/basics/soi/lighttime.html |
| Mars | 4 to 24 minutes depending on the planets' positions; average about 12.9 min | NASA white paper https://www.nasa.gov/wp-content/uploads/2025/12/acr25-wp-why-moon-and-mars-v2.pdf ; table https://spacemath.gsfc.nasa.gov/planets/10Page2.pdf |
| Jupiter | 39 min 50 s on Aug 5, 2011; 48 min 19 s on July 4, 2016 (the Juno arrival) | JPL Juno kits https://www.jpl.nasa.gov/news/press_kits/JunoLaunch.pdf and https://www.jpl.nasa.gov/news/press_kits/juno/facts/ (the 2011 figure sits in the Launch kit; I read it through search summaries, not the PDFs; confirm) |
| Voyager 2 (Aug 2023) | 18.5 h, at more than 12.3 billion miles | https://www.jpl.nasa.gov/news/nasa-mission-update-voyager-2-communications-pause/ |
| Voyager 1 (Apr 2024) | 22.5 h (so 45 h round trip) | https://www.jpl.nasa.gov/news/nasas-voyager-1-resumes-sending-engineering-updates-to-earth/ (summary of NASA wording read via secondary reports; confirm) |
| Voyager 1 (Nov 18, 2026) | about 24 h: one light-day, about 16.09 billion miles (25.89 billion km) at 2:16:07 a.m. PST | https://science.nasa.gov/mission/voyager/voyager-1/voyager-1-what-is-a-light-day/ ; https://www.nasa.gov/news-release/nasa-invites-media-public-to-join-voyager-1-one-light-day-activities/ |

Note for the game (inference): "today" in the story is the dates above; the game computes light time from distance
divided by the speed of light, then shows it in a clock that can be skipped.

### 3.3 Data rate falls with distance
- Physics (standard, inference from the inverse-square law and not from one NASA page): a signal spreads out with the
  square of the distance, so doubling the distance leaves a quarter of the power at the receiver; the usable data rate
  must fall roughly the same way unless dishes, power or coding improve.
- Voyager today: science data returns in real time at 160 bits per second, via the DSN. Source:
  https://science.nasa.gov/mission/voyager/interstellar-science/ . For comparison, Galileo's emergency link after the
  stuck antenna was reported as about 10 bps rising to about 300 bps (single source:
  https://www.pulse.bot/spacetech/news/when-the-galileo-spacecrafts-main-antenna-failed-to-unfurl-on-the-way-to-jupiter-engineers-salvaged-63632d4b-2476-49c3-817f-1c195c759ae8 (404 on 2026-11-16)
  which I flagged as low-reliability; prefer the NASA papers listed in item 5 for any number).
- Webb is about 1 million miles (1.5 million km) away and downlinks stored science via Ka-band, far more efficient than S-band
  (a transfer that takes hours on Ka takes many days on S). Webb page above.
- Bands: S, X and Ka are the deep-space bands; Ka is used for high rates but is more affected by the atmosphere; some
  stations hold Ka uplink. DESCANSO: https://descanso.jpl.nasa.gov/monograph/series4/Mono4_Ch10.pdf

### 3.4 Antenna pointing
- A craft's high-gain dish must point at Earth; Voyager 2 lost the data link when it was turned only 2 degrees away
  (JPL above). The ground fixes it by shouting with the strongest transmitter the DSN has.
- Safe mode (below) often turns the craft toward the Sun and keeps the antenna toward Earth (NASA safe-mode papers).

### 3.5 Telemetry versus commands
- Telemetry (downlink): spacecraft health and science data coming to Earth. Commands (uplink): instructions to the
  spacecraft. For Webb, S-band carries commands and engineering telemetry; Ka-band returns stored science data.
  Source: Webb page.
- Craft store data on a recorder between contacts and then play it back during a pass (Webb page).
- With long light time, "joystick" control is impossible: commands are uploaded as sequences and the craft's fault
  protection covers the delay (Mars delay note: https://blogs.esa.int/mex/2012/08/05/time-delay-between-mars-and-earth/ ;
  the "sequences and onboard fault protection" claim is from the search summary; confirm on the ESA blog).

### 3.6 Safe mode
- A protective state written into flight software: the craft stops what it was doing, points arrays at the Sun for
  power and the antenna at Earth, and waits for the ground, buying the team time. Sources: NASA NTRS papers
  https://ntrs.nasa.gov/api/citations/20170002012/downloads/20170002012.pdf and
  https://ntrs.nasa.gov/api/citations/20000033274/downloads/20000033274.pdf ; explainer
  https://www.popsci.com/science/safe-mode-space-telescope/
- Real examples: New Horizons (item 14), SOHO (item 7).

### 3.7 Signal-to-noise
- The signal reaching Earth from a distant craft is faint against noise; as an inference from the Voyager 2 incident, a
  carrier signal can be detected when data cannot be (the DSN "detected a carrier signal" that was "too faint to extract
  data", JPL link in item 16). Detecting a tone needs less signal than decoding bits.
- I did not find a NASA page with the received-power numbers (femtowatts) during this session; do not put one in the
  game until a cited source (for example DSN Telecommunications Link Design Handbook, https://deepspace.jpl.nasa.gov/dsndocs/810-005/)
  is read.

### 3.8 What a ground controller actually watches (mostly inference from the sources above)
- Whether the carrier is locked (the craft is alive and heard), then whether the telemetry frames decode (data lock).
- Link health during a pass: signal strength and noise, antenna pointing and lock, which station has the craft.
- The contact schedule: pass start and end, the next handoff to another complex (Webb page: schedules).
- Spacecraft health from engineering telemetry: power, temperatures, attitude, recorder fill, and any safe-mode flags.
- Uplink plan: what commands go up, in what order, and when the answer can come back after the light-time round trip.
- Sources: Webb page, JPL Voyager updates (items 16 and 17), NASA safe-mode papers. The list itself is my synthesis (inference).

---

## Part 4. Signal-reading mini-game ideas (each tied to a real practice)

1. **Lock the carrier ("Find the whisper").** A waterfall of noise with a faint vertical line; drag a tuner to the line,
   narrow the filter until the carrier stands out. Practice: the DSN's detection of Voyager 2's carrier when data
   could not be decoded (item 16); also SOHO's carrier hunt (item 7).
2. **Align the dish ("Hello, Canberra").** Two sliders for the dish angle and a hint line; the signal bar rises near the
   peak; lock after 5 s on target. Practice: pointing matters, 2 degrees ended the Voyager 2 link; the 70 m dish was used
   for the strongest signal.
3. **Decode the telemetry ("Read the squiggles").** A strip of values (battery, temperature, spin) with one anomalous
   channel; flag it and choose the likely cause from three. Practice: the EECOM reading telemetry in Apollo 12 and
   the garbled FDS in Voyager 1 (items 2, 17).
4. **Packet triage before the pass ends ("Last five minutes").** Packets of different priority and size slide by; the
   pass window shrinks; put critical engineering packets first, science next, extras last. Practice: limited contact
   windows of 2 to 6 hours for Webb and 6 to 8 hours per day for Voyager (Part 3.1); Galileo's compression (item 5).
5. **Handoff relay ("Follow the Sun, follow the dish").** A globe with three DSN complexes; as the Earth turns, hand off
   the craft to the next station before the current one loses sight. Practice: the 120-degree rule (Part 3.1).
6. **Command composer with delay ("Say it once, say it right").** Build a short command sequence from labeled blocks;
   after sending, a countdown equal to the round-trip time; the answer arrives with the result. Practice: Voyager 1's
   45-hour wait for the fix (item 17).
7. **Which band? ("S, X or Ka").** Choose a band for commands, telemetry, or bulk data, balancing speed with weather.
   Practice: Webb's S for commands and Ka for science data; Ka is sensitive to atmosphere (Part 3.3).
8. **Safe-mode recovery checklist ("Is it asleep or lost?").** Read a list of status lights, decide the order of
   recovery steps (get a carrier, check power, point, check computer, restart instruments). Practice: SOHO (item 7), New
   Horizons (item 14).
9. **Pattern match from the notebook.** Like seed 2, a standing small-time game that reuses the player's earlier
   observations as a "ground-control notebook": the player learns signatures (dust storm voltage curve, reboot loop,
   frame drift) and matches them during failures. Practice: failure signatures such as the Apollo 12 pattern and the
   Spirit reboot loop (items 2, 10).

---

## Gaps and checks before use
- Not found as a NASA-hosted page: the Pathfinder priority inversion (item 8). Use JPL's Reeves text (Dr. Dobb's, Cornell archive) and mark as secondary.
- Not read in full: Galileo antenna papers (item 5), Reeves/Neilson Spirit paper (item 10), Apollo 13 timeline detail (item 3), Skylab NASA pages (item 4).
- Not found: received-power figures for deep-space signals, and a NASA statement on Voyager 1 science-data return dates (secondary source only).
- Unit cautions: Voyager 1's light time changes daily; the game should compute it, not hard-code it.
- Real mission names appear in text only; no NASA insignia anywhere (event rule).
