# Local power, useful fieldwork and later food production

2026-10-06. Baseline `f951ed3`; rollback tag `checkpoint/pre-solar-recovery-2026-10-06`; branch `codex/solar-recovery`. The power recovery and first compound solar array below are implemented. Parts expeditions and farming are planned, not implemented. Existing terrain, roads and structure placement are preserved.

## The immediate defect and its resolution

The old ground-cabinet verification required `powered()`. Once mains were gone and the home pack was empty, verification could not complete. Even forcing repair stage 3 supplied no energy: the only charger in the old model used the vanished mains. This was a commissioning deadlock plus a missing generation source, not a visual percentage bug.

The insulated service tester now commissions the replaced circuit at zero home charge. That connects the compound's original two-module 120 W DC array and arms backup output. It grants no charge. Existing empty saves acquire the physical source through a conservative migration and earn energy only as subsequent game time advances. Grid/transmitter deadlines and finite stock do not reset.

Charging is independent of the backup output switch and repeater switch. An empty pack holds outputs off until it has a 12 Wh reserve, then resumes them if the output switch is enabled. This prevents an empty pack continually energizing loads for a fraction of a frame. A separate reserve threshold also makes recovery visible and understandable. If selected loads exceed input, the reserve will still decline: the remedy is load management, not repeating verification.

The existing sun's 06:00–18:00 cycle drives generation, cloud cover reduces input, and accumulated panel snow blocks cells. Snow clearing uses the existing interruptible, halved work wait. Night produces zero energy. Five-game-minute energy slices handle dawn/dusk, snow, home-empty, recovery and portable-full boundaries through long sleeps. The gameplay yield model is not a geographic PV prediction and does not ray trace tree/tower shading.

The tower panel and ground charger expose current input, reserve and recovery state. The power modal explains the switches and what to do next. The repaired cabinet remains local equipment: it never revives the town grid, distant transmitter or missed radio clips.

## Initial budget and choices

| Quantity | Current implementation |
| --- | ---: |
| Home reserve | 144 Wh |
| Cold-start output release | 12 Wh |
| Array nameplate | 120 W |
| Effective clear-noon input, cells exposed | 93.6 W |
| Effective cloudy-noon input at 0.55 overcast | 45.2 W |
| Effective blizzard-noon input at 1.0 overcast | 5.6 W |
| Lamp / public receiver / repeater / unisolated crew spur | 7 / 3 / 12 / 6 W |
| Charging a docked walkie | Up to 6 W |

A continuous clear model day yields approximately 715 Wh before reserve overflow; the cloudy model yields approximately 345 Wh. These are idealized simulated input totals, not guarantees. A 144 Wh store still cannot run a 28 W home load through the entire night. The radio-only reserve, with the repeater/lamp off and crew spur isolated, is much more durable. Keeping every circuit on should not be the default successful strategy. Snow, clouds, charging a depleted walkie and discarded excess midday energy all matter.

The array sits inside the compound, west of the stair structure, beside the existing electrical equipment. Its narrow physical footprint does not occupy the cabinet approach, yard waypoint or gate corridor. Only the rack blocks contact; its discrete feet follow surveyed terrain. No pad or map regrading is introduced. The native Blender source, generated original cell/label textures, GLB and bounds/triangle/hash manifest are retained.

## Next early-game checkpoint batch

Start with one optional resilience expedition after the existing relay assignment, rather than several versions of the same delivery job. Commissioning remains possible with the original reserved relay and service kit. Do not make the player discover a second hidden prerequisite to fix the bug.

1. **Inspect at home.** The charger reports a specific fault class, source input and selected load. Distinguish no daylight, snow obstruction, disconnected circuit, blown protective fuse, damaged cable and failed controller. Night or cloud is not a broken part. Inspection should reveal the useful destination without relying on a missed broadcast.
2. **Small spare at the crew cache.** Add a finite sealed DC fuse/connector packet and a labelled crew issue record to the existing cache. This is a low-distance preparedness choice alongside water/wood, not a second battery refill. Collection must respect pack capacity and persist after reload. It need not be required if the original fuse is healthy.
3. **Controller at North Ridge Supply.** Use the existing service-stock/back-counter area, with a delivery slate and a distinct reserved/replacement component box. Add an original controller/fuse/connector prop family, metre-scale bounds and sockets. A stocked day-one location and a later depleted/disrupted revisit should tell different stories. A replacement improves an identified failure; it is not a generic +power collectible.
4. **Cable recovery at the crew-spur junction.** Reuse the known logging-road feeder location and its maintenance identity. A finite coil can be recovered after safely isolating the unused branch. Make isolation, cable yield and cable installation separate persisted facts; do not give unlimited cable by toggling the disconnect. Leave the walking lane and existing equipment in place.
5. **Bench diagnosis and fitting.** Use the existing service kit and home work area. Reserve materials while work is pending, recheck the exact fault and inputs on completion, and commit one installation transaction. Cancellation, injury or movement spends nothing. A used fuse/controller cannot be refunded by reopening the panel or reloading. Recommissioning neither resets the outage nor fills the pack.

