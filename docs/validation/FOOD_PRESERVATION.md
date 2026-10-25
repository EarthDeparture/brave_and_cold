# Food preservation validation

2026-10-07; local baseline `9f3dff6`, branch `codex/food-preservation`. Synthetic snapshots only; no user saves read or modified. No push. Exact source, native asset, manifest, log and image hashes are sealed in `FOOD_PRESERVATION_RECEIPT.json` by `tools/record_food_validation.py`.

## Automated behavior

The new diagnostic passes 69 assertions. It covers all six food variants' energy/mass/shelf-life rules; raw input and inadequate knife rejection; four-slot reservation; duplicate loading; heat-only progress; wall-time spoilage; JSON restoration; completed/unfinished expiry; split versus long sleep intervals; full-pack retention; ground age; old-cabin freshness preservation; actual lookout cooking/loading/hold cancellation/door motion/damage/stale tool validation; actual world reload and visual depletion; indoor chest age; actual campfire loading/collection; and collision-free rack import.

The ten retained diagnostics pass a further 557 assertions: electrical fieldwork 49, solar recovery 29, lookout assignment 27, lookout opening 53, watch/walkie/door 46, radio bulletins 141, first-week core 33, first-week story 38, opening pacing 50, stair turns 91. Total 626 gameplay assertions. Native processes exited zero; inspected runtime logs contain no script or parse errors. Three Python tests cover save-copy conversion, preservation of unrelated state, refusal to overwrite and rejection of unknown save versions.

Commands use the installed Godot 4.7.2 console binary, `--headless --path brave-and-cold --script res://tests/test_NAME.gd`. The Blender generation uses the installed 5.2.2 LTS binary with `--background --python tools/blender/gen_food_preservation.py`. Static validation and rollback tests use `tools/terrain/.venv/Scripts/python.exe` with `tools/validate_food_assets.py` and `tools/test_export_food_rollback.py`.

## Assets and renderer

The independent validator checks GLB headers/length, real indexed triangle counts, actual transformed vertex bounds, material/texture budgets, embedded image storage, four stock roots, door pivot, native/export hashes, original graphics and engine-extracted graphics. Rack 6,414 triangles; dropped food 528. Editable Blender sources and generators are tracked. Numbered authoring backups, local build/import logs and runtime shots are ignored; the receipt retains their evidence hashes.

Frozen 1600 x 900 Forward+ captures use the actual game/world assets and player camera on an NVIDIA GTX 1080 Ti. Agent image review inspected empty and loaded rack, open door, collected rack, food pickup and readable modal; it rejected the window-overlapping candidate. Additional night-fire and blizzard-light views assess material readability under the existing environment. Stock and notes captures are not a human survival playtest, animation film, particle benchmark or performance claim. Frozen storm capture assesses sky/light response, not moving snowfall. Existing stairs pass their movement diagnostic; no new floor colliders, pads, roads or terrain edits were introduced.

## Known environmental output and boundaries

Editor import exits zero but emits the pre-existing Terrain3D DoubleSlider nil/int error and restricted editor/log/cache access output. Runtime logs include the existing restricted `user://logs` path, certificate-store output and shutdown RID/ObjectDB warnings; these are distinct from assertions and runtime script errors. This batch does not repair those existing editor/environment diagnostics.

Raw/cooked nutrition balance, legacy cabin cook timing, carcass game-time decay, hunting supply sustainability, individual portion inventories and farming remain next-batch work. Indoor pantry aging is an intentional balance correction; beans/jerky and the initial finite provision quantities are unchanged. New processing retains average-stack freshness and never grants instant fresh preserved food.
