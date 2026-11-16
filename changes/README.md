# Change notes

One file per piece, written by the piece itself, so pieces built in parallel never edit the same file. When the
release is made, `tools/dev/release-notes.py` joins them into the release's notes, and the release removes them.

- Name: `<short-name>.md`, the short name of the piece's branch (`from-v0.3.0/phone-layout` → `phone-layout.md`).
- First lines: `kind: new`, `kind: improvement` or `kind: fix`, then `issue: <number>`. Then one or two sentences for
  a player: what they can now do or see, never how the code changed.

```
kind: improvement
issue: 6
On a phone, the chapter cards are readable and the hints name the buttons on screen instead of keys.
```

The kinds help the team decide the release number; they do not decide it.
