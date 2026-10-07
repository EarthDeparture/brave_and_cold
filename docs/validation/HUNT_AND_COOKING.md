# Hunting and cooking validation

2026-10-07; baseline `d3a9f87`, branch `codex/hunt-cooking`. Synthetic state only; no user saves read or modified. Native sources, original Blender assets, diagnostic outputs and render evidence are sealed in `HUNT_AND_COOKING_RECEIPT.json`.

## Gameplay and compatibility

The new diagnostic passes 50 assertions covering occupied-slot limits, exact heat use, wall-time aging, large versus split updates, full-pack collection, hold cancellation, stale fuel/tools, authoritative cabin water/fuel time, knife/axe yields and wear, stale/duplicate harvesting, expired carcasses, capacity-limited carried/spilled age, actual save/reload and visual depletion, old saves and absence of walking colliders. The preceding eleven diagnostics pass 626 further assertions: food preservation 69, electrical fieldwork 49, solar recovery 29, lookout assignment 27, lookout opening 53, watch/walkie/door 46, radio bulletins 141, first-week core 33, first-week story 38, opening pacing 50 and stair turns 91. Total: 676 gameplay assertions. P6 also passes its 13 existing audio/freshness/weight checks, including the corrected cooking expectation. Three Python rollback tests cover reserved-food return, retained unrelated state, version rejection and exclusive output.

Commands use the installed Godot 4.7.2 console binary with `--headless --path brave-and-cold --script res://tests/test_NAME.gd`. The route uses `res://tests/measure_hunt_cooking.gd -- opening_seed=20261004`; P6 uses `--headless --path brave-and-cold -- autostart p6test=1 opening_seed=20261004`. Native processes exit zero and inspected runtime logs contain no script or parse errors. The route completes its actual movement/ballistics/resource loop; precise costs and its controlled-fixture limitations are in the design document and receipt.

## Asset and render evidence

Blender 5.2.2 LTS builds the original native asset through `tools/blender/gen_cooking.py`; `gen_cooking_graphics.py` produces deterministic 512-pixel raw and seared textures. `tools/validate_cooking_assets.py` independently reads GLB bytes, real indexed triangles, transformed vertex bounds, source/export/graphics hashes, material budgets and food/sear roots. No external art or provider job was used.

Eight actual Forward+ 1600 x 900 player-camera views on an NVIDIA GTX 1080 Ti cover empty/raw/cooked/collected cabin pans and raw/cooked/night-fire/spoiled lookout food. Agent inspection rejected the initial buried cabin placement and raw-colored cooked surface. Final views show pans seated on the stoves, handles accessible, chimney/kettle clearance and authoritative stock. Captures freeze simulation/entity processing: they are not human playtests, animation reviews or performance benchmarks. No new walking collision is introduced; the retained stair diagnostic passes.

## Environment and scope

The editor import exits zero with the pre-existing Terrain3D DoubleSlider nil/int error and restricted editor/log/cache output. Runtime output includes the existing restricted user log path, certificate-store messages and shutdown RID/ObjectDB warnings. These are distinct from new script/parse failures, which are absent from accepted runs. No user-facing environmental workaround or new dependency was introduced.

Natural prey availability, moving animal pursuit, predator response, portion nutrition balance and multi-day scent behavior are not validated by the static controlled outing. A generic portion silhouette is currently used for meat/fish. The new functionality is timed cooking/aging and consistent resource transitions, with original in-world cooking assets; broader hunting ecology and farming remain future work.
