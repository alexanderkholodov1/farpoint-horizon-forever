# Story scenes (issue #66)

- The cuyes talk: `scripts/story/dialogue.gd` plays a scene of `data/story/<chapter>.json` over any screen (or pauses
  it). The portrait is live: the speaker's 3D model in its own small studio, with the line's mood and its mouth moving
  while the line is written; each cuy babbles in its own pitch. Title cards (date and place), NASA facts with source.
- `scripts/story/cuy_actor.gd` animates the crew models without a rig: blinks, brows, eyes, mouth corners, an open
  mouth while talking, head tilt/nod/turn toward the speaker, breathing, hops and trembles; 15 moods; a personality
  per cuy (Rumi deadpan, Killa curious, Inti proud and bouncy, Wayra sleepy).
- `scripts/screens/story.gd`: a chapter as a short film. Cinema bars, the Earth and Moon behind a platform, cuts to
  whoever speaks (close, two, low, wide), slow push-ins, the bang (shake + flash), the red alarm, power going dim.
  Reached from The crew, "Play the Apollo 13 scene".
- Chapter 1 (Apollo 13) is the first data: three scenes, facts from NASA's mission page (S-apollo13-nasa).
- Next: hook the scenes into the campaign (#43) and the chapters (#45-#50); the team confirms names and lines.
- Each mission sits between two films: the chapter's "intro" scenes (context, the problem) play before the mission,
  its "outro" scenes (what came of it, a hint of the next) after it, then the next chapter's intro, and so on
  (`data/story/<chapter>.json` keys `intro`, `outro`; `order` plays the whole film). The campaign (#43) chains them.
- The story is linear: `data/story/prologue.json` (who the cuyes are, why they go, how they reach Florida and Houston)
  plays once before mission 1; then each chapter's intro, the mission (today a "Your turn" card where the playable
  part will go, #45), its outro. `story.gd` story() lists the whole film as "chapter/scene" refs.
