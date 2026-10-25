# Zero-charge recovery and compound solar — 2026-10-06

Fixed the empty-battery commissioning deadlock and added an original ground-mounted solar source inside the lookout compound. Branch `codex/solar-recovery`; pre-change tag `checkpoint/pre-solar-recovery-2026-10-06` at `f951ed3`. Local work only; no push.

## Player behaviour

Continue an existing save or start a new game. With the service kit, inspect the ground cabinet, fit the reserved relay and verify the circuit. **Zero home charge no longer blocks verification.** If the mains are already gone, verification arms the backup output and connects solar without granting an instant refill.

The reserve then charges from daylight. The backup output and repeater switches can be off while solar charges. After depletion, the room waits for a 12 Wh reserve before its selected loads resume. Night, clouds and snow remain meaningful; brush snow at the ground array and switch off unnecessary loads. The tower panel and ground charger expose live status, and either offers a readable power modal. Existing saves retain their clock profile, current supplies and outage/transmitter deadlines.

## Evidence

The original `f951ed3` power script was reproduced in an isolated diagnostic: verification failed at zero after mains loss, and a forced stage-3 repair still earned 0 Wh across twelve hours. The replacement regression verifies cold commissioning, zero/no-free-charge, charge with output/repeater off, reserve release, night and slept-through dawn, snow/cloud/controller conditions, long-skip energy accounting, capacities, save round trips, interrupted clearing, real install/verify callbacks, physical lamp/status restoration and an actual legacy world reload retaining the 48x clock.

Nine runtime diagnostics pass with **508 PASS assertions**: solar recovery 29; assignment 27; opening 53; watch/walkie/door 46; radio 141; first-week core 33; first-week story 38; opening pacing 50; stair turns/rail pressure 91. The existing battery-exhaustion checks explicitly disable solar to measure finite stored power without generation. The radio snapshot assertion now permits later save schemas while still checking channel retirement/calendar meaning.

The complete actual-controller scripted depot/repair/return route passes after adding the rack, with no blocked waypoint and repair stage 3. It remains 546.57 simulated active seconds, matching the prior pacing candidate. Its familiar-route/direct-callback/frozen-entity limits remain explicit; this is not human playtesting or a populated performance benchmark. No user save files were used.

Original Blender 5.2 source and two generated print/cell textures are retained. Static validation verifies native/GLB/source/texture hashes, embedded textures, 6,306 triangles, seven materials, eight mesh nodes, separate snow/disconnect nodes and measured bounds. The two-panel rack is approximately 2.43 m wide, 1.96 m high in native mesh extent, with a 1.10 m depth. Surveyed runtime feet connect it to the existing terrain; only its physical rack footprint blocks contact. No road, terrain raster, tower/stair geometry, existing building placement or movement controller was changed.

Actual 1600×900 Vulkan Forward+ GTX 1080 Ti views were inspected: clean array, snow-covered array, recovered desk panel, day power modal and zero-charge night modal. The first flat snow sheet was rejected and replaced with a thicker irregular surface. The rack was moved west to keep the entire cabinet-to-yard corridor clear with player tolerance. This confirms the reviewed views and geometry, not target-hardware FPS or the whole game's visual acceptance.

Restricted-environment Godot log/certificate/editor-cache errors and existing shutdown RID/object warnings remain recorded. Editor import registered the new scripts/assets but also reports the unchanged Terrain3D `DoubleSlider` nil-setting error when Windows editor settings are unavailable; it is not a clean-editor-run claim. Final runtime diagnostics have no script/parse errors. The game-dev CLI is unavailable on this host; production used the established local Blender/Python workflow and project manifests, with no providers or downloads.

Exact input and evidence hashes, all route samples and diagnostic limits are in `SOLAR_RECOVERY_RECEIPT.json`. Local captures/logs are in ignored `brave-and-cold/shots/solar-recovery-2026-10-06/`; the route sampler writes its JSON under `shots/opening-pacing-2026-10-06/solar-candidate-route.json`.

## Next work and reversion

The [solar/food progression plan](../design/SOLAR_AND_SUSTAINABLE_FOOD.md) defines finite fuse/connector/controller/cable expeditions and their persistent installation rules. New parts checkpoints, random equipment failures and farming are not implemented in this batch. Food progression first builds on existing hunting/butchery/cooking and preservation, then a sheltered or seasonal growing space with explicit heat/water/seed costs.

Playtest an existing empty save: finish the cabinet job, inspect reserve status, wait through dawn if necessary, turn off/re-enable output and observe charging, then clear panel snow. Check cabinet, gate and stairs on the same outing. Reject unwanted changes by reverting this batch's local commit after preserving later work; do not hard-reset the shared checkout or replace the user's save. The checkpoint tag retains the exact pre-change version.
