# Change notes

One file per piece, written by the piece itself, so pieces built in parallel never edit the same file. When the team
has chosen the release's number, `python tools/dev/release-notes.py --release vA.B.C` writes them into
`CHANGELOG.md` as that version's section and removes them (`docs/guides/releasing.md`).

- Name: `<short-name>.md`, the short name of the piece's branch (`from-v0.3.0/phone-layout` → `phone-layout.md`).
- First lines: `kind: new`, `kind: improvement` or `kind: fix`, then `issue: <number>`. Then one or two sentences for
  a player: what they can now do or see, never how the code changed.

```
kind: improvement
issue: 6
On a phone, the chapter cards are readable and the hints name the buttons on screen instead of keys.
```

A piece that changes nothing a player sees or does (the repository, its checks, its tools) writes no note: the
notes become what players read about the release, and its pull request already records the work.

The kinds help the team decide the release number; they do not decide it.
