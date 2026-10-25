# Winter environment detail review

Reviewed: 2026-10-03. Implementation: 71b091dc4045ba6755ee3bd2d97c3af369a12468.
Baseline: cdc91978c33ec980b8d0dd5192f1e41b523a59ef.
Branch: codex/environment-detail.
Recovery: checkpoint/pre-environment-detail-2026-10-03.

## What is in the playable build

Three original Blender spruce families replace the former angular near crowns and cone-like distant crowns. The final bank uses detailed needle cutouts, actual supporting branches, separate resting snow caps and tapered trunks. Near models use 2548–2860 triangles; distant models use 306. Wind follows Weather direction, strength and saved phase, with rooted trunks. Scatter positions, variants, physical trunk radii, exclusions and felling behavior remain identical.

A new Terrain3D presentation list supplies original periodic powder, bedrock and forest snow textures with packed height, normal and roughness channels. Wind crust is softer and broader than the previous fine noise. Terrain height/control maps and texture slot IDs remain unchanged. Ice now has irregular two-scale fractures, cloudy areas, bubbles, snow patches and subdued surface normals. Existing shore coverage, top elevation, 0.32 m thickness, underside and side walls remain intact. Footprints gain sharper sole outlines and a compression normal while retaining their pool, lifetime and trample rules.

Snowfall uses 6500 near flakes and 3800 smaller distant flakes, below the former 12000 maximum. Both layers use the same building masks and roof collider. Wind-carried ground powder uses 28 bounded motes, queried against actual terrain/ice; it cannot spawn on an elevated lookout floor or drift through building interiors. Small breath puffs respond to cold air and stop on death. Existing regional fog, cloud and lighting controls remain in use after the material review.

Original Blender parka sleeves add restrained folds and fitted cuffs at the existing wrist origins. Skin and glove normals are softened, fabric stays matte, and wood/steel item response is tuned. Existing hand anatomy, skeletons, grip poses, aim, recoil and work/combat timing remain unchanged. Hand silhouette refinement is a separate art task; this pass does not claim an anatomical rebuild.

Lookout timber receives authored grain, restricted to warm wood colours so cloth and painted metal stay appropriate. Original short wood/ice footstep sounds use reliable floor identification. Sparse lookout creaks/window rattles respond to wind, using a separate audio RNG. Existing threat voices, occlusion and gameplay noise radii are preserved.

## Critical iteration

The first tree generation was rejected for sparse smooth foliage and shelf-like crowns. The next exposed undersized alpha coverage, oversized needle patterns and missing mipmaps. A distance trial was also rejected because chunk-based selection exposed coarse models beside the camera. The accepted bank restores the original 140 m near distance and uses matching botanical near/far crown families with finer needle scale and mipmaps.

The first material import was rejected because the new terrain textures did not match existing mipmap settings. Packed data alpha and mipmaps are now explicitly preserved. A final interior review removed wood grain from blue cloth and metal colours. Capture windows fitted to 1152×648 were excluded from acceptance timing; review scripts now require 1600×900.

## Verification

Eight suites pass: environment detail, atmosphere/weather save continuity, survival, frozen water, shore walking, fire lookout, candidate viewmodel and audio. The detail contract compares both forest banks against the same completed exclusion snapshot: all 114022 instance transforms, variant assignments, trunk positions/radii and felling metadata match.

At 30/60/120 FPS, 84 shoreline crossings produced zero blocked frames; maximum vertical bump remained under 1.82 cm. Full lookout ascent and descent had zero blocked frames. The candidate sleeve/material rig passed complete hatchet, rifle aim/recoil/bolt and fist checks. Thumb target error was 0.236 mm; mirrored joint error was zero.

The audio test previously read QOA compressed bytes as signed PCM, producing false clipping/loop failures. It now measures uncompressed sources, validates imported duration and loop frame counts, checks the four new sounds and exits nonzero on failure. [Godot AudioStreamWAV documentation](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html) describes the distinct PCM and compressed formats.

The local review verifies 21 asset byte hashes, 20 matched camera/weather/time views and five additional tree views. It retains actual bare rifle/gloved hatchet views and 40 real moving frames per variant. The developer baseline reproduces the old forest view with only 21 changed pixels out of 1440000, mean absolute byte difference 0.00045/255. No new script or shader errors occurred in accepted captures or active runs.

## Measured cost

GTX 1080 Ti, Godot 4.7.2, Forward+ D3D12, 1600×900, four-sample MSAA. Values below are the median of three run medians, with 360 measured frames per run after 60 warm-up frames. Film readback runs are excluded.

| Route | Before ms | After ms | Frame-time change |
|---|---:|---:|---:|
| deck-day | 14.634 | 10.949 | -25.2% |
| forest-overcast | 10.656 | 9.532 | -10.5% |
| shore-dusk | 11.487 | 6.936 | -39.6% |
| shelter-storm | 12.090 | 8.895 | -26.4% |
| forest-night | 11.790 | 11.972 | +1.5% |
| sky-cycle | 9.824 | 5.204 | -47.0% |
| forest-overcast (active gameplay) | 10.357 | 8.808 | -15.0% |

Five isolated routes improved by 10.5–47%; the night forest was within 1.5%. The cheaper packed ice fields contribute to the gains. This is bounded wall-clock frame evidence on this computer, rather than GPU timestamp profiling or a full campaign/horde stress test. The active population case is a gameplay spot check; its AI state is not a deterministic render-only comparison. All raw repeat medians/p99 observations are retained in the manifests and receipt.

Existing Terrain3D interpolation deprecation and editor/exit resource warnings remain. The optional game-dev CLI/adapter was unavailable, so this is explicitly project-owned local capture evidence, not a sealed CLI run bundle.

## Evidence and reproduction

Local evidence: brave-and-cold/shots/environment-detail/review/before-after.png, material-lighting-review.png, all-25-views.png, moving-before-after.gif and receipt.json. Full inputs and source hashes are in before/manifest.json and final-03/manifest.json. The committed machine-readable evidence is docs/validation/ENVIRONMENT_DETAIL_RECEIPT.json.

Asset regeneration is documented in assets/environment_detail/README.md. Capture with tests/visual/capture_atmosphere.gd, atmosphere=winter, detail=winter, detail_reviews=1 and all creature counts zero. Compare detail=baseline with identical options. Benchmark with tests/visual/benchmark_atmosphere.gd, three repeats, matched options and fixed resolution. tools/atmosphere/build_environment_review.py validates the images, inputs, hashes and tests before generating the comparison.

## Recovery and next art review

detail=baseline selects the previous foreground while retaining the accepted atmosphere. For a full rollback, revert this pass's evidence commit first and implementation commit 71b091d second, preserving later work through normal Git conflict resolution. Keep checkpoint/pre-environment-detail-2026-10-03. Never reset the shared checkout or rewind player saves.

Playtest the lake edge, close forest, lookout stairs/deck, sheltered blizzard, and bare/gloved rifle/hatchet transitions. The next focused art reviews should address thumb/palm silhouettes against each held item, distinct building/loot prop identities and vegetation transitions while moving. Use the same matched player camera and performance gates for each iteration.
