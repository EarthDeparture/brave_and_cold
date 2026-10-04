# Grip transitions and route props — 4 October 2026

Implemented on `codex/grip-transition-route-wear`, starting at `c1dcd17`. The shared play-test checkout receives these commits only if its previous HEAD and clean state remain unchanged. No push. Checkpoint: `checkpoint/pre-grip-transition-route-2026-10-04`.

## Rifle hand motion

The fitted trigger and bolt poses were sound, but straight interpolation between them cut the hand through the stock. A 12 cm sideways clearance arc, 3.5 cm lift and temporary partial release now carry the fingers around the receiver. The arc and release vanish at the fitted endpoints. Bare skin and gloves use the same articulated skeleton; corrective morphs ease off while the hand opens. Existing axe, support-hand, aim and work-action timing remain intact.

The imported, deformed right-hand mesh was sampled at 5 ms intervals through the entire bolt sequence, in bare and gloved variants: 282 states per version. Maximum stock-profile overlap fell from 12.61 mm to 1.70 mm. The candidate passes the 3.5 mm soft-contact tolerance; the pre-clearance fixture intentionally fails it. Static held/bolt contact, aim and animation wrist/cuff continuity pass the existing hand suite. This measures stock overlap, rather than claiming exhaustive contact against every receiver triangle.

Thirty-seven matched Godot frames per version show the clearance change at 20 ms animation intervals. The test-only pre-clearance fixture preserves the old rifle motion for repeatable comparison. Captures keep camera, weather, animation time and clothing fixed. The comparison GIF uses one palette across all frames; first/last frames have viewing pauses.

## Original supplies and hardware

Eighteen tins now have cylindrical paper labels, rolled rims, pressed lids and pull tabs. Three original illustrated labels distinguish classic, tomato and maple bean packaging; all remain the existing beans item. This is visual stock variety, with the existing search tables and save format retained. A hammer, forged open-end wrench, insulated screwdriver and serrated pliers replace four identical hanging tools. Wrench and plier silhouettes received a second close-up geometry pass.

Route props have subtle baked vertex patina. An initial Blender MixRGB export washed untextured surfaces white; that candidate was rejected. The final export retains the authored material factors and direct texture links, with neutral multiplicative vertex colors. GLB-byte validation and Godot palette assertions guard against repeating that failure. Existing fixed-prop and three searchable stock groups remain unchanged. Searches remove their corresponding physical stock, save restoration restores emptiness, and entrance/search aisles stay clear.

The store dressing has 19,474 triangles and 22 material primitives, below its 20,000-triangle asset budget. Ten route GLBs total 3,125,948 bytes. Store props retain the existing 85 m visibility limit. Source Blender files include packed images; source, graphic and runtime hashes are recorded. Source hashes use canonical UTF-8/LF text to tolerate Git line-ending conversion; graphic and GLB hashes use exact bytes. Geometry/file budgets are verified; this pass does not establish a new frame-time benchmark.

## Verification and limits

`docs/validation/grip-route-followup-2026-10-04.json` records measurements and log hashes. The hand suite, fine transition sweep, route stock/save/material checks, baseline route option, GLB hash/group/budget validation, native Blender source inspection and shoreline ghost-contact regression pass. The shoreline trace finishes with zero corrections and unchanged Z. Movement and terrain code were not changed by this pass. Existing engine shutdown leak warnings and Blender deprecation warnings remain; final candidate checks have no GDScript parse failures.

Actual Godot captures are under `brave-and-cold/shots/grip-route-followup` (ignored by Git): `reload-comparison.gif`, `props-comparison.jpg`, and the nine final route images, including food/tool close-ups. The route screenshots share named cameras, seed and cloudy-noon setup; time-dependent shader/reflection variation makes them unsuitable for strict pixel-difference claims.

To reproduce, run Godot with `--headless --path brave-and-cold --script res://tests/diagnose_grip_transitions.gd -- detail=winter`; add `baseline=1 report=res://shots/grip-route-followup/grip-before-fine.json` for the intentionally failing old motion. Use `res://tests/test_viewmodel.gd` and `res://tests/test_route_identity.gd` for the gameplay regressions. Run Python on `tools/route/validate_route_assets.py` for source/asset receipts. GPU captures use `res://tests/visual/capture_reload_review.gd` (`baseline=1` optional) and `res://tests/visual/capture_route_review.gd -- ai=0 art_only=1 closeups=1`.

## Independent rollback

- `9806e59`: hand clearance and release, plus the reproducible diagnostic/capture fixture.
- `576f191`: original packaging, hardware geometry, vertex patina, source receipts and material regressions.

Revert the relevant commit to remove a disliked upgrade while preserving subsequent work. Revert route then hands for the complete pass. The checkpoint records the starting state; do not reset the shared checkout over concurrent Claude changes. Review the bolt transition in both glove states and inspect store stock before/after searching during the next play-test.
