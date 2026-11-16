# Mission 2, STS-61: glasses for a telescope (issue #46)

- `go("sts61")`; in the story, chapter 2 (`data/story/sts61.json`) hands over to it at its Your turn card.
- Hubble upright in Endeavour's bay over the Earth, at true size around the crew (scripts/story/sets.gd, set
  "hubble"). Five spacewalks with their real crews, work and lengths (NASA's STS-61 page; 35 h 28 min in all), each
  against its clock run fast (said on screen). For each part: take it from the toolbox (Killa's lens cloth is the
  joke), then do the job by hand (scripts/missions/sts61/work_panel.gd): turn bolts out, drag pieces into slots
  (let go and they float off), unroll the solar blanket without snagging it, slide WFPC2 along its rails, aim
  COSTAR's mirrors. Out of time: a lose screen, then that spacewalk again.
- Then the first image: turn the correction until M100 is sharp; NASA's WFPC1/WFPC2 pictures (PIA22913) close it.
- The solar wings fade while the crew work on Hubble's sides, so they never hide them.
