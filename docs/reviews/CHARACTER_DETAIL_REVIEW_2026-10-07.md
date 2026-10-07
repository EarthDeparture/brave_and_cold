# Character detail and work presentation

Implemented on `codex/opening-quality`, starting from d853ea8. Recovery tag: `checkpoint/pre-character-detail-2026-10-07`. No push. The existing map, player movement collision, action duration, damage timing, finite inventories and save meanings are preserved.

## Delivered

The infected now uses an original continuous winter jacket, shaped facial surface with inset eyes, fitted boot lasts and restrained seam/lacing detail. The old rounded shoulder yoke, assembled cheek/nose volumes and bulbous boot/sole pieces remain in the baseline source for comparison, rather than being overwritten. Four original 512px texture maps provide canvas albedo, tangent normal, roughness and skin paint. Existing green/blue worker variants now retain the imported PBR material instead of replacing it with a flat material. A matching distant proxy uses the correct linear colour palette for the painted sRGB albedo.

The near model is 17,790 triangles, seven material surfaces and about 1.78 m tall; the proxy is 2,192 triangles and one surface. The native packed Blender source is `tools/blender/generated/worker_detail/winter_worker_detail.blend`; authoring is reproducible with `tools/blender/gen_worker_detail.py`. Produced GLB bytes, skin weights, metre dimensions, embedded maps, outward winding, nonzero triangles, budgets, palette values and source hashes are independently checked by `tools/validate_worker_detail.py`. This is the authorized local Blender/Godot workflow; no external assets, providers or spending were used. These are local validation receipts, not a canonical or sealed Game Development Studio package.

The rig deliberately migrates from eleven to thirteen bones: each knee gains an ankle child. The eight logical hip/knee/shoulder/elbow drivers are retained. Gameplay still owns movement, attacks and death. Distance actually travelled advances the gait, each stance captures a world-space foot contact, swing lifts the foot, and two-bone leg solving plus ankle compensation follows the support plane. Full ground solving runs within 20 m; farther actors retain the detailed rig and use the cheaper joint gait without ground probes. Contacts release on a turn, blocked movement, stagger, vault, crawling, sleep, death and pool reuse. This is presentation, not a replacement for navigation or collision. Large drops and abrupt steps remain bounded by leg reach; the grade fixture does not certify every mountainside.

Hammer work now uses a compact dedicated windup, strike, hold and recovery curve with a continuous wrist entry. The original fitted grip socket, attached cuffs and authoritative impact count remain invariant. Bare and gloved hands, axe/rifle stances, weapon manipulation, drinking and treatment continue to use the existing anatomical rig. Work completion/cancellation does not depend on an animation callback.

## Acceptance

474 gameplay/pose checks pass across eight suites; 55 independent asset checks pass. The walking fixture checks actual imported ankle transforms and actual visible sole vertices at 30/60/120 FPS, walking/chase speeds and level/positive/negative grades. It also checks heavy scale, turns, interruption and pooled reuse. Sole-plane error stays below 1.2 mm on the tested grades; stance ankle error is below 0.001 mm. Rest bind error stays below the existing 0.1 mm limit. Attack/collapse deformation is finite and passes the unchanged 2.5x edge-stretch ceiling, including sleepers, crawlers, heavy actors and inclined support.

The first continuous-jacket candidates were rejected for cuff/shoulder weight spikes. Sleeve separation and a continuous, surface-relaxed weight field fixed them; the test threshold was not weakened. A first facial candidate was rejected in headlamp light because it still looked assembled from rounded pieces. It was replaced with a single shaped head/neck surface. The final audit also corrected facial winding and the proxy's colour-space mismatch. A short-stride candidate produced a rapid shuffle; adult stride length and an adaptive hip height replaced it without relaxing the sole/contact limits. Actual engine views include overcast/headlamp rest/attack/face, a walking comparison, bare/gloved work, and the clinic approach and collapse.

Retained evidence is under `docs/reviews/worker-detail-2026-10-07`: comparison images, walking GIF, clinic views, hammer impact, test receipts, asset validation, group timing and seeded moving-world timing. The engine's existing sandbox log/cache/certificate limitations and shutdown RID/ObjectDB warnings remain in raw logs. No runtime script errors or failed assertions are accepted by the review packer. No unfamiliar-player acceptance is claimed.

