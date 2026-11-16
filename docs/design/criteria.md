# Design criteria

How everything players see and hear is judged. These are criteria, not bans: where a case is not covered, decide by
the reason behind the nearest one and say what you decided. They come from the team lead's verdicts on earlier
projects and apply to the 3D models, the UI, motion, sound and copy.

## The test
Nothing may read as made by AI. Before showing anything, check it against this page; after building it, an agent that
did not build it reviews it, and a person with no context should be able to say in one sentence what a screen is for.

## Identity and graphics (lead, 2026-11-14)
- The identity and the UI are futuristic space, of the present: not a 1960s-70s control center, not retro.
- The graphics (craft, rockets, places, planets) are as real as a documentary and resemble real spacecraft.
- Characters may be stylized 3D; real objects never are. No Telltale-like look.

## Color
- The brand marks (the logo and what identifies the game as Farpoint HORIZON) carry two or three characteristic
  colors chosen together, one of them warm. Shades of one hue count as one color: a single characteristic color looks
  flat and cold. Graphics take the real colors of what they show.
- Neutrals are tinted toward the characteristic colors (never pure grey).
- Avoid the combinations AI tools reach for by default (violet fading into blue, pink or cyan as a flat wash) and muddy
  mixes. Purple is fine in moderation when the subject calls for it.
- Check the colors together, on light and dark ground and in a gradient, before using them.

## Light, depth and models
- Every scene has a light source; surfaces show it with highlights, soft shadows and reflections where the material
  has them. Gradients carry light and movement; a flat wash of color laid on top is not depth.
- 3D models are modeled, with the real geometry of what they represent (real spacecraft and rockets as reference) and
  recognizable materials: gold foil, brushed metal, solar cells, painted panels. Boxes and spheres standing in for
  parts, and flat vector drawings with small glows, read as AI.
- When a real reference exists (a photo, a real spacecraft), recreate it first, then stylize.
- Light where people work (the builder, the control center); space lit by the Sun. Dark-only interfaces are not the
  default; a dark mode can be an option.

## Interface
- A UI of its own, not a generic dark dashboard: tactile elements that belong to the world (sign-off stamps, gauges,
  switches, the craft itself showing a consequence) rather than lists of text.
- Show the 20% that matters, large and clear; details on demand. Everyday equivalences for laypeople, exact units for
  those who look closer. One message per screen moment; no crowded first screen.
- Every graphic and animation shows what it claims to show; nothing decorative pretends to explain.
- Nothing broken: no overlapping or cut text, every control works, readable sizes, visible focus, contrast at least
  WCAG AA, touch targets of 44 px.

## Motion and satisfaction
- Two layers: passive life (the scene breathes, light moves, the craft turns a little) and an answer to every action
  (a spring, a click, a count that rolls, a burst of particles). Springs and ease-outs of about 200-600 ms.
- Signature moments are worth investing in: the part that snaps into place, liftoff, stage separation, the panels
  unfolding, the first signal, touchdown.
- Animation is never driven by scrolling.

## Sound
- Sound with character: synthesized or recorded, with variation per gesture and envelopes, quiet by default, with a
  visible mute. No loop that repeats unchanged and no sound on every hover. Music and effects pause when the game is
  hidden. Sound deserves dedicated attention, not an afterthought.

## Copy
- Plain, natural English with a light touch of humor; what the player needs, nothing more.
- No colons in titles or labels (clock times are fine), no negative states ("no data"), no filler ("Here you will
  see..."), no emoji as icons (use icons and symbols), no AI vocabulary.

## Weight
- Smooth on a modest laptop and a mid-range phone in the browser: measure frame time and load time, use heavy effects
  sparingly and scale them down on small screens, keep the web build small.
