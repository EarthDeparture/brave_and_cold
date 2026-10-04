# Walking, hands and lookout supply route — 4 October 2026

Implemented on `codex/locomotion-route-quality`, starting at `9b33977`. No GitHub push. Checkpoint: `checkpoint/pre-locomotion-route-2026-10-04`.

## Movement diagnosis and result

Three issues caused visible jolts. The old slope gate could rotate a rejected walking direction by 34–63 degrees. The distant lookout also returned local/world rounding corrections of 0.06–0.12 mm when nothing collided; normalizing those values into collision normals incorrectly clipped walking velocity. Finally, changing road/terrain camera filters, a hard camera offset clamp and lateral head bob made surface transitions visible.

The lookout now returns the original world coordinates when no contact occurred. The controller ignores corrections below 0.5 mm, preserves input heading, allows a 30 cm step tolerance, and eases steep-slope speed instead of choosing another direction. Authored stairs use the actual next tread rather than probing beyond a landing. Road, trail, snow and ice use a common camera footprint filter with bounded vertical acceleration. Default head bob has no lateral motion. Real wall, tree and bridge contacts remain active.

Bridge rails now share endpoints through bends; previously the individual segment offsets left gaps. Rendered rails and finite capsule contacts use the same endpoints and retain tangential travel from either side.

The final audit covers 544 walks in eight directions. All 424 cases outside bridge barriers have zero repeated steering events. Their maximum camera height second difference is 1.69 mm per 60 Hz frame. A full-world eight-second shoreline trace receives zero ghost corrections and retains its original Z coordinate. The 192 road-route tests at 30/60/120 Hz, both complete 2.56 km road traversals, bridge approaches, creature elevation checks and building entrances pass. Twenty-eight shoreline crossings pass at each frame rate. The lookout staircase ascends and descends all 21.41 m without a blocked frame. Jumping and low-doorway clearance pass.

These measurements cover the reproduced routes and surfaces, rather than every coordinate in the map. Real walls and unwalkable slopes can still stop travel.

## Hands and contact

The original Blender mesh has fuller thenar/hypothenar pads, clearer knuckles, quieter skin creases and softer leather detailing. Individual finger angles fit the existing tools. Excessive distal bends were removed. The trigger finger splays outside the stock, the support thumb arches over it, and the bolt grip pinches the knob. Both mirrored skeletons retain 16 bones, six grips and five volume-preserving morphs per skin. Skin and gloves remain closed single components with normalized weights and valid inverse bind matrices. The triangle budget stays at 27,872 per visible hand.

Checks evaluate the imported, deformed meshes with their live corrective morphs. Shaft contact measures no bare-skin penetration and 0.98 mm glove overlap. Rifle stock profile checks measure at most 0.80 mm skin overlap and 1.73 mm glove overlap, with nearby pad vertices on both hands. The bolt keyframe contacts its knob within the skin/glove tolerance. Contact checks cover the held and bolt key poses; the full chop, aim, recoil, reload and jab sequences are checked for wrist/cuff continuity. Fourteen final bare/gloved poses were reviewed in Godot. Packed original Blender sources and textures are under `tools/blender/generated/hand_refinement`.

## Route presentation and gameplay state

The existing route gains a Kestrel Relay service sign at its junction, a field meter and leads, spare ceramic fuses, paperwork referring to North Ridge Supply, and a more legible radio face. The supply store has its own fascia and winter hours, labeled food and first-aid stock, hardware, folded clothing, a register, ledger and hanging tools. Five town homes gain role and residence plaques. Geography and building placement are retained.

Store search prompts target visible stock. Each existing search removes its corresponding stock group while fixed fixtures remain. Loot tables, inventory flow and save keys remain compatible; restoring a searched store restores its empty shelves. Counters, crates, shelves and barrels have simple collision footprints with tested clear entrance and search aisles. The dressing provides story context; electrical maintenance and scheduled radio broadcasts remain separate gameplay work.

Ten original route GLBs total about 1.9 MB, with grouped meshes, embedded graphics, hash receipts and packed Blender sources. Interior props have bounded visibility ranges. `route_detail=baseline` compares the previous route presentation while preserving the earlier electrical panel; it does not undo movement or hands.

## Validation and rollback

Evidence: `docs/validation/locomotion-route-2026-10-04.json`. In-game images and two fixed-palette 30 FPS walking GIFs are under `brave-and-cold/shots/locomotion-route` (ignored by Git). Imports and the movement, shoreline, water, lookout, jump, road, environment, survival, hand, route-state and baseline-comparison checks pass. Engine shutdown/deprecation warnings remain in logs; final runs contain no GDScript parse failures or test failures. The earlier direction baseline file was overwritten during capture; the report retains final measurements and the original code checkpoint rather than presenting that file as a valid before/after comparison.

Independent commits:

- `e4310d7`: movement, ghost contacts, stairs and bridge rails.
- `7aab86d`: anatomy, item/bolt grips and quieter viewmodel bob.
- `ad75d26`: route identities, original props, physical stock and comparison option.

Revert the relevant commit to roll back a disliked upgrade. For a complete rollback, revert route, hands, then movement. Preserve later work and saves; do not reset the shared checkout over concurrent Claude work.
