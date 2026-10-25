# Roads and Spacebar jumping: implementation review

The normal player can now make a modest, stamina-limited jump with Spacebar. The existing road receives original winter materials and original Blender roadside assemblies. This pass starts from 9886e7d, on codex/roads-jump, with checkpoint/pre-roads-jump-2026-10-03 retained. No GitHub push is part of this work.

## Movement

The player is a custom Node3D terrain-following controller, rather than a CharacterBody3D. The jump adds vertical ballistic motion to that controller while retaining its bounded movement steps, slope gate, cabin/chest/trunk resolution and height-aware lookout surfaces. Gravity is 16 m/s²; initial vertical speed is 4.6 m/s, producing a 0.661 m maximum rise and about 0.58 s in the air. Each jump costs eight stamina points. Encumbrance reduces height, airborne steering is restrained, and landing has a small camera response and the existing surface-specific footstep/noise system.

There is no second jump in the air or auto-repeat from holding Space. Crouching, exhaustion, insufficient stamina, death, sleeping, struggle, UI and noclip suppress jumping. The existing sleep wake and struggle controls keep Space. Airborne footsteps/trampling stop; landing produces one grounded contact. Held work is interrupted. Saves cannot record an airborne state; land before saving from the pause menu. Save formats are unchanged.

Surface queries during a jump use the supporting floor level, so an apex cannot choose another stacked stair flight or pull the player to the terrain under the lookout. Guardrails remain solid. Ceiling and door-header bounds follow the original Blender building dimensions. Horizontal entry under a low header is blocked while the head is too high. Moving uphill jumps contact rising treads rather than passing through them. The existing smooth grounded walking response is retained. This is a controlled jump within the existing custom collision contract; it does not introduce vaulting, a general rigid-body character, or a new fall-damage system.

## Road and sign analysis

The 2.558 km route has 1024 centreline samples, 16368 road triangles, 57 utility poles, 18 signs and one bridge span at points 293–302. Its previous material was flat colour bands with uniformly upward normals and no UVs. Sign faces used plain primitive meshes and floating Label3D text; posts could obscure the lettering, and facing was random. STOP signs occurred on the uninterrupted route.

Metric UVs, generated slope normals/tangents and mipmapped original material fields now supply aggregate, compacted snow, irregular wheel wear, slush colour, small compression ribs and restrained polished patches. Shoulder/end colours blend toward the adjacent powder. Coverage responds modestly to current snowfall; this is visual presentation, not a new accumulation simulation. The shader remains opaque. Mesh positions, route, bridge geometry, exclusion footprint and terrain height/control files stay intact. The original geometry still has coarse bank silhouettes and abrupt road endpoints; material blending alone cannot solve those shapes.

The six original sign assemblies are speed, deer, bear, slippery-road and left/right curves. They use baked bespoke graphics, real plate thickness, a small rim, punched metal posts, mounting saddles, hex bolts and restrained snow on the top lip. Models use 474–482 triangles and four material surfaces each. Signs share imported scenes/materials and have bounded visibility. Their positions and count stay intact, front panels face approaching traffic on the appropriate side, and curve warnings are limited to suitable curve slots. STOP is replaced by a winter road warning. Old global RNG consumption is preserved so later gameplay placement is not changed by the new signage.

Raw terrain sampling along this route exposes local slopes: the 95th percentile is 42.74% grade and the maximum is 87.01%. These are unfiltered lidar/carved-bed sample gradients, not an engineered road-grade measurement; they include bridge-bed samples and small surface fluctuations. The path planner itself needed 28° and 22° cell limits on two segments. This confirms that a visually believable service road needs a dedicated grading review. RoadNet bridge decks also lack their own height-aware Player floor contract, which deserves an actual crossing audit. This pass does not claim to have engineered the road profile or solved bridge movement.

## Rejected iterations

The first road render exposed dark continuous wheel streaks; those were too graphic. Snow initially sat across sign graphics, and curve warnings replaced too many other signs. Both were corrected. A border dithering trial produced visible speckling and was removed. The deer graphic was reduced to fit fully inside its border. Accepted images use opaque, softer road materials and corrected sign mounts/graphics.

## Verification and cost

