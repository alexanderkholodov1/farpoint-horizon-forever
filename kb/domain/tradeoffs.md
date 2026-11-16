# Mission design trade-offs: the coupling graph

Purpose: for every major decision, what it touches and in which direction, plus formulas simple enough to run in a game loop.
Data ids in `code font` refer to entries in `kb/data/reference.json`. Source status of each formula is stated inline.

Reading guide
- "Doc" = derived from physics and textbook equations; formula verified here by calculation, source named.
- "Dataset" = number comes from a cited source in `reference.json`.
- A one-line "teen version" follows each formula.
- Numbers marked (calc) were computed for this document with the stated formula and are not from a source; they are examples for balancing, not facts.

---

## 1. Coupling graph

Legend: `+` raises, `-` lowers, `~` depends. Read "row decision -> column effect".

| Decision | Mass | Power | Budget | Data produced | Data returned (comms) | Lifetime | Science value / coverage | Risk / schedule |
|---|---|---|---|---|---|---|---|---|
| Objective (what to measure) | sets which instrument classes are needed | sets instrument power | sets cost class | sets data rate | sets required downlink | sets how long to observe | defines success | vague objective = unbounded requirements (CML 1-2) |
| Instrument (bigger / more) | + (instrument and bus to carry it) | + (instrument power plus bigger arrays and batteries) | + (instrument cost, bus cost, launch) | + (SAR, hyperspectral, high-res optical are the largest generators) | needs bigger radio or more ground contact | pointing and cooling needs may shorten life | + resolution, spectral range, number of science products | + complexity, longer development |
| Bus size (1U to ESPA to large) | + obviously | + power available (larger area) | + (cost per kg falls with size; total rises) | ~ (more room for storage) | + (room for bigger antenna and radio) | + (more redundancy, fuel) | allows heavier instruments | larger buses need bigger launcher, less rideshare flexibility |
| Power system (array tier) | array mass vs W/kg | `solar_basic_si` 229 W/m2 vs `solar_standard_tj` about 400 W/m2 vs `solar_advanced_hp` about 433 W/m2 (BOL) | + for better cells | none | enables higher-power radios | degradation reduces EOL power | enables duty cycle | more cost, more deployables (failure point) |
| Battery (bigger, deeper DoD) | + mass | none | + | none | enables comms or imaging during eclipse | shallower DoD = longer life | allows eclipse operations | cell cycling life falls fast with deep discharge |
| Comms band and antenna | + mass for dish and radio | + radio DC power | + (X and Ka radios, dishes) | none | UHF kbps, S Mbps, X tens of Mbps to Gbps | none | converts data into science | needs licence and a ground station that supports the band |
| Ground network | none | none | + (commercial per-minute or per-pass; own station = build cost and time) | none | contact minutes per day (polar stations see many more passes) | none | enables near-real-time response | station not ready is "a mission killer" (CubeSat 101 PDF p.30) |
| Orbit (altitude, inclination) | none | eclipse fraction sets battery and array size | + (higher orbit needs bigger launcher) | none | passes per day, range (link loss) | LEO drag sets lifetime below about 600 km | coverage, revisit, resolution (GSD scales with altitude) | radiation (MEO belts) and debris rules |
| Launch vehicle | caps mass and orbit | none | + price; rideshare is cheap per mission but constrains orbit and date | none | none | none | defines reachable orbits | reliability, schedule slips, rideshare date set by primary mission |
| Propulsion | + dry mass and propellant | + for electric | + | none | none | + (station-keeping, deorbit, drag make-up) | enables orbit change, constellation phasing | launch providers get nervous about propulsion (CubeSat 101 PDF p.24); regulatory scrutiny |
| Mission lifetime (longer) | + (consumables, margins) | EOL degradation worse, bigger array | + operations cost accumulates | + cumulative data | needs more ground time | by definition | + more science | wear-out failures; rules for disposal (5 or 25 years) |
| Redundancy | + (duplicate parts) | + | + | none | none | + survival probability | protects science | + complexity; cuts failure probability, not zero |

