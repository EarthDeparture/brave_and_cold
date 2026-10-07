# Electrical resilience outing

2026-10-07. Implemented on `codex/electrical-fieldwork`, from `4292c60`. Rollback checkpoint: `checkpoint/pre-electrical-fieldwork-2026-10-07`. No remote push. The existing terrain, roads, structure placement and original relay assignment are preserved.

## Player experience delivered

The technician has one optional preparation outing using the existing logging-road stops and North Ridge Supply. The desk's winter service issue introduces it without requiring a live radio bulletin. Mara's counted issue record identifies each location; the depot slate changes from expected delivery to unconfirmed delivery after the first day. This is practical evidence of outside disruption, not a replay of missed broadcasts.

The crew reserve holds one sealed packet: a matched DC fuse and connector pair. Both must fit in the backpack before the issue transaction commits. The packet is physically retained inside the existing crate lid and follows its movement. The logging-road crew-spur cabinet has one spare lead. The existing feeder isolation must be completed with the insulated service kit before the lead can be tested and recovered. Isolation still removes the real 6 W branch load. North Ridge Supply holds one matched winter controller in a fitted case beside, and clear of, the original reserved transfer-relay case.

Claimed stock remains gone after reloading. The empty controller case remains visible, its issue slate records collection, and no stock is replenished by toggling the disconnect. Dropped parts use their original unit meshes and the existing pickup/save path. None of these props introduces another ground pad or walking collider.

At the compound array, a commissioned transfer circuit, insulated service kit, matched controller, sealed connector pair and tested lead permit the optional winter refit. Work takes four active seconds under the existing half-duration rule. Movement, damage, key release, airborne state or opening UI interrupts the existing work runner; incomplete work consumes nothing. On completion the exact ingredients and hardware state are checked again, then the installation commits once. Preceding game time is settled using the old hardware before conversion changes.

The controller can reuse a healthy tested lead already fitted during cable repair. It neither requires a second finite cable nor refunds the installed one. A direct matched refit replaces a failed controller and cable together. Fuse replacement remains a separate, diagnosed transaction using the correctly matched spare; fitting a healthy fuse wastes nothing.

## What the reward means

| Quantity | Standard regulator | Winter regulator |
| --- | ---: | ---: |
| Simulated conversion factor | 78% | 86% |
| Clear noon input from the existing 120 W array | 93.6 W | 103.2 W |
| Home battery capacity | 144 Wh | 144 Wh |
| Empty-reserve restart threshold | 12 Wh | 12 Wh |
| Night generation | 0 W | 0 W |

This is a bounded hardware specification within the game's existing energy model, not a geographic or manufacturer prediction. Conversion improves approximately 10.3%; it does not refill the reserve, add panels, remove panel snow, revive the town grid or reset transmitter deadlines. A little more daylight input helps in cloud, while finite storage and overnight load management remain meaningful. The simpler regulator stays useful if the player skips the outing.

Read power status distinguishes open fuse, failed lead, failed controller, disconnection, incomplete relay, snow obstruction and darkness. The actionable diagnosis and destination appear above the longer conservation instructions. Faults block generation but do not erase existing stored energy. If cable and controller checks both fail, the record explains combined replacement or reuse of the already repaired lead.

Healthy equipment is not randomly damaged by this batch. The repair paths support explicit saved faults and future diagnosed damage, but automatic damage events are deliberately not authored here. Before adding them, establish a visible cause and warning, another finite recovery source where repeated replacement is intended, and a feasible unpowered recovery trip. Repeated arbitrary failures would exhaust the one issued set and turn a useful refuge into a forced delivery treadmill.

## Existing-save policy

New solar fields default to a healthy fuse/lead, standard regulator and no previously installed tested lead. Existing controller faults, snow, energy, switch settings, clock pace, outage deadlines and route positions survive. New issue flags default to unclaimed because this stock did not exist in older saves. Subsequent reloads use the saved flags rather than granting it again. The original zero-charge relay commissioning remains independent of the optional refit.

## Critical next food milestone

The next complete slice should be hunt or fish -> interruptible processing -> one portion cooked using actual stove time -> stored surplus -> spoilage or preservation -> another useful expedition. Audit the existing raw/cooked calorie and mass values first. Venison currently changes from 350 kcal / 0.9 kg raw to 900 kcal / 0.6 kg cooked; do not silently change that economy or duplicate yield while adding props. Decide whether those are digestible-energy abstractions or should become consistent portions, then rebalance all meats and fish together.

For a first preservation implementation, give one bounded vessel or rack a visible capacity, consume exact portions and measured fuel/time, preserve raw/cooked freshness at transfer, and save each pending/finished portion. Heat interruption should pause or fail a clearly defined process. A full pack leaves finished food in the vessel. Collection, reload and repeated timestamps must not duplicate portions or reset their ages. Clarify the existing outdoor chest's cold-rate behavior before adding a second incompatible storage model. Hunt success should yield several choices rather than an unlimited calorie source.

Farming remains later. Winter cultivation requires either seasonal thaw or a genuinely sheltered planter with unfrozen medium, water, heat and light. Prototype one crop and a full growing/harvest/replant cycle before adding a greenhouse, and account for game-day growth offscreen and through sleep. The small electrical refit does not establish an energy budget for electric greenhouse heat or crop lighting. Survey any later structure beside the current road; preserve existing map geometry and lookout escape routes.

## Validation boundary

Runtime diagnostics cover atomic packet capacity, finite issues, isolation, mismatched/missing parts, interruption, stale completion, combined faults, installed-lead reuse, zero charge, timing boundaries and real world reload. The existing fixed-step depot route and a new optional outing use the actual Player controller and world survival simulation. GPU captures inspect the crate lid, counter stock/empty case, cable, live slate and readable diagnosis. Native Blender/GLB/printwork integrity is checked independently.

These checks establish functional and integration evidence. Human exploration, readability while moving, repeat-trip value, sound performance and target-hardware frame time remain separate acceptance activities. No user saves are used by the diagnostics.

## Reversion after playtesting

The checkpoint preserves the pre-change code and original assets. This batch also adds item IDs that older code does not recognize. Before reverting after collecting new parts, preserve the current save and run `tools/export_electrical_rollback.py SOURCE_JSON SEPARATE_OUTPUT_JSON` to make a compatible copy. The tool rejects in-place output and existing output files. It removes only the four new components from inventories, storage and pickups, plus the new issue/solar-upgrade fields. It preserves health, needs, clock, position, normal items, tested original circuit state, reserve energy and outage deadlines. This is an explicit, separate export, never an automatic mutation of the player's save. No real user save has been read or modified during this batch. Revert the isolated commit, then use the preserved pre-change save or the compatible copy; avoid a hard reset of the shared checkout.
