# kb/data: reference dataset

`reference.json` is an engine-neutral (Godot or web) set of real-world reference values for the Space Mission Design Game. It is a single JSON object, not a bare array:

```json
{
  "meta": { "version": "...", "generated": "YYYY-MM-DD", "schema": "see README", "categories": {"orbit": 12, "...": 0} },
  "entries": [ { ...entry... } ]
}
```

## Entry schema

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string, snake_case, unique | yes | Stable key; never reuse or rename once the game references it |
| `category` | string | yes | One of the categories below |
| `name` | string | yes | Human-readable name |
| numeric fields | number | per category | Flat, lowercase, unit suffix is in the field name where helpful (`mass_kg`, `power_w`). A range is two fields: `x_min`, `x_max` |
| `units` | object | yes | Maps numeric field names to unit strings (SI: kg, W, m, km, s, bit/s, USD). Every numeric field has a unit; where a range field (`x_min`, `x_max`) is absent from the map, the unit of base field `x` applies. Counts use `count`, booleans `flag (0/1)` |
| `tier` | string | subsystems | `basic`, `standard`, `advanced` |
| `notes` | string | optional | Caveats, definition of the number, year of USD values |
| `source` | array of `{url, page?, note}` | yes | `page` is a PDF page or section name. Several sources allowed |
| `confidence` | string | yes | `documented`, `typical range` or `estimate` |

Confidence meaning:
- `documented`: the number is stated by an authoritative source for exactly that item (agency page, user guide, datasheet, official report).
- `typical range`: representative range across several products or missions; not a promise for any single one.
- `estimate`: computed from a formula or judged; the formula or reasoning is in `notes`. Game balance can adjust estimates freely; `documented` values should not be silently changed.

## Conventions
- SI units everywhere, plus km for orbital distances and USD for money. USD values are nominal for the year stated in `notes`; they are not inflation-adjusted.
- Orbit altitudes are above mean Earth surface. Payload capacities are to the stated reference orbit; a vehicle's published performance is usually for a specific altitude and inclination.
- Missing value = not found in a citable source. Gaps are listed below; do not fill them with guesses in the game data without marking `estimate`.
- Game designers: treat `payload_*`, `isp_s`, `data_rate_*`, `mass_kg`, `power_w` as the hard-constraint fields. Cost fields are the least reliable in the dataset.

## Categories
| category | entries | content |
|---|---|---|
| `adcs` | 7 | Magnetorquers, reaction wheels, star trackers, sun sensors |
| `antenna` | 14 | UHF, S, X, Ka antennas with gain |
| `battery` | 4 | Battery tiers and LEO depth-of-discharge guidance |
| `bus_class` | 22 | Bus classes (1U-12U, ESPA), reference missions, cost caps, development time, power by class |
| `cost_rule_of_thumb` | 22 | Launch cost per kg, NASA cost classes and caps, reserves, GAO growth, small-sat costs |
| `design_lab` | 6 | GSFC MDL/MPL, JPL Team X, Glenn COMPASS, Ames MDC study formats |
| `formula_source` | 4 | Formula text plus authoritative source (period, eclipse, Hohmann, rocket equation) |
| `ground_network` | 12 | NSN, DSN, KSAT, AWS, SSC, Leaf, Atlas, Viasat, SatNOGS, pass statistics |
| `instrument` | 30 | Instrument archetypes (optical, multispectral, hyperspectral, thermal IR, spectrometer, SAR, lidar, magnetometer, particle, telescope) at CubeSat to flagship scale |
| `launch_vehicle` | 15 | Launch vehicles active 2025-2026 with payload, price, flight record |
| `lifecycle_phase` | 11 | NASA lifecycle phases and reviews |
| `link_budget_reference` | 8 | FSPL, margin practice, data volume, light time, DSN examples |
| `margin_practice` | 13 | GSFC-STD-1000 mass, power, RF link, propellant margins |
| `obc` | 4 | Onboard computers |
| `orbit` | 25 | Orbits and environment: LEO 400/550/800, ISS, SSO, MEO, GEO, Molniya, Sun-Earth L1/L2, lunar NRHO, Mars transfer; delta-v, drag lifetime, radiation, coverage, debris rules |
| `orbit_power` | 1 | Orbit-average power references |
| `physics_constant` | 8 | Earth radius, GM, solar constant, sidereal day, c |
| `process_timeline` | 5 | CubeSat 101 stage durations, licensing times, CML thresholds (from the challenge PDFs) |
| `propulsion` | 7 | Cold gas, mono/biprop, electrospray, Hall, ion, PPT |
| `radio` | 17 | UHF, S, X, Ka radios and optical terminals |
| `rideshare` | 5 | Rideshare and deployer options |
| `solar_array` | 10 | Solar array tiers, peak power by CubeSat size, degradation |
| `structure` | 1 | CubeSat structure mass |
| `thermal` | 4 | Passive, heater, active thermal |