### The five strongest couplings for gameplay (each has real teeth)
1. Instrument -> data -> comms. High-data instruments (SAR, hyperspectral, high-res optical) are useless if the radio and contact time cannot bring the data home. Rule: data generated per day must be below data downlinked per day, otherwise the onboard recorder fills and science is lost (section 3.5).
2. Instrument -> power -> array and battery -> mass -> launcher. One decision cascades through four subsystems and the launch vehicle choice (sections 3.3, 3.4, 3.7).
3. Orbit -> eclipse, radiation, drag, coverage, contact. Low orbit gives resolution and short light time but more drag and fewer minutes per pass; higher orbit gives wide coverage but lower resolution and a bigger launcher. Each orbit has a distinct penalty (section 4).
4. Launch vehicle -> orbit and mass window, with rideshare as the cheap but inflexible option. NASA CubeSat 101 states the launch date cannot be moved by a secondary payload and a late CubeSat is left behind (PDF p.36).
5. Margins and maturity -> cost growth. Early designs carry 15% mass and 25% power margins (GSFC-STD-1000) that shrink as design matures; skipping trade studies yields worse science per cost (CML paper p.3).

---

## 2. Orbit basics

### 2.1 Orbital period and speed
Formula (textbook, Kepler; `formula_orbital_period`): T = 2 pi sqrt(a^3 / mu), v = sqrt(mu / a), a = R_earth + altitude, mu = 398,600.44 km^3/s^2, R_earth = 6,378.137 km (`const_earth_gm`, `const_earth_radius_eq`).
Teen version: the higher you are, the slower you go and the longer one lap takes.

| Altitude | Period (min) | Speed (km/s) | Max eclipse (min) | Max eclipse fraction |
|---|---|---|---|---|
| 400 km | 92.6 | 7.67 | 36.1 | 39% |
| 550 km | 95.6 | 7.59 | 35.6 | 37% |
| 800 km | 100.9 | 7.45 | 35.1 | 35% |
| 20,200 km (GPS) | 718.7 | 3.87 | 55.4 | 8% |
| 35,786 km (GEO) | 1436.1 | 3.07 | 69.4 | 4.8% |

(Dataset: `orbit_leo_400`, `orbit_leo_550`, `orbit_leo_800`, `orbit_meo_gps`, `orbit_geo`; period and speed computed from the formula, GEO and GPS values agree with the documented 1436 min and 718 min.)

### 2.2 Eclipse fraction
Formula (cylindrical shadow model, `formula_eclipse_beta`): eclipse fraction f = asin(R / (R + h)) / pi when the Sun lies in the orbital plane (beta = 0). With a Sun-to-orbit-plane angle beta, f = (1/pi) acos( sqrt(h^2 + 2 R h) / ((R + h) cos(beta)) ); no eclipse if |beta| >= asin(R / (R + h)).
Teen version: in low orbit the satellite spends up to about 4 of every 10 minutes in Earth's shadow; in GEO only about 1 in 20 and only near the equinoxes.
Dawn-dusk SSO: orbit plane rides the terminator, beta near 90 deg, almost no eclipse; the cost is a fixed launch time/orbit choice. The formula in the dataset is a derivation (cylindrical shadow); the critical-beta statement has an outside source but was seen only via a search snippet (see README Gaps).
Gameplay: eclipse minutes set battery size (section 3.4); a dawn-dusk SSO is a legitimate "cheat" that trades battery mass for a restricted launch slot.

### 2.3 Sun-synchronous orbit
Inclination for SSO rises with altitude: about 97.4 deg at 500 km, 97.8 at 600, 98.2 at 700, 98.6 at 800 (calc, J2 precession of 0.9856 deg/day, dataset `orbit_sso_generic`). Real examples: Landsat 9 at 705 km / 98.2 deg (`orbit_sso_landsat9`), Sentinel-2 at 786 km / 98.62 deg (`orbit_sso_sentinel2`).
Teen version: tilt the orbit just past polar and Earth's bulge turns it once a year, keeping the same local sun angle every pass.

