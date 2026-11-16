# Rocket parts

The builder's parts (issue #6), one glTF each, made by `assets/source/parts.py` from the downloaded models in
`assets/source/vendor/` (not imported by Godot: `.gdignore`) and from our own shapes. Their values live in
`data/parts.json`. Rebuild with `blender -b --factory-startup --python assets/source/parts.py` (add
`-- --render <dir>` for a lineup PNG).

Every part has two empty nodes on its axis, `Attach_Bottom` and `Attach_Top`; the builder puts a part's
`Attach_Bottom` on the `Attach_Top` of the part below. Engines have both at their mount plane, so their nozzles hang
into the interstage or below the rocket. The booster's origin is its base; the builder places the pair beside the core.

| Part | Model | License |
|---|---|---|
| `engine_merlin_x9` | nine copies of "Merlin Engine" by hoahluke [S-merlin-model] under our thrust section | CC BY 4.0 (credit hoahluke) |
| `engine_merlin_vac` | "Merlin 1D Vacuum" by MartianDays [S-mvac-model] | CC BY 4.0 (credit MartianDays) |
| `engine_small_x9`, `engine_small_vac` | "Rocket Nozzle Part" by Zachary [S-nozzle-model], simplified for the web | CC BY 4.0 (credit Zachary) |
| `booster_srb` | NASA's Space Shuttle Solid Rocket Booster [S-srb-model] | Public domain (credit NASA) |
| tanks, interstages, fairings | ours: no source offered them with a usable license (searched 2026-11-14) | MIT |

Downloaded models are scaled to their real sizes: the engines by their nozzle exit (0.92 m and 3.3 m [S-merlin]; the small
engines to fit nine under a 1.2 m stage, our estimate), the booster by its 45.46 m length [S-srb].