Ten suites pass: jump, road detail, shore walking, lookout, viewmodel, survival, ice mesh, atmosphere, audio and full environment detail. Actual Spacebar input starts a jump in the complete rendered world, a save attempt is safely refused in the air, and the player lands. Forty-two actual rendered jump frames are retained. Jump height differs by under 1.2 mm at 30/60/120 FPS. Existing shore walking still completes 84 crossings with zero blocked frames and a maximum vertical bump under 1.82 cm; full lookout ascent and descent have no blocked frames.

The road contract verifies identical triangle vertex positions, bridge metadata, route samples, sign anchors and global RNG consumption. All six imported sign models pass geometry/material budgets. Asset/source hashes and tests are recorded in docs/validation/ROADS_JUMP_RECEIPT.json. Eleven matched views cover clear day, overcast, dusk, blizzard, night, near surface and five sign slots. Three repetitions per view measure 120 frames after 30 warm-up frames; screenshot readback is excluded. GTX 1080 Ti, Godot 4.7.2, Forward+ D3D12, 1600×900. Creature counts are zero for the isolated render comparison; these are wall-clock frame observations, not GPU timestamp profiling or a horde benchmark.

| View | Before ms | After ms | Change ms |
|---|---:|---:|---:|
| road-day | 6.441 | 6.660 | +0.219 |
| road-overcast | 7.083 | 7.309 | +0.226 |
| road-dusk | 5.042 | 5.274 | +0.232 |
| road-storm | 7.078 | 7.295 | +0.217 |
| road-night | 6.920 | 7.174 | +0.254 |
| road-surface | 7.110 | 7.281 | +0.171 |
| sign-0 | 9.307 | 9.350 | +0.043 |
| sign-1 | 7.518 | 7.544 | +0.026 |
| sign-2 | 6.131 | 6.288 | +0.157 |
| sign-3 | 5.200 | 5.282 | +0.082 |
| sign-4 | 8.058 | 8.113 | +0.055 |

The road views add about 0.17–0.25 ms. Existing Terrain3D interpolation and shutdown resource warnings persist. No new script/shader errors occur in accepted captures. The optional game-dev CLI was unavailable; production uses project-owned Python/Blender tools and local Godot evidence, with no paid providers or sealed-CLI claims.

## Recovery and next improvements

`road_detail=baseline` selects the previous road/sign appearance while keeping the accepted environment. Use the retained checkpoint and revert this pass's local commits to remove the complete change, preserving any subsequent work. Never reset the shared checkout or rewind player saves. New assets occupy assets/road_detail; their original generators and Blender source are retained.

1. Audit and improve the road profile, transitions/endpoints and actual bridge crossings. Preserve the geographic route and building placement. Make one complete walking route comfortable before adding transport or roadside vehicles.
2. Refine hand anatomy and silhouettes, glove seams and item contact at the actual first-person camera. Close-up hands remain an important visible quality gap; they were not rebuilt by this road/jump pass.
3. Give the lookout-to-town survival route distinctive authored buildings and props: electrical equipment, store fixtures, containers, tools and abandoned human traces. Reuse established collision/loot systems and preserve placements initially. A coherent route should communicate maintenance work, retreat and dwindling supplies through visible objects.
4. Review contact shadows, local indoor lighting, weather transitions and moving vegetation at those finished locations. Retain the accepted sky initially, and make any further changes against matched captures and movement footage.

For each next pass, retain an appearance baseline, compare the same player camera/day/weather, review moving footage and track render cost. Material detail cannot substitute for recognizable silhouettes, grounded placement and readable gameplay.

## Evidence and reproduction

Ignored local evidence lives at brave-and-cold/shots/roads-jump: review/before-after.png, review/signs-before-after.png, jump-film/jump.gif, manifests and test logs. Rebuild textures with tools/roads/generate_road_fields.py and models with tools/blender/gen_road_signs.py in background Blender. Import with Godot, run the tests, then use tests/visual/capture_roads.gd with matching options and repeats=3. tools/roads/build_review.py validates hashes, controls and suite completion before assembling comparison images and receipts.

Primary references used for input handling/material semantics: [Godot InputEventKey](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html) and [Godot spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html). Sign categories are Canadian-inspired, checked against [ICBC's signs and markings chapter](https://www.icbc.com/assets/en/7CsgGUXEIxCwW8xQrqyoLu/drivers3.pdf); graphics are independently authored and do not copy its images.
