# Lookout MVP opening validation — 2026-10-04

Baseline/checkpoint: `afe938072b8a7dc3789317ad0696ec625df877e2`, `checkpoint/pre-lookout-mvp-opening-2026-10-04`.
Implementation branch: `codex/lookout-mvp-opening`. Commits: `380b57a` assets/audio, `ee5c14e` playable integration, `84b983b` final stove refinement. Local integration only; no push.

## Scope and play test

Start **New Game** for the 07:00 technician assignment. Inspect the ground relay cabinet using the service kit, open the perimeter gate, follow the preserved logging track to North Ridge Supply, collect the reserved case at its counter, return, install and verify under local power. Read the desk log for bearing/distance. Test pantry storage, stove fuel, snow boiling, cooking and elevated bed; tune work/public channels while preparing or resting. Broadcasts are optional, expire once and cannot be replayed. Existing saves without opening state retain their original survival state.

The package closes the opening, usable home, first depot objective, local power and collapse radio loop. New enemy art/animations, expanded medical/town destinations, maintenance hand poses, final voice performances and full-run balance are subsequent production batches described in the build plan.

## Automated results

Godot 4.7.2 Windows console. Tests use in-memory snapshots/`SaveGame.pending`; they never write the player's real save. Final test logs contain no `FAIL`, `SCRIPT ERROR` or `Parse Error`. Some earlier diagnostic runs exposed issues; the table reports the corrected reruns.

| Check | Result | Evidence |
|---|---|---|
| Assignment calendar/power/radio state | 23 assertions; 0 failures | Seed/save stability, battery draw/recharge, auto transfer, source expiry, elapsed tuning and no replay |
| Full opening and fresh-world save restoration | 52 assertions; 0 failures | Equipment, finite stock, cancellation, repeat-proof parts, fuel/cooking, height-aware heat, radio, refuge, elevated drops, legacy save compatibility |
| Real player opening traversal | 5 grouped assertions; 0 failures | Preserved track through open gate to stairs; closed gate stops actual player; 64 free headings retain exact candidate position; 10 fence crossings block in both directions |
| Lookout geometry | 23 assertions; 0 failures | Room/stair/bridge floor queries, supporting structure and boundary behavior |
| Jump | 45 assertions; 0 failures | Tower rail retention, stair landings, low ceilings/headers and forward movement |
| Walking surfaces | 18 grouped assertions; 192 route cases; 0 failures | Full 2.56 km road both directions at 30/60/120 Hz plus entrances/bridges; max contact error 0.00001522 m; max camera step change 0.00607364 m |
| Shoreline and actual tower stairs | 28 shoreline crossings per rate; 0 blocked frames | Max vertical bump: 0.00365232/0.00092094/0.00022654 m at 30/60/120 Hz; actual 21.41 m ascent/descent, 0 blocked frames |
| Survival regressions | 12 assertions; 0 failures | Existing survival checks |
| Route identity regressions | 29 assertions; 0 failures | Existing authored route resources/grips/details |

A localized 1 mm contact skin closes the lookout deck rail creep discovered by the jump regression. It does not increase the global player contact tolerance. Ground perimeter resolution only applies at ground elevation, uses the shared actor contact path, and leaves unobstructed movement bit-exact.

## Original asset checks

Blender 5.2.2 sources and Python generators are included. All GLBs have finite normals/bounds, embedded textures, matching manifest hashes and triangle/accessor counts; their packed native `.blend` files are present. No external/copied game assets or paid generation services were used.

| Runtime asset | Triangles | Mesh surfaces | GLB bytes |
|---|---:|---:|---:|
| Relay station | 4,746 | 10 | 1,591,308 |
| Home detail, bedding and stove | 10,750 | 15 | 2,238,736 |
| Reserved relay case | 710 | 4 | 481,520 |
| Mesh gate | 1,326 | 3 | 511,496 |

Binary hashes/texture receipts live in `brave-and-cold/assets/lookout_opening/manifest.json`. Source hashing normalizes UTF-8/newlines. Godot's generated runtime texture/import metadata is committed with the asset package.

## Render review

Actual Godot Forward+ / D3D12 rendering on the NVIDIA GTX 1080 Ti, 1600 × 900. Full existing forest/terrain retained; AI disabled for reproducible framing. No populated-route frame-time/performance claim is made from these captures. Particle/ember animation varies with render time.

Reviewed before/after bedding; day/night home; mains, stove-only and manual backup lighting; close stove/kettle/grate; chimney plume; relay mast/cabinet; compound entrance; reserved depot case; live caption panel; actual new-game camera with the existing hand rig. Asset iterations corrected blanket winding/intersections, pillow silhouette, gate-track alignment, cabinet indicator placement, stove bevels/hardware and kettle/flue clearance. The final ember uses visible unshaded color as well as emission, and the plume uses small faded billboards rather than a dense column.

Final screenshots and logs are copied into the ignored play-test evidence folder `brave-and-cold/shots/lookout-mvp-opening-2026-10-04`. The repeatable capture script is `brave-and-cold/tests/visual/capture_lookout_opening.gd`.

## Practical limitations

Radio voices are locally synthesized development audio with original writing, filtered/hiss-treated for the receiver. They require final directed performances later. This package has automated and rendered acceptance evidence; a full multi-day human playthrough is still needed to judge pacing, stock pressure and perceived threat. Headless/editor and renderer shutdowns report the project's existing CanvasItem/ObjectDB/resource leak warnings; no claim of leak-free shutdown is made. An existing physics interpolation deprecation warning also remains.

## Safe rollback

Preserve the checkpoint. For these changes alone, revert implementation commits newest first: `84b983b`, `ee5c14e`, then `380b57a`; documentation-only commits can also be reverted if desired. This removes gameplay references before the original assets. Do not hard-reset the shared checkout or overwrite subsequent Claude/user changes; inspect any revert conflicts. The developer `opening=survival` switch supports comparison while keeping the implementation installed.
