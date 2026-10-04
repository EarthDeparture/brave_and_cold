# Environment detail implementation and acceptance

Date: 2026-10-03. Baseline cdc91978c33ec980b8d0dd5192f1e41b523a59ef.
Recovery checkpoint: checkpoint/pre-environment-detail-2026-10-03.
Branch: codex/environment-detail. Shared checkout stays untouched until review and verification.

## Deliverable
A coordinated foreground, surface and weather quality pass in the complete game. Preserve the accepted sky foundation, terrain height/control maps, structure transforms, existing tree transforms/colliders/felling, ice footprint, traversal, survival balance and real player saves. Generated assets are original project work with deterministic seeds, source scripts and byte hashes. No paid generation, external assets or license acceptance.

## Reviewable stages
1. Replace the three spruce model families through an opt-out presentation bank. Budget each near tree at <=4200 triangles, each far at <=900. Retain the old scatter RNG sequence, locations and trunk interaction. Model separate branch, foliage and snow forms, matching far silhouettes. Add restrained wind animation with grounded trunks.
2. Original periodic terrain/material fields: powder, wind crust, exposed rock and forest snow. Preserve the terrain data and use a new presentation asset list. Improve ice with branching fractures, cloudy/frost patches, surface normals and irregular snow cover. Improve footprint compression appearance without changing SnowField rules.
3. Weather presentation: depth layers of snowfall and local blowing powder, safe shelter masking, shared wind/gust phase, breath in cold exposure, broken/cloud-covered lighting distinction, bounded near-ground mist. Keep the five weather state probabilities and survival effects unchanged.
4. Close-up materials: authored timber grain and restrained wear on the lookout; improve hand/glove surface response, cloth and item readability with existing rigs. Review anatomical grip corrections separately before adopting them. Avoid merely subdividing meshes.
5. Ambient context: synchronise gust modulation with Weather; add sparse original timber/window events at the lookout and surface-specific footstep sound where reliable surface identification exists. Preserve threat audibility and creature occlusion.
6. Consolidation: all 20 matched scenes, nearby tree and first-person views, real moving camera clips, active gameplay timing and shoreline/stair/hand/weather/audio checks. Reject failures before integration.

## Acceptance
Each stage needs a visible improvement in the actual player camera, coherent material scale and motion, no geometry/shading/import errors, no new collision obstacles, compatible saves and preserved interactions. Performance is compared with the accepted atmosphere, not the older renderer. Aim for <=15% additional median cost in representative routes and no new recurrent hitches; report actual evidence and revise expensive implementations. Do not label image differences or successful generation as art acceptance.

Godot and Blender are installed. The optional game-dev CLI and adapter are unavailable. Use project-owned capture/benchmark scripts and original asset provenance receipts as a local fallback; do not claim sealed CLI packages or telemetry. The user authorised local implementation and iteration in this request. Production writes go to this isolated worktree; original assets remain untouched.

## Recovery
Revert only this enhancement pass's commits, newest first, after preserving intervening shared work. Never reset the shared checkout or rewind player saves. Retain the separate atmosphere recovery tag as well. Reimport and verify the restored presentation. Developer option detail=baseline will preserve the accepted atmosphere while comparing the old foreground assets/effects.

## Reviewed decisions

The production pass retained the accepted sky/cloud/lighting foundation. Its clear, broken-cloud, dusk, night and storm states already give the materials the required distinct lighting. Weather additions are snowfall depth, wind-carried ground powder and cold breath; regional haze continues through AtmosphereRig.

Rejected geometry included sparse smooth foliage volumes, oversized needle patterns, and a distance setting that exposed coarse crowns beside the camera. The final bank uses three near/far botanical crown families at the original 140 m chunk distance. Fine needle alpha textures have mipmaps; tree positions and physics do not depend on the presentation bank.

The first-person work is original sleeve geometry and skin/glove/item surface tuning on the existing rig. Hand anatomy is unchanged in this pass. Detailed thumb/palm silhouette revisions remain a separate art review with the current animation contracts retained.

Wood grain is restricted by the lookout's authored vertex palette so blue cloth and metal surfaces do not inherit it. Additional lighting/fog changes were unnecessary after reviewing the new materials. The full validation and measured results are in ENVIRONMENT_DETAIL_REVIEW.md.
