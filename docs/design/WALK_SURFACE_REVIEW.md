# Walking surfaces, hands and technician equipment: review

This pass starts at 39d91cb and retains checkpoint/pre-walk-surface-2026-10-04. Work is on codex/walk-surface-polish. The implementation is split into movement/road (fb28c86), hand assets (3b8c822), technician prop (49e7dfc) and a separate evidence commit. No GitHub push is included.

## What caused the walking problems

The player uses a custom Node3D movement controller. Terrain materials do not supply collision to that controller. Previously, the same smoothed terrain height placed both the body and the view. Narrow terrain discontinuities and shoreline corrections could therefore leave the feet above or below their supporting floor while the camera caught up. A measured shoreline spike near (-618, -72) rises roughly 0.37 m across a very short horizontal interval; lagging physical contact was especially inappropriate there.

The road, bridge deck, trail ribbons and lookout access path had visible geometry without matching height queries. The controller could follow the terrain underneath a raised walking surface. Storage chests resolved horizontal overlap at every elevation, forming invisible columns above and below the actual crate. The store ramp started inside the porch's floor region, producing a discontinuous entry. These are distinct defects; a smoother shader cannot correct them.

The new controller places feet on the exact supporting floor and filters the camera separately with a critically damped response. Authored ribbon floor queries interpolate the same triangles used by the rendered geometry. Height-aware crate collision leaves clear space beneath elevated crates. The store ramp now starts at its porch front. Bridge guardrails constrain actors on the deck while height queries during active movement retain the lower floor for actors underneath. Wolves, deer, zombies and population proxies use the road floor as well. Resolved movement drives head bob and activity, so pushing against a wall no longer simulates free walking.

The existing slope gate remains meaningful, including descents toward steep drops. The broad survey did not reproduce sustained baseline stalls across its sampled routes; it did confirm visible jolts and poor foot contact. This review does not attribute every reported bump to a single material or falsely claim to have removed solid objects and cliffs.

## Road shape

The geographic route, bridge elevation, building sites, sign positions, tree transforms, terrain height files and save format are retained. A dedicated road profile fills local troughs, reduces exaggerated lateral camber and smoothly approaches the fixed bridge. Shoulders widen to 6.5 m from the centreline, taper toward the terrain and blend out at the route ends. Bridge shoulders remain inside the deck. Ice repair is activated before building the road mesh so repaired water elevation is accounted for.

This is a smoother remote service route within the existing geography. Its raising profile is limited toward 55% grade, and the unchanged route planner already required steep cell limits. It is not a newly engineered low-grade vehicle road. Road clearance and broader route redesign deserve a separate vehicle pass if driving is introduced.

## Hand and equipment review

The version 6 original Blender hand source refines wrist width, dorsal/volar palm proportions, fingertip pads, glove gathering and reinforced seams. Skin and glove paint remain independently authored. Existing 16-bone native left/right rigs and grip targets are preserved. Five pose-specific corrective morphs maintain bend volume under Godot linear skinning; skeletal and corrective transitions blend together. Each visible hand remains 27,872 triangles, with four shared embedded 2048-square textures. The exported package is 18.22 MB, including both hands, glove variants and corrections.

Close-up review rejected three issues: an excessive rifle wrist offset, a thumb-web mesh inversion and an unhelpful mesh-LOD experiment. The inversion came from thumb ring ordering that did not match the palm opening. Correcting that order and the skin's emergence from the palm removed the visible half-twist. The retained rifle wrist change is a small 6 mm lateral adjustment. Disabling mesh LOD and compression did not solve the defect and was reverted. Final GPU images cover 14 bare/gloved poses across fists, jab, axe rest/strike and rifle carry/aim/bolt operation. Rig tests also retain cuff continuity, mirrored motion, dry fire and work/combat timing.

A new original Blender power panel adds recognizable technician equipment inside the lookout: a weatherproof casing, gasket, hinges, latch, fasteners, meter, physical breakers and authored circuit graphics. It uses 1,806 triangles and four material surfaces, with a 140 m visibility limit. It fits beneath the rear window without adding a floor blocker. This is a visual prop; interactive electrical maintenance, relay operation and scheduled broadcasts are still future gameplay work.

## Verification

Eleven suites pass: full walking surfaces, jumping, shoreline walking, road details, viewmodel, lookout, environment details, atmosphere, frozen water, audio and survival. The full world test completes the entire 2.558 km road in both directions, 192 shorter routes at 30/60/120 FPS, six bridge crossings, all 16 cabin/hut/store entrances in both directions, crate elevation checks and actual wolf/deer/zombie bridge contact. Maximum measured foot-floor error is 0.0000152 m. The maximum camera-step change over those full-world routes is 0.01004 m.