A larger replacement battery is a later expedition requiring a credible heavy, finite part at a service shed or town workshop. The location does not exist yet; survey an additive site beside the current road before authoring it. Weight/transport and the value of keeping the original smaller pack should be established before adding battery capacity.

Do not introduce arbitrary offscreen equipment destruction inside the player's refuge. Initial known damage and visible weather obstruction support planned maintenance. Later failures need a cause, warning and recovery route: exposed connector damage, repeated overload, or poor condition. Never fail the only charger solely because a story timer demands another errand. At least one recovery path must remain feasible without electric light, a charged walkie, live dispatch or an already-operating home circuit.

Acceptance: new and legacy zero-charge saves; commissioning before/after mains loss; night-to-dawn sleep; low-light/cloud/snow; outputs on/off; repeater disabled; depleted/full docked walkie; long time skips; repeated timestamps; interrupted clearing and installation; full inventory; collected/installed component reload; both compound approaches and the stairs remain usable. Actual user playtesting must judge whether the new maintenance choices are engaging instead of repetitive.

## Narrative continuity work alongside those checkpoints

The next authored evidence should support ordinary expectations before its disruption: a recent electrical work record, counted spare packet, expected shipment and named crew sign-out. June's dispatch can acknowledge useful work; Mara's unfinished crew issue record can motivate an optional revisit. The depot delivery slate changes when resupply is cancelled. A player who misses every call should still see the date, contents and practical implications of the record, without receiving a substitute transcript.

These props and clues are the next P1/P2 opening milestones. Establish consistent dates, named junctions and each character's knowledge before generating additional radio speech. Preserve current clips until a complete script/performance/caption replacement is validated. Solar gives the technician a meaningful local success while outside services still fail independently.

## Food progression: improve hunting before adding farming

The current game already has deer/wolf/bear yields, knife/axe butchery differences, meat preparation on fires/stoves, time-based spoilage and fish cooking. Farming should extend those foundations rather than create another unrelated nutrition/inventory loop.

The next food batch should first validate and improve tracking, carcass discovery, a safe butchery window, knife condition, interrupted processing, carrying burden, raw/cooked state, actual stove-fuel time and visible cooked portions. Review finite meat yields against food consumption: cooking currently increases an item's calorie reward substantially. Decide whether that represents safer digestible food or should become portion-based yield; do not silently duplicate mass or calories during an animation pass. Cold storage and preservation should reward a useful successful hunt without supplying infinite food or bypassing spoilage saves.

Outdoor planting into frozen ground would contradict the current winter setting. Later farming needs either a credible seasonal thaw or a small sheltered growing space with light, unfrozen medium, water and heat. Choose the setting deliberately; do not assume a small electrical array can power heating and crop lighting as well as the home. The stove may support a compact propagation area, but heat demand must be measured in the existing fuel economy.

Start with one bounded planter/cold-frame prototype and one crop family. Track seed quantity, planted identity, growth stage, moisture, temperature exposure, disease/condition, yield and timestamps. Advance in game days while offscreen and during sleep; persist the planted instance and harvested outcome. Growth is gradual, not a hold-to-generate-food action. Clearly readable stunted/frozen/ready appearances should help the player diagnose a problem. Retain a portion of viable harvest for seed so the long-term loop has choices; seed collection cannot duplicate plants after reload.

Finite town expeditions can supply original seed packets, soil/compost containers, hand tools, glazing and fittings. Distinct destinations should serve different decisions: depot hardware, a household's seed/storage supplies and a later agricultural/work shed. Do not add a complete industrial greenhouse before the small food/heat/water loop works. A useful progression is emergency canned food → skilled hunting/fishing and preservation → small sheltered cultivation → expanded seasonal self-sufficiency.

Farming acceptance: one full growing/harvest/replant cycle; freeze/drought and recovery; saved/offscreen growth equivalence; failed crop consumes its committed seeds; partial/full-pack harvest leaves remaining produce; no repeat-yield exploitation; heat/water/electricity costs conserved; no greenhouse collision around the lookout stairs or escape routes. These are later-stage specifications, not features included in the solar repair.

## Release and reversion

Keep this repair/solar introduction in a separate local commit, with the pre-change checkpoint above. Preserve unrelated Claude/user work. Revert the commit rather than hard-resetting the shared checkout. No remote push is implied. Validation receipts distinguish baseline reproduction, logic checks, native/static asset integrity, actual rendered views and outstanding human pacing/combat/performance acceptance.