### 2.4 Delta-v (velocity change) for common transfers
| Transfer | Delta-v (km/s) | Status | Dataset id |
|---|---|---|---|
| LEO (400 km) -> escape | 3.18 | calc, Hohmann/energy formula | `dv_leo400_to_escape` |
| LEO -> GTO/GEO, Hohmann, 400 km | 3.85 (2.40 + 1.46) | calc | `dv_leo400_to_geo_hohmann` |
| LEO -> GEO typical budget incl. plane change | about 3.77 per table (the source flagged its own LEO/GTO/GEO figures as inconsistent) | typical range | `orbit_geo` |
| LEO -> TLI (trans-lunar injection) | about 3.2 (calc 3.08 to a 384,400 km apogee) | typical range | `orbit_lunar_nrho` |
| LEO -> Mars transfer | about 4.3 (typical, not minimal); Hohmann departure 2.93 from Earth orbit | typical range | `orbit_mars_transfer` |
| LEO -> Sun-Earth L1/L2, low-thrust spiral | about 7.4 | typical range (high-thrust value not verified, in Gaps) | `orbit_sel1`, `orbit_sel2` |
| ISS altitude upkeep | about 2 km of decay per month | documented | `orbit_iss` |
Formula (`formula_rocket_equation`): delta-v = Isp x g0 x ln(m_full / m_empty), g0 = 9.80665 m/s^2.
Teen version: the same amount of fuel gives far more speed change if your engine is more efficient (higher Isp), but efficient engines are slow and power-hungry.
Example (calc): 10 kg satellite carrying 1 kg of propellant. Cold gas (`prop_cold_gas`, Isp 40-110 s, use 60): about 62 m/s. Electrospray (`prop_electrospray_feep`, Isp 1500 s, 40 W): about 1,550 m/s. Hall thruster (`prop_hall_bht200`, Isp 1390 s, 250 W): about 1,440 m/s.
Gameplay: electric propulsion gives 20x the delta-v per kg but costs 40-250 W; a CubeSat with 20 W cannot use a Hall thruster while the array is feeding the radio.

### 2.5 Orbital lifetime (drag)
Rule of thumb from NASA ODPO FAQ and the NASA SmallSat SOA deorbit chapter (`env_leo_lifetime_vs_altitude`): below about 600 km debris normally re-enters within several years; at about 800 km often centuries; above about 1,000 km typically 1,000+ years. Smallsats near 400 km generally decay in under 5 years; above about 500 km there is no 5-year guarantee, some exceed 25 years. A fixed orbit's lifetime can vary up to 5x across the solar cycle (`env_solar_cycle_drag`).
Ballistic coefficient (mass / (Cd x area), Cd 2.2): a 6U (6 kg, 0.06 m^2) is about 45 kg/m^2, a 100 kg, 0.5 m^2 satellite about 90 (SOA). Higher coefficient = lives longer. Teen version: a dense compact satellite punches through the thin air better; a light, flat one slows down faster and falls sooner.
Rules in force (`rule_nasa_25yr`, `rule_fcc_5yr`): NASA guideline max 25 years post-mission; FCC adopted 5 years (Sept 2022 order, applies to satellites launched after 29 Sept 2024, per a search summary); ESA also moves to 5 years.
Gameplay: lifetime vs altitude is a three-zone rule (self-cleaning below about 500 km, needs a disposal plan 500-800 km, will not clean up above 1,000 km).
Note: a numeric lifetime-vs-altitude curve was not extractable from NASA's Fig 13.2 (README Gaps). Designers can tabulate from NASA's DAS tool or the SOA figure.

### 2.6 Coverage, resolution and revisit
- Resolution (pure geometry, Doc): ground sample distance GSD = altitude x pixel pitch / focal length. Halving the altitude halves GSD (sharper) for the same camera. Example (calc): 550 km, 5 micron pixel, 0.5 m focal length -> 5.5 m. Teen version: closer to the ground, sharper picture, but you see a smaller area.
- Swath and repeat (Dataset): Landsat 9 at 705 km has a 185 km swath, 16-day repeat, about 14.5 orbits/day; with Landsat 8 revisit is 8 days (`coverage_landsat9`). Sentinel-2 at 786 km has a 290 km swath and 10-day revisit with one satellite, 5 days with two (`coverage_sentinel2`).
- Track spacing (calc): at 705 km, adjacent ground tracks are about 2,759 km apart at the equator per orbit (`coverage_track_spacing_705`); a 185 km swath fills only a fraction each day, so global coverage takes many days. Rule: revisit time scales as (track spacing / swath) x orbit period, so doubling swath halves revisit; adding satellites in the same orbit divides revisit by the satellite count.
- Inclination limits latitude: ground tracks reach up to inclination latitude (ISS 51.6 deg cannot see the poles; SSO about 98 deg sees everything).
Gameplay: "need daily global imaging" forces either a wide swath, a constellation, or accepts coarse resolution.

