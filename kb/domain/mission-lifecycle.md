# Mission lifecycle, distilled for game design

Purpose: how a real space mission goes from a need to operations, and what each stage means for game stages, decisions and failure events.
Scope: the three challenge PDFs plus the NASA lifecycle sources named in section 2.

Citation convention: "WEB p.N" = `250323-design-and-develop-science-mission.pdf` (NASA SmallSat Institute webinar, 26 Mar 2025), PDF page N (slide number).
"CML p.N" = `Space_Mission_Concept_Development_Using_Concept_Maturity_Levels.pdf` (Wessen, Borden, Ziemer, Kwok, JPL, 2013), PDF page N.
"CS101 p.N (printed p.M)" = `nasa_csli_cubesat_101_508.pdf` (NASA CubeSat Launch Initiative, Oct 2017). PDF page = printed page + 8.
Files are in `docs/`.

---

## 1. The big picture (what players should see)

Process (WEB p.10): Identify Need & Goals -> Define Concept -> Define Requirements -> Design -> Build & Verify -> Implement.
Rule that matters for game design: "Begin with the end in mind" (WEB p.15-19). Start from the user segment (who uses the data and what product they need), then derive requirements, then design backwards. The BioNutrients-2 example derives hardware limits (12 samples, 30 mL each, < 250 g container, < 300 mL volume) from the science question, and plans how each requirement will be verified (for example "< 250 g" is verified by weighing the empty container; WEB p.19). A game requirement should likewise carry a verification method.

### The four segments (WEB p.8; applied to an example on WEB p.14)
| Segment | What it is | Game resource it maps to |
|---|---|---|
| Launch | Launch vehicle and related services to reach space | mass limit, orbit reachable, price, launch date risk |
| Space | Spacecraft, orbiters, landers, rovers, instruments | mass, power, data generated, lifetime |
| Ground | Ground stations and mission control that command the spacecraft, receive data, manage the mission | contact time, downlink capacity, operations cost |
| User | Scientists and the public who use the data | science value, data products, scoring |

Every one of the four can be the weak link. Score the mission across all four, not only on the spacecraft.

### Concept of Operations (ConOps)
WEB p.13 (quoting NPR 7123.1): ConOps describes at a high level how the system will be used to meet stakeholder expectations, usually in time order; helps understand goals; stimulates requirements and architecture; is the basis for operational planning; and gives the criteria for validation.
Game use: the "mission timeline" screen (launch -> checkout -> science -> end of life) is the ConOps. The simulation should be played against it.
Reference given on WEB p.2: NASA SE Handbook SP-2016-6105 Rev 2, Appendix S (ConOps annotated outline).

---

## 2. NASA project lifecycle (Pre-Phase A to Phase F)

