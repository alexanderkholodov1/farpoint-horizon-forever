#!/usr/bin/env bash
# Runs Godot 4.7 with the given arguments. Uses $GODOT when set, else `godot` on PATH, else the usual install places.
set -euo pipefail
find_godot() {
  if [ -n "${GODOT:-}" ]; then echo "$GODOT"; return; fi
  if command -v godot >/dev/null 2>&1; then command -v godot; return; fi
  for c in \
    "/c/Program Files/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" \
    "/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" \
    "$HOME/.steam/steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64" \
    "$HOME/.local/share/Steam/steamapps/common/Godot Engine/godot.linuxbsd.editor.x86_64" \
    "$HOME/godot/godot"; do
    if [ -x "$c" ]; then echo "$c"; return; fi
  done
  echo "Godot 4.7 not found: install it or set GODOT to its path" >&2
  exit 1
}
exec "$(find_godot)" "$@"