## Timing scope

The isolated group diagnostic poses 55 actors with sixteen actor centres verified inside the camera frustum at 1920x1080. Three repeats use 120 warmup frames and 240 measured frames for each model. It measures local frame intervals, including presentation and rendering; it has no world terrain or population AI. The full-world fixture separately retains twelve seeded moving cases/repeats, cold entry timing, active counts and frame percentiles. Compare the retained counts and host variability along with timings. These checks do not establish minimum-hardware performance or attribute a hitch to the GPU. Detailed measured results are in `moving-comparison.json` and `group-timing.json`.


Measured median frame intervals (median of three repeats):

| Moving case | Previous runtime | Current runtime | Current P95 range |
| --- | ---: | ---: | ---: |
| logging-forest | 22.130 ms | 24.046 ms | 25.763-26.219 ms |
| town-road | 21.964 ms | 23.818 ms | 25.482-26.109 ms |
| storm-route | 19.601 ms | 21.519 ms | 24.169-26.099 ms |
| clinic-encounter | 17.149 ms | 21.285 ms | 25.874-28.774 ms |

The isolated group sample measured 5.553 ms for the old asset and 6.313 ms for the new asset. Both run the current gait code, without a player, so all 55 actors use precise solving; it isolates model variants under the same presentation path and is deliberately more demanding than the distance-tiered runtime. It is not an old-versus-new runtime comparison.

The measured world regression remains unresolved. Clinic warm hitches above 33 ms increased from two to eight across the three repeats, and the first repeat has 55 active actors versus 56 previously. Limiting precise foot solving to 20 m and caching inverse transforms reduced the worst clinic P95 from 30.312 ms in the preceding unbounded run to 28.774 ms here, but the median did not improve in these runs. Host load was uncontrolled; this is not proof of the optimization's effect. The unbounded group and moving receipts are retained alongside the final results. Do not describe this pass as a performance improvement or a completed frame-budget acceptance. Reproduce baseline and candidate under matched host conditions and investigate terrain/rendering and character costs before expanding population or interiors.

## Reversal

Gameplay/art commits are 6e8083b (worker and planted gait), 6792a76 (hammer), 4aad61b (proxy colour), 162d0b7 (natural stride cadence and adaptive hip height) and 86a5a82 (close-distance ground solving and cached transforms). To undo this pass, revert 86a5a82, then 162d0b7, then 4aad61b, then 6792a76, then 6e8083b. Retained review media can remain. Do not reset the shared checkout or restore older player saves. This removes the new character/rig paths and restores the prior model, gait and hammer presentation without disturbing earlier encounter/route work.

## Next development gates

1. Run the current first shift and first night with an unfamiliar player. Check that they understand their technician role, discover the work log and charging cradle, prepare for the timber/cache/feeder trip, make a carry-capacity choice, and return with fuel/water before shelter support runs low. Reports remain optional and missable. Record confusion, timing and failures; do not add mandatory exposition to compensate for an unclear task or route.
2. Test the first changed town visit: two clinic exits, finite medicine, Sam's changing notice, a readable threat windup, bandaging and a safe return. Review Elise, Mara and Sam's texts together for continuity and information the player could have learned. Directed radio performances should follow this reviewed sequence.
3. Use that session to choose the next environment assets: electrical equipment and route landmark silhouettes, door thresholds, shop/clinic shelf dressing, usable loot readability and interior shelter lighting. Capture the particular player views in matched weather/time. Keep the surveyed roads/trail and existing map layout.
4. Extend character variation and acting deliberately: another recognizable winter outfit, clearer infected hand poses, and smoother gait-to-idle/attack/stagger blending. Keep animation separation from damage and inventory transactions. Refine geometry where the encounter camera exposes it, rather than adding undirected detail everywhere.
5. Investigate remaining world frame spikes with renderer/terrain/host evidence before broad expansion. Farming, additional gun families and a larger town follow the first-shift/first-night/clinic acceptance gate.