Source: NASA Systems Engineering Handbook SP-2016-6105 Rev 2, section 3 "NASA Program/Project Life Cycle" (https://www.nasa.gov/reference/3-0-nasa-program-project-life-cycle/, https://www.nasa.gov/seh/3-project-life-cycle; dataset ids `phase_*`, `lifecycle_structure`, `review_list`). Governing documents: NPR 7120.5 (space flight programs and projects), NPR 7123.1 (systems engineering). Source caveat: the web page read gives purposes and reviews per phase but does not letter the KDPs or give durations; the KDP letters used below come from the standard NASA AO template (https://soma.larc.nasa.gov/StandardAO/pdf_files/StandardAOTemplate181023f.pdf), which uses them for cost-reserve rules, and from general NASA usage. The full NPR 7120.5 KDP table was not read in this pass (README Gaps).

| Phase | Name | Purpose (SEH) | Major reviews named | Group |
|---|---|---|---|---|
| Pre-A | Concept Studies | Produce a broad spectrum of ideas and alternatives for missions; may run several years | MCR, informal proposal review | Formulation |
| A | Concept and Technology Development | Develop a credible mission/system architecture responsive to the need | SRR, MDR/SDR | Formulation |
| B | Preliminary Design and Technology Completion | Finish technology development, prototyping, heritage hardware/software assessments | PDRs (system and lower level) | Formulation |
| C | Final Design and Fabrication | Complete and document detailed design | CDR, PRR, SIR, safety review | Implementation |
| D | System Assembly, Integration and Test, Launch | Assemble, integrate, verify, validate and launch | TRRs, SAR or pre-Ship Review, ORR, FRR, configuration audits | Implementation |
| E | Operations and Sustainment | Conduct the prime mission and keep supporting the need | PLAR, CERR, DR, system upgrade review | Implementation |
| F | Closeout | Decommission, dispose, analyze returned data and samples | DRR | Implementation |

Key decision points (KDPs) are gates between phases where the decision authority lets the project proceed. In PI-led competed missions KDP-C (Confirmation) is the Phase B to C gate and a minimum 25% unencumbered cost reserve is required (AO template, dataset `reserve_ao_min`). Acronyms: MCR mission concept review, SRR system requirements review, MDR/SDR mission/system definition review, PDR preliminary design review, CDR critical design review, SIR system integration review, ORR operational readiness review, FRR flight readiness review, PLAR post-launch assessment review (standard NASA usage; the fetched page printed acronyms without expansions).

Mapping to the CML scale (CML p.4, Fig. 2): CML 1-4 sit in Pre-Phase A; CML 5 is the level for an MCR (assigned projects) or Step 1 proposal; CML 7 for the PMSR/MDR; CML 8 and 9 equal PDR and CDR.

What each phase means for a game:

| Phase | Decisions | Info needed | Typical failure |
|---|---|---|---|
| Pre-A | objective, cost class, rough architecture | science question, target cost class (CML 1) | skipping trade studies (CML p.3) |
| A | architecture, requirements, technology choices | trade results, ConOps | requirements that cannot be verified |
| B | preliminary design, margins | mass/power tables, prototypes | margins already below phase minimum |
| C | detailed design, procurement | drawings, interface documents | late design changes ripple through mass and power |
| D | build, test, ship, launch | test results, readiness reviews | test failures, late licences, launch slip |
| E | operations, data return | contact schedule, anomaly procedures | ground station or data-return shortfall |
| F | disposal | debris compliance plan | deorbit rule violated (5 or 25 years) |

---

## 3. Concept Maturity Levels (CML) and design-lab study levels

Source: CML p.1-4, 11, 14-15. CML is a JPL scale for how mature a concept is during Pre-Phase A, 2008 onward (CML p.1-2).

| CML | Name | What it requires (CML p.2) | Study type | Decisions made |
|---|---|---|---|---|
| 1 | Cocktail Napkin | Science questions articulated; type of observations proposed; rudimentary sketch and high-level objectives. CML 1 only considers: science objective, unique mission characteristics, approximate launch time frame, target cost class (CML p.11) | Idea | What do we want to learn and why is it unique? |
| 2 | Initial Feasibility | Idea questioned on science, technical, programmatic feasibility; lower-level objectives; key performance parameters quantified; first-order calculations show viability | First-order calculations | Is it physically and financially possible at all? Which cost class? |
| 3 | Trade Space | Exploration of science objectives and architecture trades between spacecraft, ground system and mission design, to understand the relationship between science return, cost and risk | Trade studies | Which combination of orbit, instruments, bus, ground gives the best science per cost and risk? |
| 4 | Point Design | One specific design and cost that returns the desired science, down to major subsystems, with acceptable margins and reserves; subsystem trades done | Point design | Freeze the design (mass/power/cost table with margins) |
| 5 | Baseline Concept | Implementation approach: partners, contracting, I&T approach, cost and schedule. Level needed for a NASA Step 1 proposal or a Mission Concept Review | Proposal | Who builds what, when, for how much |
| 6 | Integrated Concept | Expanded technical, management, cost detail; level of a Step 2 Concept Study Report | | |
| 7 | Preliminary Implementation Baseline | Preliminary requirements and analyses, demonstrated margins and reserves, prototyping, risk plans; needed for PMSR (competed) or MDR (assigned) | | |
| 8 / 9 | PDR / CDR | Design and planning commensurate with PDR / CDR | | |

Key lessons for game design (CML p.3):
- CML 2-4 is a loop, not a line. If a point design fails, teams go back to trade-space exploration. Allow players to go back and redesign without punishment.
- Teams that skip trade-space exploration and jump to point design get (1) less science return, (2) inefficient spacecraft and ground design, (3) less efficient overall missions. A game mechanic: show a "science partials" view, i.e. how science return changes with one parameter (mass, data volume, orbital period).
- Trade space exploration "increases the likelihood that a global optimum is identified" (CML p.3).
- The matrix has 24 rows: 2 science, 13 technical, 5 management, 1 cost, 3 other (CML p.4). The science rows are "why" (science objectives) and "what" (science data products) (CML p.5, Fig. 3). The matrix itself is an image (CML p.5-10) and is not machine-readable text.
- Maturity checklist rule: a concept is "at" a level if 80% of that column's attributes are complete; "nothing special about 80%" and judgment is needed (CML p.11). A concept at 90% but missing its Science Traceability Matrix, Level 1 requirements and Master Equipment List is not mature. The checklist measures completeness, not quality, and does not weight attributes. Self-assessment is "very dangerous" and tends to be optimistic (CML p.14). Game use: a pre-launch readiness checklist with a pass threshold, plus a rule that one critical missing item blocks launch regardless of the percentage.
- Cost tools at CML 2 have large uncertainty; they are only good enough to decide the cost class (CML p.15). Game use: show cost as a range early, narrowing with maturity.
- Omitted programmatic items cause redesign or cost growth (CML p.9, Fig. 5), and "other" areas (export compliance, NEPA, etc.) are "considered after-the-fact and can lead to cost growth or worse" (CML p.10, Fig. 7). Game use: a surprise-requirement event table.
- Typical NASA cost classes named: Explorer, Discovery, New Frontiers, Flagship (CML p.15).

### NASA design labs (study levels)
- JPL A-Team handles CML 1-3 (idea generation, feasibility, architecture trade space, science traceability, technology infusion). Facilitated sessions, small team, rapid and inexpensive exploration (CML p.15).
- JPL Team X (created 1995; over 1,000 studies by 2013) does CML 4 point designs: "usually 3 [collaborative design sessions] over the span of a week", producing mission design, spacecraft design, cost and risk results (CML p.15).
- Other labs listed on WEB p.24: NASA Glenn COMPASS Lab (design-by-type pages, e.g. Mars Moon Sampler, New Frontiers class). The Goddard Mission Design Lab is not described in the three PDFs; see `kb/data/reference.json` category `design_lab` for sourced descriptions.
- Game mapping: "quick study" (CML 2, coarse numbers, wide error bars), "trade study" (CML 3, compare 2-4 architectures), "point design" (CML 4, full mass/power/cost table with margins).

---

## 4. CubeSat 101 process (CSLI), stage by stage

Source: CS101 chapter 2 (PDF p.17-38, printed p.9-30). Timeline figure: PDF p.18 (Fig. 8) and Appendix E (printed p.85, PDF p.93).
Overall: a CubeSat can be designed, built, tested and delivered in as little as 9 months, typically 18-24 months; delivery to launch ranges from a few months to a few years; the launch vehicle usually requires delivery 4 weeks to 6 months before launch (CS101 p.17, printed p.9).

CSLI = NASA CubeSat Launch Initiative: NASA covers launch costs (up to $300,000, "typically enough to launch a 3U into low-Earth orbit") for selected CubeSats, in exchange for a report on results; developers pay for everything else (CS101 p.10 and p.19, printed p.2 and p.11). Annual call: an Announcement of Partnership Opportunity posted typically early August, proposals due typically November (CS101 p.11, printed p.3).

| # | Stage (duration) | PDF p. | Decisions made | Information needed | What typically goes wrong |
|---|---|---|---|---|---|
| 1 | Concept development (1-6 mo) | 19 | Mission goal; sponsor/partners; match to NASA Strategic Plan goals | Funding sources, partner goals | Choosing very specific orbit or launch date makes manifesting hard; "flexibility is key" |
| 2 | Securing funding (1-12 mo) | 19-21 | Which funder (RFPs, NSF, ESTO, Space Grant, crowdfunding, tech-demo sponsors) | Detailed cost estimate: materials, labor, environmental testing, travel, ground station | Cost depends on complexity, team experience, duration, specialised hardware; under-funding loses the launch slot and can lead to demanifest of co-manifested CubeSats; reserve of at least 10% recommended; travel often forgotten (p.21) |
| 3 | Merit and feasibility reviews (1-2 mo) | 22-23 | Go/no-go on proposing | Independent reviewers outside the team | Treating reviews as a box-check; CSLI also looks at how findings were addressed |
| 4 | CubeSat design (1-6 mo) | 23-25 | Components (mostly commercial off-the-shelf), simple vs ambitious design | Prior CubeSat lessons, vendors, CubeSat Design Spec (CDS) | Propulsion makes launch providers nervous; keep design simple and use flight-proven batteries, antennas, ADCS; put important parts on the exterior to ease repair after test failures; double burn wires on deployables (p.24) |
| 5 | Proposal to CSLI call (3-4 mo) | 25 | Mission type: science / technology / education | AoPO requirements | Noncompliant proposals removed; a strong science case with a weak education plan scores lower (p.25-26) |
| 6 | Selection and manifesting (1-36 mo) | 26 | Which launch opportunity to accept | Orbit and date constraints | Priority list 12-16 weeks after deadline; priority is not a ride; wait driven by orbit flexibility. A CRADA contract follows (p.26) |
| 7 | Mission coordination (9-18 mo) | 27-28 | Interface Control Document (ICD) requirements, test levels | Integrator schedule, templates | ICD is "the official rulebook"; kickoff ~18 months before launch (p.27) |
| 8 | Regulatory licensing (4-6 mo) | 28-29, 51-60 | Frequency band, remote-sensing licence if imager | RF licence (FCC for non-federal, NTIA for federal), NOAA licence if imaging; FCC minimum 90 days from application (p.57-58), NOAA about 120 days (p.59) | Missing licence before delivery causes demanifest. Example: a CubeSat was already in its dispenser days before launch without an FCC licence (p.29). NOAA application changes restart the process (p.60) |
| 9 | Flight documentation (10-12 mo) | 29, 61-72 | Safety and orbital debris compliance | 11 deliverables: orbital debris assessment report (ODAR), transmitter survey, materials list, mass properties, battery report, dimensions, electrical report, venting analysis, test reports, compliance letter, safety inputs (p.62) | Late revisions after design changes; high-melting-point materials surviving reentry raise licensing issues and possibly insurance (p.62) |
| 10 | Ground station (2-12 mo) | 30-31 | Own station vs partner; radio and antenna | Amateur radio expertise, tracking via TLEs | "Launching with an inadequate ground station is a mission killer" (p.30). Test early by tracking other satellites |
| 11 | Hardware fabrication and test (2-12 mo) | 31-33 | Build 1 or 2 flight units; ETU and FlatSat | Test levels from ICD | Parts fail during vibration; after verification testing no further work without retest; loss of knowledge as students graduate (p.32). "Test like you fly" (p.33) |
| 12 | Mission readiness review (half day) | 33 | Flight approval | All deliverables accepted, tests complete | Must present in person; draft due 2 weeks earlier |
| 13 | CubeSat-to-dispenser integration (2 days) | 34-35 | none (last access) | Hazards, special accommodations | No access after closing the dispenser (p.34) |
| 14 | Dispenser-to-launch vehicle (1 day) | 35 | none | none | Developers not invited |
| 15 | Launch (1 day) | 36 | none | none | Only the primary mission can move the date; late CubeSat is left behind; scrubs are common (p.36) |
| 16 | Operations (variable, up to 20 years) | 37-38 | Commanding, data collection | TLEs/state vectors from JSpOC | Identifying which tracked object is yours can take several weeks (p.38); first contact is often via volunteer amateur trackers |

Other CS101 facts useful for the game:
- Definition: small satellite is below 300 kg; CubeSat 1U is a 10 cm cube with a mass of about 1-1.33 kg; 3U is 10 x 10 x 34 cm; larger sizes 1.5U, 2U, 3U, 6U, 12U exist; 6U introduced 2014 (CS101 p.12-14).
- About half of CSLI missions are scientific (space weather and Earth science most often); 66% are technology demonstrations (CS101 p.11).
- Launch vehicle for a CubeSat must have additional performance margin, be going to the desired orbit and accept dispensers (CS101 p.16).
- Mission models (who sponsors the ride): NASA-procured launch, ORS rideshare, NRO rideshare, commercial via third-party broker, ISS deployment (CS101 p.39-46). Each brings different requirements and integrators.
- Verification testing types: vibration (required for all launches), thermal vacuum bakeout, shock (sometimes), EMI/EMC, Day-In-The-Life (DITL) with frozen flight software (CS101 p.32, 67-69).

---

## 5. Game design summary: stage -> decision -> failure event

Proposed game stages (each stage = one player screen and one check):
1. Objective and user (CML 1): choose a science or technology question and a cost class. Output: required observation type, user data product. Check: is the objective measurable? Failure event: a vague objective raises later redesign probability.
2. Requirements (CML 2): derive requirements backwards from the data product (WEB p.15-19); each carries a verification method. Check: first-order feasibility using `tradeoffs.md` section 3 formulas with wide error bars.
3. Trade study (CML 3): compare two to four architectures (orbit, instrument tier, bus size). Reveal science-vs-cost-vs-risk "partials". Reward trying more than one option.
4. Point design (CML 4): spacecraft build with mass, power, data, cost tables including phase margins (15% mass / 25% power at this stage).
5. Launch and licensing: pick vehicle and orbit; check mass/orbit fit; licence and dispenser lead times; rideshare date risk (CS101 p.26-29, 36).
6. Verification and readiness: tests and a readiness checklist with the 80% rule plus a critical-item block (CML p.11, CS101 p.32-33).
7. Launch and commissioning: reliability roll from the launch vehicle record; early-orbit identification delay (CS101 p.38).
8. Operations: contact passes, data downlink vs generation, eclipses, degradation, anomaly events; science score accumulates.
9. End of life: disposal compliance; lessons-learned report.

Failure modes drawn from the sources (use as event tables): missed licence (CS101 p.29), under-funding and demanifest (p.19), unprepared ground station (p.30), test failure and retest (p.32), late delivery (p.36), lost knowledge when staff leave (p.32), omitted programmatic items causing redesign or cost growth (CML p.9-10), self-assessed optimism (CML p.14).
