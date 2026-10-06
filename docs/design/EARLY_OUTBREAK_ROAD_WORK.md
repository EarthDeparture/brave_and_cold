# Early outbreak work along the logging route

Status: design plan, 2026-10-05. The medical and firewood fixes accompanying this document are implemented; the new roadside stops below are not yet built.

## What the opening can already support

The technician starts in the elevated lookout with an insulated service kit, finite provisions, a wood stove, snow boiling, cooking, a bed, a rechargeable dual-monitor walkie and independent public desk radio. The ground transfer cabinet already supports inspection, collection of a reserved relay at North Ridge Supply, installation and verification. The established track reaches the road and depot. Tree felling, fallen-trunk splitting, firewood, planks, storage, barricading and save restoration already exist. Roadside electrical dressing should not be mistaken for an implemented network of maintenance jobs.

This gives the player practical work while normal radio reports become unsettling. The opening should advance through ordinary work and increasingly consequential supply decisions. It should remain possible to ignore assignments: the world clock and broadcasts must continue without a quest gate.

## Three authored stops, in priority order

| Stop | Player decision and useful result | Existing support | Work still required |
| --- | --- | --- | --- |
| Timber pull-off near the first track/road junction | Split a finite windfall; bring fuel home now or carry planks onward for reinforcement. An optional return trip competes with daylight, warmth and pack weight. | Axe, falling trees, split-log interactions, saved logs, wood/planks, unified home rack. | Survey the actual route; place a believable windfall outside the walking corridor, a readable crew marker and a flat working patch. Give the authored trunk a persistent identity so it cannot respawn on reload after splitting. Verify interaction reach, clear walking and actual return-trip time. |
| One roadside electrical inspection point | Diagnose and isolate a fault on the local site feeder. Its completed state must visibly change something useful, such as removing an avoidable local load or establishing a correctly labelled safe disconnect. | Service kit, assignment stages, ground cabinet, local backup/load simulation, reading modal, electrical props. | Specify the circuit and measurable consequence before building it; author an inspectable panel, legible fault state, saved one-time result and appropriate feedback. Distinguish local service from the failing town grid. Avoid a second arbitrary relay-fetch quest or a generic repair button. |
| Finite crew cache at a shelter/pull-off | Recover matches, food and first aid, read a dated shift note, then decide whether to continue to the depot or return with supplies. The abandoned work site supplies the first quiet sign that routine has broken down. | Storage chests, supply props, medical items, reading modal, saving. | Author one credible location and clue, budget its finite stock, bind it to persistent loot, check doors/collision and sightlines. It must support a detour without making the main road inaccessible. Do not refill the cache each day. |

Do not place all three at the same junction or evenly space them as collectible markers. Use the timber stop as the near-home fallback, electrical stop as a route landmark and cache as a modest choice of detour. The existing tower, depot and roads remain the anchors; add to them after surveying the route rather than moving the map.

## Day-by-day rhythm

Day 1: read the log, take the charged handset, inspect the ground cabinet, gather fuel on the way toward the reserved relay, then return to commission the local supply. Stoke the stove, boil snow, eat and dock the walkie before resting. A healthy player is maintaining their station; an injured player has a concrete reason to interrupt work for a bandage, food, water and warm rest. Outdoor broadcasts can accompany travel, so being home at every public slot is unnecessary.

Day 2: the expected delivery fails. The finite crew cache becomes a plausible optional supply objective. The electrical inspection teaches the player what their limited local backup actually powers. Bring extra wood, medical supplies and reinforcement material home while ordinary work still feels feasible. Dispatch should acknowledge completed work only if a matching authored state-dependent line exists; current fixed calls should not pretend to react to a job.

Day 3 and later: normal maintenance loses priority as travel becomes dangerous. The player decides whether another timber run or town visit is worth the exposure, conserves electrical loads and strengthens the refuge. Completed opening jobs should leave stocked shelves, a known route and useful equipment. Do not repeatedly resurrect maintenance faults merely to fill the calendar.

These are pacing targets, not new scripted deadlines. Outage variation, weather, injury, missed broadcasts and player choice must still change the experience.

## Fuel and recovery balance to measure

New games now start with six logs in the home rack, two carried logs and two hours already burning: eighteen game hours of total stove fuel if continuously used. Each log contributes two hours. Existing saves keep their original remaining wood. The rack displays twelve logs at most; additional deposited wood remains stored and labelled. The stove refuses a log if there is less than two hours of remaining capacity, consuming neither log nor match.

The smaller reserve establishes a first-day gathering need without forcing the player into town for fuel. It does not yet prove the opening is balanced. Measure a normal walking round trip, tree/split work, warmth loss, food/water consumption and loaded return speed. The near-home option must remain reachable after an injury or missed depot trip. Do not solve pacing by adding collision obstacles, shortening the radio day or quietly spawning replacement stock.

Blood recovery uses the existing health/blood pool: above 900 kcal and 45% water, no active bleeding, fever or hypothermia. Awake recovery is one health point per game hour; warm sleep is up to three. A bandage stops blood loss, consumes one wrap and supplies no immediate refill. This creates meaningful preparation and convalescence without rewarding an eight-hour starvation sleep. A separate wound/blood/shock model and treatment animations are later decisions, not part of this fix.

## Production and acceptance order

1. Survey and measure the existing route, including loaded downhill/uphill traversal. Select candidate stop locations with clear approaches and believable sightlines.
2. Build only the timber pull-off first. Test a fresh game, cancellation, splitting, full backpack, storage replenishment and repeated save/load; depleted timber must remain depleted. Play-test the eighteen-hour fuel budget before adding more chores.
3. Specify the electrical stop's circuit, consequence and saved completion; then author the interaction and visible before/after state. Verify that it neither restores distant public broadcasts nor provides unlimited battery power.
4. Add the finite cache and one readable clue. Review its prop quality, stock budget and route value; avoid visual loot that cannot be taken.
5. Review the whole opening as a player, including ignoring jobs, leaving the walkie docked, travelling during news, returning hurt and sleeping through a slot. Confirm that story progresses and resources remain understandable.

Stop adding opening tasks when they no longer produce a useful resource, a lasting world change, route knowledge or a meaningful risk decision. Weather, food, heat, radio, travel and existing relay work already occupy the player's day. Two or three carefully authored stops will do more for this opening than a broad procedural mission system, extra meters or mandatory task chains.
