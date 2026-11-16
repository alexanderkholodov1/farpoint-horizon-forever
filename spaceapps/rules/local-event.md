# The local event: Sangolquí, rules and rubric

Source: *Guía oficial para participantes, NASA Space Apps Challenge Sangolquí 2026* and *Guía integral y metodología
oficial de calificación y juzgamiento* (Comité de Jueces, Universidad de las Fuerzas Armadas ESPE), copy in
`spaceapps/challenge/GUIA PARTICIPANTES Y RUBRICA.pdf`. Read on 2026-11-14. Where this file and the global rules
(`event-and-judging.md`) differ, the team follows both: the local one decides the local score and nominations, the
global one decides global eligibility.

## Where and when
- Venue: Universidad de las Fuerzas Armadas ESPE, Sangolquí, Ecuador. Saturday 14 and Sunday 15 November 2026.
- **Sunday 09:00**: deliverables uploaded to the venue's official form (shared by the organizers) and to the global
  NASA Space Apps platform.
- 09:30-10:45: staff audit of every project page (links, NASA data, repository, format).
- 11:00-13:30: live pitch **in Spanish** plus questions, in 4 rooms, 4 judges per room. 14:30 deliberation, 15:00
  awards and the announcement of the global nominees.
- Mentors work in four thematic blocks; this challenge is in block 3 (games, gamification, strategic simulation),
  Saturday morning and afternoon. Block 4 covers storytelling and pitch rehearsal for every team, including Sunday
  07:30-10:00. Mentors ask questions, validate science data, help scope the MVP and rehearse the pitch; they do not
  write code.

## Deliverables
- Slides as PDF or Slides, **at most 7** including cover and closing. Recommended (not mandatory) order: cover (team,
  project, challenge, venue Sangolquí); the problem; the solution; NASA data and scientific grounding, with visual
  evidence and the processing method; technical architecture and the working MVP; impact, usability, scalability and
  the post-hackathon roadmap; transparency (AI and tools used), scientific credits and team roles.
- A demo video for the global platform, if used: at most 30 s (35 s tolerance).

## Staff audit: penalties subtracted from every category (up to -8)
| Item | What the staff checks | Penalty |
|---|---|---|
| NASA open data | Active links or explicit citations of official NASA or partner datasets (Earthdata, Landsat, GIBS, APIs...) on the project page | -2 |
| Public repository and open license | A link to the repository and a license file (MIT, Apache, GPL or CC) at its root | -2 |
| Public links | Every link (demo, video, repository, documents) opens in a private window with no login and no 404 | -1 |
| Length | 8 or more slides, or a video longer than 35 s | -1 |
| AI and NASA logos | The AI-use declaration ticked; **visible watermarks on AI-generated images**; no NASA logos with AI | -1 |
| Two languages | The project description and the deliverables on the platform **in both Spanish and English** | -1 |

## The rubric (each question scored 1 to 5; 5 only for truly outstanding work)
- **RCD, scientific rigor and data:** NASA datasets named and shown visually and how they drive the project (1.1);
  sound science (1.2); how the data was processed, explained (1.3: "a pipeline, script or model that turns the data
  into useful information" scores 4); command of the science in Q&A (1.4); transparency about models, libraries,
  literature and AI, telling own work from outside help (1.5).
- **IET, innovation and technical execution:** a working, interactive demo during the pitch (2.1); a coherent
  architecture, explained (2.2); originality (2.3); technical defense in Q&A (2.4); feasibility and reproducibility
  (2.5).
- **IR, impact and relevance:** direct alignment with every objective of the challenge (3.1); size of the impact
  (3.2); a realistic path to adoption and scale after the event (3.3); fit with a real context, local in Ecuador,
  global or space (3.4); accessibility and usability for the real users (3.5).
- **STP, storytelling and presentation:** a narrative of problem, solution with data, impact (4.1); visual quality of
  slides and UI (4.2); time management (4.3); confident, inspiring delivery (4.4); the team answering together, each
  by role (4.5).

## How nominations are scored
Each category weighs the four area averages differently (RCD/IET/IR/STP): Best Use of Data 50/20/15/15; Best Use of
Science 50/20/20/10; Best Use of Technology 20/50/15/15; **Best Mission Concept 25/35/25/15**; Galactic Impact
15/15/50/20; Best Storytelling 15/15/20/50; **Art & Technology 15/40/15/30**; Global Connection 15/15/45/25; Local
Impact 15/15/50/20; Most Inspirational 10/15/25/50. Base = sum of (area average x 20 x weight); each judge's
nomination adds +3 in that category (up to +12); staff penalties are subtracted.

## What this means for us (inference)
- Real NASA datasets must be visible inside the game and in the pitch, with the processing explained: not only cited
  parameters. Candidates: imagery from NASA GIBS or Earthdata shown as the data a mission returns; positions and
  launch windows from JPL Horizons; physical constants from NSSDC fact sheets; a small, documented pipeline that turns
  them into game data.
- The pitch is in Spanish, while the platform needs Spanish and English: the description, README and deck exist in
  both languages; the game itself can offer both.
- Images made by an AI need a visible watermark; models and textures made by our scripts or taken from cited sources
  avoid the question. The AI declaration is ticked and the disclosure section names the agents.
- Strongest categories for this game: Best Mission Concept and Art & Technology (technical execution weighs most),
  Best Storytelling (presentation weighs most).