### 2.7 Radiation by orbit
Dataset `env_van_allen`: NASA Science places the inner belt (protons and electrons) down to about 1,000 km and the outer belt (electrons) up to about 60,000 km; secondary sources start the outer belt about 13,000 km; sources disagree on the inner belt's upper edge (6,000-13,000 km) and boundaries move with solar activity. The South Atlantic Anomaly dips into LEO above about 500 km and instruments are often paused there.
Qualitative scale for the game: LEO below 1,000 km and low inclination = mild; SSO and polar = high-latitude particle exposure; MEO (GPS 20,200 km) sits in the outer belt = severe; GEO = outer belt edge + solar events, needs rad-hard electronics; L1/L2 = outside belts but exposed to solar particles and cosmic rays (`orbit_sel1`).
Electronics rating (Dataset): `obc_soc` tolerates about 20-30 krad total dose, `obc_leon` 50-300 krad. Teen version: radiation slowly cooks computer chips; higher orbits need tougher (heavier, costlier, slower) chips.
Gameplay: radiation sets a lifetime cap for cheap commercial parts and forces the player to buy rad-tolerant tiers beyond LEO.

---

## 3. Spacecraft resource formulas

### 3.1 Mass budget and margin
Mass total = sum of subsystem masses x (1 + margin). NASA GSFC-STD-1000 (GOLD rules), as recorded in the dataset (`margin_mass_*`): mass margin at least 15% at Pre-Phase A and SRR, 10% at PDR, 5% at CDR, 2% at SIR, 0 in Phases D/E. Margin applies to the current best estimate and shrinks as designs mature (which is why early estimates grow).
Teen version: always pack extra weight allowance for what you forgot, and keep less spare as the design becomes real.
CubeSat mass caps (CubeSat Design Spec Rev 14.1, from `bus_cubesat_*`): 1U 2 kg, 1.5U 3 kg, 2U 4 kg, 3U 6 kg, 6U 12 kg, 12U 24 kg. (An older rule of 1-1.33 kg per 1U appears in CubeSat 101 PDF p.12; use the CDS values.)
Structure mass (SOA, `structure_cubesat`): 1U about 0.12 kg, 3U about 0.35 kg, 12U about 1.8 kg.
Game rule: show mass with margin, colour it red when the margin falls below the phase minimum. Launch vehicle check: mass x (1 + margin) <= payload capacity to that orbit (section 5).

### 3.2 Power budget and margin
Power margin (GSFC-STD-1000, `margin_power_*`) against end-of-life capability: 25% pre-Phase A, 20% Phase A, 15% Phase B, 10% Phase C, 5% Phase D.
Average load = sum of (power x duty cycle) over all subsystems and instruments. Instruments are the swing item; the radio transmitter often dominates for short bursts.