## Companion documents
- `kb/domain/tradeoffs.md`: coupling graph, formulas and rules of thumb that consume these values.
- `kb/domain/mission-lifecycle.md`: how a mission proceeds from need to operations.

## Gaps
Items not found in a citable source (omitted, not guessed). Treat all as open research tasks.

Orbits and physics
- High-thrust delta-v from LEO to Sun-Earth L1/L2 (only a 7.4 km/s low-thrust figure from a secondary table); Mars transfer C3; low circular lunar orbit parameters.
- A numeric lifetime-vs-altitude table (NASA SOA Fig 13.2 is a plot; NASA DAS can generate one); the SAA minimum altitude; Van Allen belt edges disagree between sources (inner belt top 6,000-13,000 km).
- The eclipse-fraction formula is a cylindrical-shadow derivation; only the critical beta angle has an outside source, seen via a search snippet.
- Launch-specific LEO to GEO delta-v including plane change (about 3.9 km/s) has a derived value only; the 3.77 km/s table figure is flagged as inconsistent by its own source.

Launch
- Bandwagon price and inclinations; P-POD/ISIPOD and other deployer prices; Vulcan, Firefly Alpha and Neutron fairing diameters; Vega-C LEO capacity; Ariane 6 price in USD; H3-22/H3-30 payloads; Falcon 9 LEO reference altitude; per-vehicle CSIS $/kg (chart only). Most vehicle numbers and flight counts come from Wikipedia tables (Nov 2026) because SpaceX and Rocket Lab pages were not readable; flight counts change. Rideshare prices come from secondary sources.

Spacecraft
- Orbit-average power for 1U/3U/6U/12U (only peak BOL power and ranges); payload mass fraction; design life by bus class; development time for smallsats and flagships (CubeSat only); spacecraft cost per kg (only a teaching analogy); official current Discovery/New Frontiers/Flagship caps; a current MIDEX cap; official Landsat 9 and TESS mission costs.
- LEO solar degradation %/yr from SMAD or NASA (a 2-8 %/yr rule comes from secondary sources); array mass and cost; a 30,000-cycle LEO battery figure is unconfirmed.
- ADCS accuracy for gravity-gradient and magnetorquer-only control; thermal mass/power for MLI, louvers, heat pipes; basic microcontroller OBC examples; RAD750 power unverified; GSFC mass-growth allowance by subsystem; cold gas product data; Exotrail, Accion, BET-300 propulsion.

Comms and ground
- DC power and cost for radios (tables give RF output power only); AWS Ground Station and KSATlite dollar prices (not published; a third-party AWS figure was found but not used); DSN time-request procedure and data rate per band; SatNOGS cost model; an agency-sourced mid-latitude passes-per-day figure (the 4-6 passes/day and 5-15 min pass durations are from secondary sources); KSAT 14 passes/day and Moon/Mars light times came via search summaries; L2 light time uses a distance not fetched; the FSPL constant and Voyager 160 bps are confirmed only in secondary sources.

Instruments
- No mass spectrometer or small thermal camera example. Missing mass/power: EMIT, GEDI (sources disagree), MMS fluxgate, BlackCAT, Landsat OLI alone, JWST power, NISAR instrument, Pixxel satellite. The NASA SmallSat SOA has no instrument chapter, so instrument values come from eoPortal, ESA, NASA mission pages and some search snippets (flagged in notes). Costs are mostly missing.

Lifecycle and cost
- Full NPR 7120.5 KDP table (KDP letters follow the AO template only); phase durations; GAO average cost-growth and schedule-delay percentages (only portfolio totals); a launch cost-share rule (one worked example only); official Team X / Ames MDC study durations; a Flagship cost cap.

Quality warnings
- Wikipedia-sourced mission and vehicle values are "documented" only in the sense that a cited page states them; verify against agency sources before using them in player-facing text.
- Entries with confidence `estimate` include all computed periods, delta-v, eclipse values and price-per-kg figures. Recompute with the formulas in `kb/domain/tradeoffs.md` if the game uses different constants.
- Two entries have inconsistent source values, noted in their `notes` (Sentinel-2 MSI mass/power, ECOSTRESS mass).

