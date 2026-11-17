# Mission 1, Apollo 13: the adapter game (issue #45)

- `go("apollo13")` plays it on its own; inside the story the "Your turn" card (`data/story/apollo13.json`, scene
  `mission`, `"play": "apollo13"`) hands over to it and the outro follows when it is done.
- Only the crew's version (team choice, 2026-11-15): the story gives the context; this screen only the task, with
  Rumi and Killa beside the adapter. An emergency against the clock: about two minutes of air, alarm, heartbeat,
  blur in the danger zone. Wayra (Mission Control) reads four steps; the table holds only what the crew had.
  When the air runs out the game is lost and tried again (team choice). The win: slow motion, a flash,
  needle turns around, "Saved!", then NASA's photo of the real "Mail Box" (AS13-62-9004) and up to three stars.
- Rules in `scripts/missions/apollo13/adapter.gd` (tested by `tests/ci/apollo13.gd`), data in
  `data/missions/apollo13.json`. NASA facts only from S-apollo13-nasa and S-apollo13-mailbox; the steps' order and
  the gauge's pace are our simplification, said on screen.
- Next: the flight home (free return, `scripts/flight/transfer.gd`) and re-entry (#67); a card in the Missions screen
  once the campaign (#43) decides where story missions are listed.
