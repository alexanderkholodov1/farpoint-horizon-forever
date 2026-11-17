# Music (C7, #12)

- "Horizon", our own piece: 84 bpm in D, four chords (Dmaj9, Bm9, Gmaj9, A6sus2), a detuned pad under a filter that
  breathes, a sub bass and a pentatonic bell melody, in a long hall; a 46-second loop with no seam. Composed by
  `tools/content/audio/compose_music.py` (numpy, ffmpeg) into `assets/audio/music_horizon.ogg`; no samples, nothing from outside.
- `scripts/ui/music.gd` plays it for the whole game from the menu on: under the menus and the design, louder in the
  credits film, nearly silent in the launch, the trip and the landing. Master bus (the menu's Sound off silences it);
  it pauses while the window is not in front.

The music now follows the moment: a second layer, `assets/audio/music_horizon_drive.ogg` (a pulse, a thump on each beat, a
run of the chord's notes; same length, tempo and chords, composed by the same script), comes in under the piece
during the climb, while an engine burns or is about to, at the braking at the Moon and in the landing, and leaves
in the coast and the menus (`scripts/ui/music.gd`, `_tense`).
