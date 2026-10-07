# Hunting and stove cooking

2026-10-07. Successor to food preservation, baseline `d3a9f87`; local branch `codex/hunt-cooking`. Rollback tag: `checkpoint/pre-hunt-cooking-2026-10-07`. No push.

## Player behavior

Older cabin stoves now reserve one raw meat/fish portion per load, up to two occupied skillets. Loading uses the globally halved action duration: one real second. A portion requires 20 game minutes of actual stove burn. Taking food frees its slot; a full backpack leaves food on the stove. The lookout keeps its existing single cooking slot and four drying slots. Water and food can share a lit stove; neither progress consumes extra fuel beyond its existing burn.

Food ages while waiting, including when the fire dies and after cooking completes. Cooking retains the spent fraction of source shelf life. Reserved food, remaining work, fuel and freshness survive saving. Older saves begin with empty cabin pans; they do not grant ingredients or meals. There is no longer a runtime instant inventory-wide cooking function.

Cabin fuel, water and food advance from the world's authoritative elapsed game time, including sleep and dispatch interruptions. Cabin `_process` only drives presentation. This removes the separate cabin speed multiplier and double-clock behavior.

## Harvesting

Carcass meat now accumulates game-time food age at the existing outdoor cold-storage multiplier of 0.35. Its age transfers to harvested inventory portions and any overflow dropped outside. Thirty-hour raw meat consequently expires after approximately 85.7 game hours outdoors under this simplified constant-rate model. Quartering expired meat yields spoiled portions; it cannot reset freshness. Hide/gut/fat availability follows existing rules.

A knife requires at least 1% condition for each step. A hatchet requires 2%, works for meat only, takes twice as long and gives half yield rounded up. Deer/wolf/bear full knife yields remain six/three/ten portions. The exact selected tool is rechecked at completion; dropping or breaking it cannot silently substitute another tool or grant food. Canceled/stale actions spend no resources. Successful steps spend their tool wear and 30 calories once, even when food must stay on the ground. Repeating an already completed step grants nothing.

Saved carcasses retain food age. A legacy save with no food-age record begins tracking on restoration; historical age is not invented. Existing scent/predator carcass timers still use real time. Their behavior was not represented as unified with this new food clock.

## Assets

Original Blender cast-iron skillet: 0.256 m wide, 0.447 m long including handle, 0.049 m tall; 2,196 triangles, three materials and one GLB texture. The independent seared texture is an additional runtime texture. The source packs both original textures. Meat is visible only for reserved portions; raw, seared and spoiled states differ, and collecting empties the pan. Handles have real hanging holes. No walking colliders, floor pads, terrain or road edits were added.

Cabin pans sit 2 mm above the authored 0.85 m stovetop above the floor. The lookout pan uses the rotated stove frame, clear of its chimney and kettle. Visual review rejected the initial buried cabin placement and the cooked surface that retained a raw hue. The current cut is a generic meat/fish portion silhouette; species-specific fillets and portion variations are a subsequent art pass.

## What the controlled outing establishes

The deterministic diagnostic walks from the lookout room down the actual stairs, through the gate, shoots one supplied static deer on the access track using the actual ballistic trace, quarters it, returns to the stove, cooks one portion, dries it and eats it. Total walking distance: 180.01 m. At the default 30 game-seconds/real-second pace, it finishes in 379.17 real seconds / 3.1597 game hours. One round is spent, the knife ends at 98% after quartering and drying, five raw portions remain, and the stove retains 4.84 hours of its initial eight-hour fuel stock. Core temperature recovers on returning indoors. The meal adds up to 900 kcal, constrained by the existing 2,500 kcal cap.

This is an integration measurement with supplied equipment and static controlled prey, not a natural hunt or human playthrough. It proves traversal and resource transitions. It does not establish prey availability, pursuit difficulty, predator response, exploration time or sustainable food balance.

## Next development priorities

1. Measure natural prey encounters along the logging route across several seeds and depleted food states. A functional harvesting system is not sufficient if animals cannot be found, tracked or recovered fairly. Measure ammunition, failed shots, travel exposure and food recovered together.
2. Give the processing window useful parallel work: boil water, service equipment, mend clothes, organize stock and listen to scheduled news. Keep cooking/drying active offscreen rather than requiring the player to stare at the stove.
3. Revisit nutrition and yield together. Existing raw-to-cooked calorie increases are large (six deer portions: 2,100 raw versus 5,400 cooked kcal). This batch preserves that balance; it does not claim cooking conserves energy. Drying continues to conserve cooked calories.
4. Add distinct fish fillets, species cuts, preparation sounds and hand contact, then review them under daylight and firelight. Timed processing and clear stock are prerequisites for those presentation details.
5. Reconcile predator/scavenging timers with game-time decay before balancing multi-day carcass behavior. Weather-driven outdoor preservation and individual portion inventories remain later extensions. Farming remains outside this batch.

## Reverting safely

The checkpoint retains the complete preceding implementation. Before reverting after a test save contains occupied cabin pans, `tools/export_cooking_rollback.py SOURCE COPY` creates a separate compatible JSON copy: unfinished portions return raw with their source age, finished portions return cooked with their retained age, expired portions return spoiled. Returned portions go into lookout provisions, or inventory for legacy saves without a lookout. Existing drying rack stock, spent fuel and tool condition remain. The tool rejects unknown versions/food and refuses to overwrite files. It never edits the original save. Reverting without this copy would discard the newer optional cabin reservation fields. Do not run a Git reset over unrelated work.