### 3.3 Solar array sizing
Energy balance in one orbit (textbook, SMAD "Spacecraft Power" chapter; formula form verified by calculation, not re-checked against a page in this pass):
P_array_needed = ( P_avg x T_eclipse / eta_batt + P_avg x T_sun ) / T_sun
Array area A = P_array_needed / ( W_per_m2_BOL x cos(sun angle) x packing x (1 - d)^years )
where d = annual degradation, eta_batt about 0.8 (charge-discharge path), packing about 0.85.
Teen version: the panels must run the satellite in daylight and also refill the battery for the dark part, and they get weaker every year in space.
Dataset W/m2 at 1 AU, BOL: Si (`solar_basic_si`) about 229, triple-junction (`solar_standard_tj`) about 398-403, advanced (`solar_advanced_hp`) about 433; specific power typical about 30 W/kg and up to 100-140 W/kg for advanced arrays. CubeSat peak BOL power: 1U about 2-2.4 W, 3U about 8-21.6 W, 6U about 18-57.6 W (`solar_cubesat_1u_peak_bol`, `_3u_`, `_6u_`).
Degradation: GEO telemetry study gives GaAs 0.44-1.03 %/yr and Si 0.71-1.69 %/yr (`solar_degradation_geo_telemetry`); LEO is harsher, a rule-of-thumb range of 2-8 %/yr (`solar_degradation_leo_rule`, typical range, secondary source). Use 3 %/yr as a default.
Example (calc): 100 W average load in a 550 km orbit (35.6 min eclipse of 95.65 min), eta 0.8 -> array must deliver about 174 W at the array during sunlight. After 3 years at 3 %/yr with packing 0.85: Si needs about 0.98 m^2, triple-junction about 0.56 m^2, advanced about 0.52 m^2.
Gameplay: a 3U (area ~0.03-0.07 m^2 body-mounted) cannot support a 100 W instrument; deployable arrays are the upgrade path and add a deployment-failure risk (CubeSat 101 PDF p.24 recommends redundant burn wires).

### 3.4 Battery sizing
Battery energy (textbook; DoD range from dataset `battery_leo_dod`): E_batt = P_eclipse x T_eclipse / ( DoD x eta_discharge ).
Teen version: the battery must carry the whole dark part of the orbit, and you only dare use a fraction of it every lap or it wears out.
Dataset: recommended LEO depth of discharge 20-40% for long cycle life (cycle life 2,000 to 70,000 depending on DoD and chemistry; the dataset flags that a 30,000-cycle figure for LEO was not confirmed). Specific energy: cells 112-260 Wh/kg (`battery_18650_cell`), CubeSat packs 75-178 Wh/kg (`battery_pack_cubesat`), advanced chemistries 150-450 Wh/kg.
LEO cycle count: a 550 km orbit makes about 5,500 orbits per year, so a 5-year mission needs about 27,500 eclipse cycles (calc: 365 x 24 x 60 / 95.65 = 5,494 per year). This is why DoD must be shallow.
Example (calc): 100 W load through a 36.1 min eclipse = 60 Wh used; at 30% DoD and 0.9 discharge efficiency the battery must be about 223 Wh, i.e. about 1.2-3 kg at 75-178 Wh/kg.
Gameplay: deeper DoD saves mass but shortens life; a GEO or dawn-dusk SSO needs much smaller batteries.

### 3.5 Data volume versus downlink
Formulas (Doc; `link_data_volume`): data returned per pass = data rate x contact time; per day = per pass x passes per day. Data generated per day = instrument rate x duty cycle x 86,400 s.
Teen version: how much you can send home equals the speed of the radio times the minutes you can see the ground station; if you collect more than that, the recorder fills and data is thrown away.
Dataset rates (radios): UHF 9.6 kbps typical, up to 38.4 kbps (`radio_uhf_*`); S-band 256 kbps to 20 Mbps (`radio_s_*`); X-band up to 50 Mbps typical CubeSat class, products up to 1.5-3 Gbps (`radio_x_*`); Ka-band 25 Mbps to 1 Gbps (`radio_ka_*`); optical 10 Mbps to 200 Gbps (`radio_opt_*`).
Pass geometry (calc, circular orbit, overhead pass, 0 deg minimum elevation): 400 km 10.2 min, 550 km 12.2 min, 800 km 15.3 min; with a 10 deg minimum elevation mask 6.2, 7.9, 10.6 min. Typical figure from the dataset: 5-15 min per pass (`gnd_pass_polar`, `gnd_pass_midlat`; secondary sources). Real passes are shorter than the overhead maximum on average because most passes are off-nadir.
Passes per day (Dataset): a polar high-latitude station sees about 12-14 passes per day for an SSO satellite (KSAT Svalbard 14/day, `gnd_ksat_svalbard`), a mid-latitude station about 4-6 (`gnd_pass_midlat`, secondary source only).
Examples (calc, 8 min per pass):
- UHF 9.6 kbps, 5 passes/day -> 2.9 MB/day.
- S-band 2 Mbps, 5 passes/day -> 600 MB/day.
- X-band 50 Mbps, 5 passes/day -> 15 GB/day; with 14 polar passes/day -> 42 GB/day.
Gameplay: an optical camera streaming 100 Mbps for 10 minutes per day produces 7.5 GB; S-band with 5 passes carries 0.6 GB, so the player must add X-band, a polar ground network, onboard compression, or accept lower duty cycle.

