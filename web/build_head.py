"""Puts web/room_bridge.js (and the Firebase scripts it needs) into the Web export preset as html/head_include.

Godot's web export copies only index.html, so the bridge travels inside it. Run after editing room_bridge.js:
    python web/build_head.py
It rewrites the html/head_include line of export_presets.cfg and nothing else.
"""
import re

FIREBASE = "10.14.1"   # pinned: the version the bridge was tested with
here = __import__("os").path.dirname(__file__)
js = open(__import__("os").path.join(here, "room_bridge.js"), encoding="utf-8").read()
lines = [ln.strip() for ln in js.splitlines() if ln.strip() and not ln.strip().startswith("//")]
body = " ".join(lines)
head = ('<script src="https://www.gstatic.com/firebasejs/%s/firebase-app-compat.js"></script>'
        '<script src="https://www.gstatic.com/firebasejs/%s/firebase-database-compat.js"></script>'
        '<script>%s</script>' % (FIREBASE, FIREBASE, body))
value = head.replace("\\", "\\\\").replace('"', '\\"')
path = __import__("os").path.join(here, "..", "export_presets.cfg")
cfg = open(path, encoding="utf-8", newline="").read()
cfg, n = re.subn(r'html/head_include=".*"', lambda m: 'html/head_include="%s"' % value, cfg, count=1)
assert n == 1, "html/head_include not found"
open(path, "w", encoding="utf-8", newline="").write(cfg)
print("head_include written,", len(value), "characters")
