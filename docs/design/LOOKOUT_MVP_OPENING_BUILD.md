# Lookout opening: build and play-test plan

Branch: `codex/lookout-mvp-opening`. Local checkpoint: `checkpoint/pre-lookout-mvp-opening-2026-10-04` (`afe9380`). No push.

## Delivered sequence

A new game starts at 07:00 in the elevated lookout, wearing winter layers and carrying a hatchet, service kit and small supplies. Existing saves without an opening block retain their survival mode, inventory and placement. The existing valley, forest, road network and buildings are preserved.

1. Read the service log on the desk; turn the receiver on and choose field dispatch or public radio.
2. Inspect the ground transfer cabinet beside the original Blender relay mast. Inspection needs the service kit.
3. Open the compound gate. Follow the existing logging track to the road and North Ridge Supply (about 542 m straight-line; the log gives the actual bearing).
4. Collect the reserved relay case at the store counter. It is independent of random store loot and stays put if the backpack is full.
5. Return, install, then verify under local power. Interrupted work consumes no part; completion and collection cannot be duplicated.
6. Commissioning restores later field dispatch and arms automatic battery transfer. It cannot restore the town grid or distant transmitter.
7. Stock the stove, boil snow, cook hunted food, transfer provisions and sleep in the elevated bed. Rest retains hunger, cold, bleeding and injury rules. The closed ground perimeter blocks player and creature capsules; the upper lookout remains defensible.

All timed interactions use the existing 50% duration multiplier. Gate and electrical switches are immediate. Existing cabins remain usable.

## Collapse and power

The mains fail after a saved, seeded 48–72 game hours. Public broadcasting continues on independent transmitter reserve for another 36–60 hours. Eight original broadcasts tell the story through routine work traffic, abnormal incidents, attacks, confirmed reanimation, regional outages, isolation and final silence. Each airs once. Tuning late seeks into elapsed audio; leaving, switching off or sleeping skips it. There is no replay backlog, and private/local repairs cannot revive a dead public transmitter.

The local battery holds 144 Wh. The lamp uses 7 W, receiver 3 W and commissioned repeater 12 W. While mains are alive it charges at 24 W. Manual backup works without completed commissioning; automatic transfer requires the commissioned, enabled relay and its armed control. Turn off the lamp/repeater to conserve charge. A receiver alone lasts approximately 48 game hours from full charge. Electrical state changes actual lights and radio availability.

The home begins with 12 loose logs, 2 carried logs and 2 stove hours; each log burns for 2 hours, with a 16-hour stove cap. Relighting uses a match. The pantry contains four beans, two jerky, four matches and two bandages; these stocks persist and never refill on loading. Cooking progresses only for actual remaining burn time. The stove's heat and shelter apply to the upper room, not actors beneath it.

The existing zombie population is introduced once at hour 28 (250 by default; developer count overrides preserved). Placement respects a 120 m exclusion around the player's position at disruption, including interior sleepers. Pool reuse also prevents materialization inside the closed refuge. No friendly-town NPC simulation is implied by this opening.

## Asset production and visual decisions

Four original Blender models: relay station, home detail, reserved relay case and mesh gate. Native `.blend` sources and reproducible Python generators are included. Graphics are original project writing and procedural woven fabric. Embedded textures and binary/source hashes are recorded in `assets/lookout_opening/manifest.json`; each model is below 20,000 triangles. Cabinet shoes are grounded with adaptive piers, and the fence follows existing terrain without flattening or inserting a walkable pad.

Visual iterations corrected intersecting bedding, restored its face winding, added a rounded pillow, refined lattice wire into diamonds, aligned the gate to the actual logging track, moved the cabinet indicator off its text, and corrected the stove's direct light with a small motivated warm bounce. Electrical light and flame heat remain separate. The debug monitor is hidden by default for the opening; F3 remains available.

Broadcast WAVs use original text synthesized locally with Windows System.Speech, then band-limited, compressed and mixed with seeded low hiss. They are development performances, not final directed voice acting. Synthesis and processing scripts, clip hashes and provenance are included. Existing fire audio is reused spatially at the stove.

## Acceptance and evidence

Run the assignment, full opening/save, real traversal, tower, jump, shoreline, walking-surface, survival and route-identity tests. Preserve the user's real save: tests use in-memory snapshots and `SaveGame.pending`, without writing it. Visual review runs the actual Godot renderer with deterministic views, including mains, manual backup, stove-only night, original/new bedding, relay cabinet, gate, parts case and live captions. See `docs/validation/LOOKOUT_MVP_OPENING_VALIDATION.md` for results.

## Next production batches

1. **First expedition readability:** stronger destination silhouettes, a compact medical building and scavenging props with actual stock, plus entrance/interior lighting and consistent materials. Each new building must offer a distinct survival purpose and fit the existing route.
2. **Threat presentation:** authored zombie silhouettes/clothing, movement and hit reactions; then footsteps, spatial moans and occlusion. Validate chase, noise, light detection and doorway traversal before adding larger groups.
3. **Interaction polish:** maintenance hand/tool poses, stove and food handling, visible per-item pantry depletion, receiver tuning feedback and readable storage/item presentation. Reuse the existing anatomical rig and grips.
4. **Survival balance:** tune first-night fuel, food/water pressure, expedition duration and sleep/illness consequences through complete runs. Avoid expanding crafting before this loop is engaging.
5. **Visual consistency and performance:** finish one route with coherent snow cover, contact detail, timber/metal variation, weather visibility and day/night exposure; profile that populated route before extending the map or adding global effects.

This package closes the opening/home/maintenance/power/radio sequence. It does not implement the entire future town, new enemy rigs, final performances or a full campaign.

## Reversion

Before integration the shared play-test checkout is checked for concurrent changes. Keep the implementation commits and original checkpoint. Revert the gameplay integration before the asset commit so no resources are removed while still referenced. `opening=survival` is available for developer comparison; normal new games use the assignment. Prefer a local revert commit over resetting a shared working tree, preserving any subsequent Claude/user work.