### 3.6 Simplified link budget
Free-space path loss (`link_fspl`, standard formula; constant confirmed in secondary sources): FSPL(dB) = 32.44 + 20 log10(d in km) + 20 log10(f in MHz).
Teen version: signal gets weaker with the square of distance and with higher frequency, so every time you ten-times the distance you lose 20 dB (100 times weaker).
Examples (calc, d = 1,000 km): UHF 437 MHz 145 dB; S 2.25 GHz 159 dB; X 8.2 GHz 171 dB; Ka 26 GHz 181 dB. A Moon-distance link (384,400 km) at X-band 8.4 GHz: 223 dB.
What compensates (rules of thumb): +3 dB = 2x power; antenna gain rises 6 dB when dish diameter doubles at the same frequency; higher frequency gives smaller antennas of the same gain but needs more pointing accuracy and suffers rain fade at Ka.
Antenna gains (Dataset): UHF whip/patch 1.4-3.4 dBi (up to 7.5 dBi helical); S-band patch 6-11.5 dBi; X patch array 12-26 dBi; X dish 29-42.5 dBi (0.7-2 m); Ka dish 40-41 dBi (0.6 m); Ka patch 26.5 dBi (`ant_*`).
Required margin (`link_margin`, `margin_rf_link`): NASA SmallSat SOA sec 11.3.1 says 3 dB is adequate for LEO data return at 1,500 km slant range and deep-space links are usually designed for 3 dB; GSFC-STD-1000 Rev I Rule 1.06 asks for more than 3 dB (NSN direct-to-Earth) through Phase B and more than 1 dB in Phase C/E.
Light time (Dataset): Moon 1.28 s, Sun-Earth L2 about 5 s (calc from 1.5 million km), Mars 4-22 minutes (`lighttime_*`). Deep-space examples: Voyager 1 about 160 bps; Mars Reconnaissance Orbiter up to 6 Mbps, typically 0.5-4 Mbps (`dsn_example_*`).
Gameplay: ground station receive capability matters as much as the satellite; amateur UHF with a whip is cheap and low-rate, DSN class only works with high gain.

### 3.7 Launch fit check
Check (for the game): mass_with_margin <= payload capacity to the chosen orbit for the chosen vehicle, and dispenser/fairing volume compatible (CubeSat 101 PDF p.16: the launch vehicle must have extra performance margin, go to the desired orbit, and accept dispensers).
Fields available per vehicle: `payload_leo_kg`, `payload_sso_kg`, `payload_gto_kg`, `payload_tli_kg`; see section 5.

---

## 4. Orbit comparison for the game

| Orbit | Strength | Penalty | Typical use (Dataset) |
|---|---|---|---|
| LEO 400 km | Short light time, good resolution, quick natural decay (under 5 yr), low radiation | Drag, ISS-like decay about 2 km/month, short passes | ISS, tech demos, short missions |
| LEO 550 km | Balanced; Starlink shells (lowered from about 550 to about 480 km in 2026 by company statement) | Decay can exceed 5 years at solar minimum | Commercial constellations |
| SSO 600-800 km | Same local solar time each pass, repeat coverage, near-global, polar ground stations | Fixed launch window/orbit, lifetime above 25 yr near 800 km, higher radiation at high latitude | Earth observation (Landsat 9 705 km, Sentinel-2 786 km) |
| MEO 20,200 km | Wide view, few satellites for global service | Severe radiation, 12 h period, weak links for small radios | Navigation (GPS) |
| GEO 35,786 km | Fixed position, continuous contact | Highest launch cost for mass (delta-v about 3.8 from LEO), long delay 120 ms | Weather, communications |
| Molniya (600 x 39,700 km, 63.4 deg, 12 h) | Long dwell high-latitude coverage | Crosses radiation belts | Polar communications |
| Sun-Earth L1 / L2 (about 1.5 million km) | Uninterrupted solar view / cold stable deep-space view; outside belts | Station-keeping, 5 s light time, needs transfer delta-v | Solar monitoring (L1), telescopes (L2) |
| Lunar orbit / NRHO (3,000-70,000 km, 7-day) | Moon science and Artemis | TLI about 3.2 km/s | Lunar missions |
| Mars transfer | Planetary science | 4.3 km/s from LEO, 200-260 day transfer, minutes of delay | Planetary missions |