The separate 1,005-case survey includes 438 open-terrain starts and 567 road/shoulder walks. Every sampled route has zero blocked frames. Camera-step change is the difference between successive vertical frame displacements, measured in metres; it is a reproducible jolt metric, not a time-normalized acceleration measure. The before/after runs use matching case positions and frame rates. Open-terrain cases exclude large endpoint gradients; this is a sample of walkable terrain rather than a claim about every cliff or obstacle.

| Sample | Cases | Before p95 camera-step change | After p95 | Reduction |
|---|---:|---:|---:|---:|
| Open terrain, 60 FPS | 438 | 8.21 mm | 2.64 mm | 68% |
| Road, 30/60/120 FPS | 189 | 11.81 mm | 4.89 mm | 59% |
| Shoulders, 30/60/120 FPS | 378 | 7.42 mm | 5.54 mm | 25% |

The shoulder survey retains 11 contour deflections across the complete run near steep banks, without blocked frames. Separate shoreline tests complete 84 crossings with no blocks. Their maximum camera bump is 8.92 mm at 30 FPS, 3.11 mm at 60 FPS and 0.90 mm at 120 FPS. Full lookout ascent and descent pass without blocked frames.

The final full-world rendered walk travels 31.84 m across the diagnosed shoreline section over 840 controller frames, retaining 84 images with normal walking head bob enabled. Its maximum camera-step change is 2.78 mm. The controller/aim/footstep CPU sample is 0.554 ms median and 1.253 ms p99 on this run. These timings exclude the world renderer, AI and screenshot readback; they are not GPU profiling or a horde benchmark. Captures use Godot 4.7.2 Forward+ D3D12, a GTX 1080 Ti, 1600 by 900, seed 20261003 and no creatures for isolated art review. Creature verification covers road spawns and active movement; it does not establish multilevel horde routing or floor-layer persistence in the existing X/Z save representation. Existing Terrain3D deprecation and shutdown resource warnings remain. Accepted captures contain no script or shader errors.

Asset/source hashes, test logs, individual capture hashes and motion-frame hashes are recorded in docs/validation/WALK_SURFACE_RECEIPT.json. The optional game-dev CLI was unavailable; evidence comes from project Python/Blender/Godot tools, without sealed-run or paid-provider claims.

## Recovery

Use road_grade=baseline to review the previous road geometry while retaining corrected walking floors. Existing road_detail=baseline still controls road/sign appearance. detail=baseline hides the new electrical panel with the other detailed presentation assets. The hand revision can be removed independently by reverting 3b8c822; the panel by reverting 49e7dfc. To remove this entire pass while preserving later work, revert its commits in reverse order, using the retained checkpoint as reference. Do not reset the shared checkout or rewind player saves. Keep the movement fixes when evaluating the visual assets unless the movement itself is being reviewed.

## Next priorities

1. Finish recognizable authored interiors along the lookout-to-store route: technician bench/relay equipment, supply storage, store shelving and abandoned human traces. The new panel is the first prop in this kit. Retain walking clearance and reuse current loot/storage interaction systems.
2. Refine the visibly gridded ice shoreline contour and its contact with snow, then review terrain, road and ice from moving cameras. Material detail alone cannot hide stepped silhouettes. Preserve existing lake coverage and authored ice heights.
3. Refine palm paint and tool/weapon surfaces at the actual first-person framing. Check the full animation, item contact and silhouette rather than accepting a still pose or passing bone test as sufficient art approval.
4. Add the technician opening as a bounded playable loop: inspect equipment, make a supply decision, prepare the refuge and travel to a useful destination. Implement world-time broadcasts and infrastructure failure against the existing clock/save systems; the power panel currently has no such mechanic.
5. Review contact shadows, indoor warmth/cool outdoor light and weather transitions at those finished locations. Retain the accepted sky during this pass. Track full-world frame cost with representative creatures before increasing asset density.

## Reproduction

Run tools/walking/generate_baseline.py to reconstruct the diagnostic baseline controller from 39d91cb into the ignored shots folder. Run tests/survey_walking.gd with baseline=1 and report=res://shots/walk-surfaces/baseline.json, then without baseline and report=res://shots/walk-surfaces/candidate.json. Run the 11 suites into shots/walk-surfaces/logs. Capture tests/visual/capture_surface_review.gd with --ai 0 and capture_out=res://shots/walk-surfaces/final. tools/walking/build_review.py verifies evidence hashes, explicit suite results and capture dimensions before assembling review/walking.gif, review/hand-grips.png and the tracked receipt.

Generate the current hand with tools/blender/gen_hand_rig.py and output-dir tools/blender/generated/hand_refinement; validate its GLB and JSON with tools/blender/validate_hand_rig.py, copy them into the runtime viewmodel folder and import in Godot. The editable Blender source includes the corrective shapes and both native skeletons. Generate the panel face with tools/route/generate_panel_face.py in the project Python environment, then its model with tools/blender/gen_field_panel.py in background Blender. Assets and native sources retain original project ownership.
