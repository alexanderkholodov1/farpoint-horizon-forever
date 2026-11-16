#!/usr/bin/env bash
# Builds the web game into build/web/ (preset "Web" of export_presets.cfg) with the version taken from git, so the
# version is never written by hand: a release build shows its tag (v0.3.1), any other build shows how far it is from
# the last release (v0.3.1-7-g1a2b3c4: 7 commits after v0.3.1, at commit 1a2b3c4; "-dirty" if files are uncommitted).
# The version is written into project.godot only for the export and put back afterwards.
# Usage: tools/dev/export-web.sh            then serve build/web (e.g. python -m http.server -d build/web 8000)
set -euo pipefail
cd "$(dirname "$0")/../.."
version=$(git describe --tags --dirty --always)
version=${version#v}
backup=$(mktemp)
cp project.godot "$backup"
trap 'cp "$backup" project.godot; rm -f "$backup"' EXIT
sed -i "s|^config/version=.*|config/version=\"$version\"|" project.godot
mkdir -p build/web
bash tools/dev/godot.sh --headless --path . --export-release "Web" build/web/index.html
echo "Built v$version into build/web"
