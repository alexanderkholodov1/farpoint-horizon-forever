#!/usr/bin/env bash
# Plays the scripted walkthrough (tests/look/autoshot.tscn) in a window and saves screenshots to shots/.
# Headless runs draw nothing, so this needs a desktop session. Look at every screenshot before calling a change done.
set -euo pipefail
cd "$(dirname "$0")/../.."
bash tools/dev/godot.sh --path . --resolution 1600x900 res://tests/look/autoshot.tscn
ls shots
