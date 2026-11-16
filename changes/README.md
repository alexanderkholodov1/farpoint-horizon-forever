# Change notes

One file per piece, written by the piece itself, so pieces built in parallel never edit the same file. When the
release is made, `tools/dev/release-notes.py` joins them into the release's notes, and the release removes them.

- Name: `<issue>-<short-name>.md`, the same as the piece's branch (`12-rocket-builder.md`).
- First line: `kind: new`, `kind: improvement` or `kind: fix`. Then one or two sentences for a player: what they can
  now do or see, never how the code changed.

```
kind: improvement
On a phone, the chapter cards are readable and the hints name the buttons on screen instead of keys.
```

The kinds help the team decide the release number; they do not decide it.