---

## 5. Launch and cost

### 5.1 Launch vehicles (Dataset `launch.json` entries; values from Wikipedia-sourced tables and user guides; see each entry's `source`)
- Capacity to LEO: Electron 300 kg; Firefly Alpha 1,030 kg; PSLV 3,800 kg; Vega-C about 2,300 kg to 700 km SSO; Ariane 62 10,350 kg; H3 16,000 kg; Vulcan 16,300 kg (VC2; more with solids); Atlas V 18,814 kg; Falcon 9 22,800 kg (17,500 kg when the booster is recovered); Ariane 64 21,500 kg; New Glenn 45,000 kg; Falcon Heavy 63,800 kg; SLS 95,000 kg; Starship 100,000 kg (status: development).
- Price: Electron about $7.5M; Firefly Alpha $15-17.6M; PSLV $18-27M; H3 about $34M; Falcon 9 about $74M; Falcon Heavy about $97M (reusable) to $150M (expendable); Ariane 62 about EUR 100M; Vulcan about $110M; Atlas V about $109M; New Glenn $68-110M; SLS about $2.5B.
- Price per kg to LEO (calc from list price over maximum capacity, `price_per_kg_leo_usd`): Falcon 9 about $4,200 (about $3,250 when expended); Falcon Heavy about $1,700; New Glenn about $1,500-2,400; Electron about $25,000; Firefly Alpha about $14,600; Atlas V about $11,100; SLS about $26,300. Published context: NASA Ames paper (Jones 2018) gives $54,500/kg for the Shuttle and $2,720/kg for Falcon 9 (`cost_rule_jones_2018_shuttle_f9`), and a 1970-2000 average of about $18,500/kg.
- Rideshare: SpaceX SSO rideshare about $350,000 for 50 kg plus $7,000 per extra kg (`rideshare_spacex_sso`, secondary source); ISS deployment about $90,000 per 1U (`deployer_iss_nanoracks`, secondary source); NASA CSLI covers launch for selected CubeSats up to about $300,000 (CubeSat 101 PDF p.19).
- Reliability notes in the dataset (all from public records): Electron 100 flights, 96 successes; Falcon 9 about 702 flights, 699 successes (counts as of Nov 2026, Wikipedia; recheck before shipping); Ariane 62 9 flights, 8 successes; H3 10 flights, 8 successes; PSLV 63 flights, 58 successes; Firefly Alpha 7 flights, 3 successes; New Glenn 3 flights, 2 successes; Atlas V 110 flights, 109 successes; Neutron has not flown (first flight expected 2027).
Rule of thumb for game: success probability per vehicle = successes / flights; apply a lower value to vehicles with fewer than about 10 flights; rideshare adds schedule risk, not price risk.

### 5.2 Spacecraft cost reference points (Dataset)
- CubeSat 3U secondary payload: about $200k-1M total development (`bus_cost_cubesat_3u_secondary`, secondary source) with launch $100-250k; NASA CSLI covers launch only, "all materials and labor, testing, ground station and operations" are the developer's cost (CubeSat 101 PDF p.19); recommended project reserve at least 10% (PDF p.21). Typical CubeSat delivery time 18-24 months, minimum 9 months (CubeSat 101 PDF p.17).
- NASA SMD cost classes: Explorer SMEX cap $190M (FY26, search summary), Discovery $500M (FY19, search summary, newer solicitations may differ), New Frontiers 5 $900M (FY22 draft), Flagship $2B and above (`bus_cost_*`).
- Mission examples (Dataset `bus_ref_*`, infobox values from Wikipedia; treat as order-of-magnitude): MinXSS 3.5 kg, 19 W; TESS 362 kg, about 400 W, about $200M; MAVEN 2,454 kg, about $582M; SMAP 944 kg, about $916M; Landsat 9 spacecraft contract $129.9M (spacecraft only); Hubble about $4.7B; JWST about $9.7B; Europa Clipper about $4.25B.

