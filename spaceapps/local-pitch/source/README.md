# The pitch deck

Seven slides in two languages, written as text and built into HTML and PDF by `<deck script, removed> so any agent
edits a line of text instead of a slide file. `en.md` is the deck for the global platform (decks must be in English);
`es.md` is the one shown at the live pitch in Sangolquí (in Spanish) and the Spanish deliverable. Its notes are the
spoken script, five minutes in all.

## The rules it follows
From `spaceapps/rules/local-event.md` and `spaceapps/rules/event-and-judging.md`:
- **At most 7 slides, cover and closing included.** 8 or more costs a point locally and the global eligibility.
  a deck script (no longer kept in the repository) fails above 7.
- **The order the venue recommends:** cover (team, members, challenge, venue) · problem · solution · NASA data with
  visual evidence and how it is processed · architecture and the working game · impact, scale, roadmap ·
  transparency (AI and tools), credits and team roles. Each slide's notes name the rubric questions it carries.
- **Both languages, slide for slide** (the venue deducts a point for one language only). The script fails when the
  two decks differ in slide count; keep their content in step by hand.
- **No NASA logos or insignia, no AI-generated images, no picture of anyone under 18.** Pictures come from the game's
  own screenshots and from the NASA imagery already in the game, each caption citing its `docs/sources.md` ID.
- **Every link public** (opens in a private window with no login).

## Format of `en.md` / `es.md`
A front matter (`title:`, `footer:`), then one block per slide after a line `---`:
```
---
layout: split                     cover · split (text left, pictures right) · wide (text above, pictures in a row)
label: NASA data at the core      the small caps line above the title
image: path/from/repo.jpg | caption [S-source-id]       one to four pictures
image: shot: what to capture | caption                    a dashed frame waiting for a screenshot
background: path.jpg              optional, for cover or full

## Title of the slide
- A bullet with **bold** and `code`
> A large sentence
### A small caps heading
flow: Step -> Step -> Step         a row of chips joined by arrows
Notes:                             (Notas: in Spanish) speaker notes, not shown; written to build/notes-<lang>.md
```
Anything still to do is written `TODO` in the text: it shows highlighted on the slide and the script lists it.

## Build and check
```
python <deck script, removed>              # both languages -> build/deck/deck-{en,es}.{html,pdf}, notes-{en,es}.md
python <deck script, removed> --final      # also fails while any TODO or screenshot frame is left
python <deck script, removed>         # the same slides as editable PowerPoint -> build/deck/deck-{en,es}.pptx
python <deck script, removed>          # only to redraw the backgrounds in spaceapps/local-pitch/source/art
```
`pitch.py` needs Python 3 and Chrome or Edge (set `CHROME` to its path if it is not found); `pitch_pptx.py` needs
`pip install python-pptx pillow`; `pitch_art.py` needs numpy, Pillow and, for the cover, ffmpeg and the game's own
recording (`build/video/raw.ogv`). A slide whose text or pictures do not fit gets a red "TOO MUCH TEXT" mark in the
HTML and the PDF, and `pitch_pptx.py` fails on it: cut words, never shrink the type. Open the PDF and the PPTX and
look at every page before calling it done.

The built decks are committed in `build/`, so the team can open them from GitHub. Rebuild all three after editing
`en.md` or `es.md`, and commit the result. Hand edits in the PPTX are fine for the final touches (the screenshots, a
last word), but they are lost on the next build: put text changes in the `.md` too.

## The look
The game's own (`scripts/ui/kit.gd`, `scripts/ui/horizon.gd`): deep space, the horizon arc from sunrise amber to deep
blue, horizon-blue glass cards, the title as the game shows it. The cover is the credits film's opening, the Earth at
sunrise from NASA Blue Marble and Black Marble [S-gibs-earth]; the other backgrounds are drawn by a script (no longer kept in the repository)
(procedural, no AI images). The HTML and PDF use Inter (the game's type); the PPTX uses Segoe UI, on every Windows PC.

## When the game is complete
1. Take the screenshots each `shot:` frame asks for (`tools/dev/shots.sh`, or play and capture at 1600x900 or larger),
   put them in an `img/` folder beside `en.md` and point the `image:` lines at them, then rebuild.
2. Check that no `TODO` is left in the text (the build lists any it finds).
3. Check every number on the slides against the game and `docs/sources.md` as it is then.
4. `<deck script, removed> --final` and `<deck script, removed> look at both PDFs and PPTXs, upload: the English PDF to the global platform, both to the
   venue's form.
