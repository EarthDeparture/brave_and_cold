# Lookout food preservation

2026-10-07. Baseline `9f3dff6`; branch `codex/food-preservation`; rollback tag `checkpoint/pre-food-preservation-2026-10-07`. Original map, building placement and walking collision remain intact. This is a completed stove preservation slice, followed by the remaining food-production priorities below.

## What the player does

Hunt or fish using the existing systems, cook a portion on the lookout stove, then choose immediate eating or preservation. The original four-portion dryer is bolted to the timber wall between the stove and berth, below the window. Its mesh door opens during loading or collection; loaded portions are visible and disappear on collection. The rack starts empty and grants no food.

Aim at the rack and hold E to slice cooked portions with the hunting knife. The two-second active wait retains the global 50% work-duration multiplier. Ingredients and knife wear commit only at successful completion, after rechecking the stove, knife and available food. Moving, releasing E or taking damage cancels before consumption. Read food preparation notes there for a modal dismissible with Esc/X.

| Cost or result | Delivered rule |
| --- | --- |
| Inputs | Up to four cooked meat/fish portions; raw meat, jerky and canned food excluded |
| Knife | At least 4% condition to start; 1% wear per loaded portion |
| Loading preference | Oldest fraction of shelf life first, with stable item-name tie order |
| Processing | Two game hours of actual stove burn, shared with home heating and boiling |
| Unlit stove | Work pauses; spoilage continues |
| Outputs | One species-specific dried portion per cooked input |
| Energy | Exactly the cooked input's existing calories |
| Mass | Half the cooked portion's existing mass |
| Shelf life | Ten game days at normal rate, reduced by the input's existing spoilage fraction |
| Collection | Completed portions only; pack capacity rechecked individually; uncollected portions remain and age |

The process consumes no additional magical heat budget: the stove already burns fuel continuously. Its useful tradeoff is keeping the fire running during an outing, rather than a separate log payment while the fire is unlit. One lookout log supplies two game hours. At the current new-game 30x clock, the two-hour drying operation takes four real minutes while the world continues. Parallel boiling/heating/drying deliberately makes planning a useful home routine. It is not real-world food-safety guidance or a physical dehydration simulation.

## Food conservation and fixes

`FoodPortion` separates heat progress from wall-clock aging. Before completion, reserved food ages against its source shelf life. Completion maps the consumed fraction to the output shelf life; subsequent elapsed time ages the finished output normally. A long sleep step gives the same outcome as smaller steps, including the moment fuel ends. Food expiring before completion becomes rotten meat rather than being rescued by processing.

Lookout stove portions now age both while cooking and while awaiting collection. Campfires now cook only through their actual fuel remainder, and retain age through loading/collection. Full packs leave fire portions in place instead of creating fresh ground output. Dropped perishables retain age, age while on the ground, restore through saves and spoil normally. Chest transfers already preserved age and continue doing so. The lookout's indoor pantry now uses normal aging; outdoor chests retain their existing 0.35 cold-storage rate.

Freshness still uses the project's existing average age per item stack. Combining portions produces a weighted average; this batch does not introduce individual-food containers or FIFO portion inventories. Existing raw/cooked calories remain unchanged: their previous increase on cooking is an established gameplay abstraction that needs a separate nutrition balance review. Drying does not add another calorie increase.

## Persistence, scope and rollback

New optional `home.preservation` state saves each reserved portion's output ID, remaining work, age and current shelf basis. Inventory/chest age dictionaries already handle new food IDs. Dropped-food age is additive. Legacy saves acquire an empty rack; legacy pending cooked portions begin aging from load onward because their prior age was never recorded. No historical age, food, battery, firewood or elapsed time is invented. Original outbreak deadlines, electrical stock and relay progress retain their meaning.

The old cabin's instant `cook_all()` shortcut remains, but now retains food freshness. It is a known remaining inconsistency with timed lookout/campfire cooking, not a claim that every cooking station is complete. Wildlife yield tables, carcass decay and their current time basis, predator food scent, parasites and population sustainability also need a separate controlled hunting batch. This update does not introduce farming, winter crops, salt acquisition, food poisoning, burning food or a player-built smoker.

Keep the local checkpoint and this batch commit. If returning to the baseline after playing with new food, first run `tools/export_food_rollback.py SOURCE_JSON SEPARATE_COPY_JSON`. It never changes the source or overwrites an existing output. The copy converts dried portions to cooked equivalents with their spent freshness fraction, and moves reserved rack food into lookout provisions. Existing knife/fuel costs stay spent. Carried cooked equivalents are heavier; old code ignores ground-food aging fields. This is an explicit conversion for a separate save, never an automatic edit of a user's active save.

## Asset production and acceptance

Original Blender 5.2/Python metre-scale geometry, deterministic fibre/plate rasters, packed editable sources, exports and hash manifest are retained. No providers, downloads or third-party models. The established local pipeline is used because `game-dev` is unavailable. The rack measures approximately 0.558 x 0.856 x 0.340 m, costs 6,414 triangles with all four portions present, and has five materials/two textures. The dropped portion costs 528 triangles. Four original stock roots and a true door pivot support depletion and animation. Opaque wire geometry avoids transparent-surface sorting.

The initial candidate straddled a window. Renderer review rejected that placement; the accepted rack attaches below the sill. Geometry, actual GLB bounds, packed sources, extracted texture bytes and pivots are independently validated. GPU screenshots review empty/loaded/open/collected stock, original food pickup, readable notes and night/storm lighting. Tests exercise actual hold cancellation, condition changes during work, full-pack behavior, expiry, heat boundaries, long-time steps, storage, save restoration and absence of new collision. See the validation document/receipt for evidence and limits.

## Next bounded batches

1. Unify legacy cabin cooking with authoritative game-clock preparation, saved slots and actual fuel. Measure a complete hunt-to-home meal rather than relying on isolated yield tables. Recheck broken-knife butchery and finite carcass harvesting on actual callbacks.
2. Give hunting a sustainable but costly cadence: persist game-time carcass deterioration, measure animal availability along the route, and make carrying fresh meat meaningfully risky. Tune daily calorie/fuel/water budgets together before adding more recipes.
3. Connect first-week food uncertainty to the story: changed delivery notes, abandoned meal equipment and finite town supplies should reinforce missed dispatch and public broadcasts without requiring the player to hear every clip. Prefer a distinct reason to enter town over more interchangeable repair deliveries.
4. Only then prototype sheltered winter food production. Seed/water/soil containers, adequate light/heat, actual multi-day growth, finite harvests and winter failure need a complete design; outdoor snow crops cannot be a free survival solution.