### 5.2b Cost reserves and growth (dataset category `cost_rule_of_thumb`)
- Reserve: the NASA standard AO template requires at least 25% unencumbered cost reserve (against cost to complete Phases A-D excluding reserve) for PI-led missions (`reserve_ao_min`); a SMEX example uses 25% for A-D and 15% for Phase E, with development about 90% and operations about 10% of lifecycle cost (`reserve_wbs_cost_wrap`, NASA SmallSat Institute webinar 2020). Discovery practice: 25% (`reserve_discovery_psyche`).
- Worked cost split of one SMEX-class example (FY20 USD, `example_smex_cost_split`): payload 53.6M, spacecraft 60M, operations 13.8M, launch 50M, total with reserve 260M (computed shares: launch about 19%, payload about 21%, operations about 5%). One illustration, not a rule.
- Cost class caps (A-D, usually excluding launch; dollar years differ): Discovery $450M (2014 AO), $500M (2019); New Frontiers 4 $850M (FY2015); New Frontiers 5 advance notice $900M (draft); Astrophysics SMEX $190M (FY26, via search summary); historical SMEX $165-175M and MIDEX $250M (2014-2016); original SMEX $120M and UNEX class up to $15M (FY17). No official Flagship cap found.
- Growth: GAO July 2026 (GAO-26-108556) reports portfolio-level overruns of $501.4M for the year and $4.7B cumulative, with 14 years of cumulative delay across the major projects (`gao_2026_major_projects`); no per-project average percentage was available (Gaps).
- Small-sat scaling: a teaching slide implies about $0.33M per kg for a 150 kg SMEX spacecraft (estimate, `smallsat_cost_by_analogy`); the Aerospace Corp Small Satellite Cost Model exists but its equations were not read (`sscm_scope`). Government CubeSat missions $3-30M (`cubesat_mission_cost`, c. 2019); small-sat launch about $100k/kg to LEO and $30-50k/kg rideshare in a c. 2019 document (`launch_cost_per_kg`), now far lower for Falcon rideshare (about $7k/kg extra, section 5.1).


### 5.3 Cost rules of thumb to implement (balanced for gameplay)
These are modelling rules, not sourced facts; each is grounded in a dataset value above.
- Total mission cost = spacecraft development + instruments + launch + operations, with a contingency reserve (CubeSat 101: at least 10% for a CubeSat; larger NASA missions carry larger reserves, see the data entries for sourced values).
- Cost per kg falls with scale in launch (Falcon 9 about $4.2k/kg vs Electron $25k/kg) but rises for spacecraft as complexity grows.
- Complexity multiplier: the CML paper identifies complexity and omitted programmatic items as the drivers of cost growth (CML p.9-10, 15); implement as random "surprise requirement" events that add cost or delay, more likely when trade studies were skipped.

---

## 6. Margins, maturity and "what goes wrong" levers
- Mass margin 15% -> 10% -> 5% -> 2% -> 0 across Pre-A/SRR, PDR, CDR, SIR, D/E; power margin 25% -> 20% -> 15% -> 10% -> 5% (GSFC-STD-1000 rev I, `margin_*`).
- Propellant margin: size propellant to a statistical (3-sigma) delta-v (`margin_propellant`).
- RF link margin at least 3 dB (`margin_rf_link`).
- Concept maturity: 80% of checklist items completed marks a level reached, but missing a key item (science traceability, top-level requirements, equipment list) blocks it (CML paper p.11).
- CubeSat process failures: licence missing -> demanifest (PDF p.28-29, 60); test failure -> rework and retest (p.32); ground station not ready (p.30); delivery late -> launch leaves without you (p.36).
Suggested game rule: for each failed check, the simulator reports which resource blew its margin and by how much (explainable consequence).
