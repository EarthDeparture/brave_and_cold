# Electrical fieldwork validation

2026-10-07. Baseline `4292c60`, checkpoint `checkpoint/pre-electrical-fieldwork-2026-10-07`, branch `codex/electrical-fieldwork`. Detailed source, native asset, diagnostic, capture and outing digests are in `ELECTRICAL_FIELDWORK_RECEIPT.json`.

## What to playtest

Read **Winter service issue** at the lookout desk, or the crew issue record at the logging-road cache. The original transfer-relay job remains sufficient to commission solar, including at zero battery. For the optional refit: collect the crew fuse/connector packet, isolate the unused crew-spur feeder with the service kit, recover its tested cable, collect the winter controller from the North Ridge Supply counter, then fit it at the compound array. The existing interaction list lets you select nearby actions with the mouse wheel.

Packet collection opens the physical crate lid during work. Cancel to leave the packet and watch the lid close. Finish to remove the issue. The kit and empty fitted controller case should remain believable at player scale; the depot slate should change as the component is signed out and delivery becomes unconfirmed. All new stock stays depleted after saving/reloading. Dropping and recovering a component must not refill its original source.

Check output at similar daylight/cloud/snow conditions before and after fitting. The winter conversion factor is 86% rather than 78%, giving clear-noon input of 103.2 W rather than 93.6 W from the same array. Fitting grants no battery charge. Night still produces zero; snow still obstructs the cells; home restart still waits for 12 Wh. Equipment checks and their repair destination appear near the top of the status modal. No automatic hardware failures are added by this batch.

## Runtime evidence

Ten selected diagnostics pass **557 assertions**, with no selected runtime parse/script errors. The new 49-assertion diagnostic covers: combined packet weight/slot overflow without partial collection; once-only stock; kit/isolation/capacity constraints; exact part fitting; wrong, missing and already-repaired faults; combined cable/controller failure; tested installed-lead reuse; lid opening and cancellation; actual component drop/pickup; movement/damage interruption; stale callbacks; settling preceding hardware time; original zero-charge commissioning; actual solar recovery; scene/stock positions; actual world save/reload; no post-reload stock or energy gifts; and the changed day-two delivery record.

The nine retained diagnostics cover solar recovery, transfer assignment, lookout opening, watch/walkie/door behavior, scheduled public/dispatch radio, first-week survival and story, opening pace/save compatibility, and stair turns. Their final selected logs are under `brave-and-cold/shots/electrical-fieldwork-2026-10-07/`.

Three Python rollback-export tests also pass. They check conservative component removal across pack, storage and dropped items while preserving unrelated saved state; rejection of source/output aliasing and existing output; and rejection of unknown save versions. Only synthetic files in temporary directories are used.

## Actual movement outings

The original fixed-step depot/return route completes in **546.5667 simulated active seconds**, covering **1466.2703 m**, unchanged from the preceding batch. The optional electrical outing completes in **570.5667 seconds**, covering **1493.5539 m**. It traverses the existing stairs, lane, cache shoulder, spur approaches, store counter, compound rack approach and return to the room. The optional subclass uses the actual interaction radius, commits all three issues and verifies the fitted regulator. Its receipt includes every component count and installed/claimed flag at each marked segment.

The optional route returns with approximately **1095 kcal**, **56.85% water**, **36.33 °C core temperature** and **3.25 game hours of stove fuel**, starting with the same ordinary gear and 2000 kcal/85% water baseline. These observations support the initial outing budget without consuming a meal or drink during the diagnostic. Human detours, reading and task discovery will use additional time and supplies.

Both diagnostics use actual `Player._move` at 30 Hz and world survival/weather/population updates. They call interactions directly and freeze other entity animations/processes. They measure simulated active gameplay, not wall-clock test duration or rendering performance. They are not human playthroughs. No user save files are used.

## Native source and rendered review

Seven original Blender assets retain their packed `.blend` sources, GLB exports and a provenance/bounds/hash manifest: matched fuse, sealed connector pair, controller, recovered cable coil, issue packet, fitted controller case and delivery slate. Each is below 6500 triangles; the entire seven-asset library totals 11,770 triangles. The four initially visible field props total 9,216 triangles. All units are metres, embedded printwork matches generated original raster sheets, and shared original timber plus authoring helper digests are recorded. The validator verifies GLB structure, measured triangle counts, source/export hashes, texture embedding/runtime extracted copies, the removable stock node and small-prop dimensions.

The host has no callable `game-dev` CLI. This batch follows the project's established local Blender/Python workflow with independently checked native sources and manifests; it does not claim a canonical CLI package or paid-provider job.

Six final 1600×900 images were captured through Godot's actual Vulkan Forward+ renderer on the GTX 1080 Ti and visually inspected: stocked counter, issued empty case/slate, lid-mounted crew packet, surveyed ground cable, electrical issue modal and controller-fault diagnosis. The first review rejected a hidden crate-floor packet, overprinted live slate text and a diagnosis buried below the longer explanation. The packet now follows the opening lid; live slate ink occupies the printed blank region; cable height is surveyed to terrain; and diagnosis precedes the conservation details. These are scoped equipment/UI checks, not a target-hardware FPS measurement.

## Environment and reversion

The editor import completes, but restricted AppData editor/cache/log access, root-certificate access and the unchanged Terrain3D editor `DoubleSlider._ready` error remain in the import log. Runtime runs have the previously observed shutdown RID/ObjectDB warnings. These are recorded separately from the passing assertions; editor import is not described as a clean editor launch.

Source rollback is preserved by the checkpoint and isolated local commit. For saves containing the four new component IDs, the compatible-copy exporter documented in `docs/design/ELECTRICAL_FIELDWORK.md` is available before reverting code. It never changes the original file. No automatic player-save migration, code rollback, remote push, farming system, greenhouse or random hardware-damage event is performed by this batch.
