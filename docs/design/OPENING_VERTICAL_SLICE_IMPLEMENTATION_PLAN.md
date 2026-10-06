# Opening vertical slice: pacing, story continuity and production

Date: 2026-10-06. Inspected baseline: `edb43c4` on `codex/lookout-radio-opening`.

Status update, 2026-10-06: the P0 pacing candidate and service-log correction are implemented on `codex/opening-pacing`. See [implementation and validation](../validation/OPENING_PACING_IMPLEMENTATION.md) and [measured receipts](../validation/OPENING_PACING_IMPLEMENTATION_2026-10-06.json). P1-P4 remain production specifications. The original baseline findings and calculated comparisons below are retained as historical evidence. The new scripted route measurements are identified separately; an uninterrupted unfamiliar-player opening playthrough is still outstanding.

Read alongside `FIRST_WEEK_PRODUCTION.md` and `ATMOSPHERE_POLISH_IMPLEMENTATION_PLAN.md`. Their completed receipts remain evidence of delivered work; their earlier proposed milestones are not a request to recreate features already present. This document defines the next bounded production batches.

## Experience contract

The player is a visiting power technician living temporarily in the elevated fire lookout while servicing local equipment. The opening starts with ordinary expectations: colleagues answer, deliveries are promised, and home is somewhere the player expects to return. Familiar people and services become unreliable while the lookout becomes a place worth maintaining.

The playable arc is: understand the assignment -> prepare and learn the access route -> make a useful depot expedition -> return and establish an overnight routine -> discover failed support -> assess a changed supply destination -> survive a readable encounter or avoid it -> return and choose an independent survival priority.

The player should finish that arc understanding the landscape, caring about the missing voices, and knowing what to risk on the next outing. More meters, larger asset libraries and a bigger town are not substitutes for completing the arc.

Non-negotiable requirements:

- Preserve existing terrain, road alignment, structure positions, walking clearance and the lookout's defensible respite. New details belong beside existing routes and within existing spaces.
- Keep public broadcasts at 06:00, 12:00, 17:00 and midnight. Dispatch never overlaps their reserved windows. A working carried walkie monitors public and dispatch; the desk receiver remains public-only.
- Missed live transmissions remain missed. No transcript archive, catch-up playback, journal reconstruction or mandatory listening objective.
- World deterioration does not wait for assignment completion, clue collection, location discovery or the player looking away.
- Important survival rules and destination access remain understandable without broadcasts. Physical evidence contributes different information rather than restoring lost dialogue.
- Supplies, completed work, collected objects and issued infected cohorts stay depleted or completed across location transitions and reloads.
- The technician repairs local equipment. That cannot restore the town grid, revive the distant transmitter or magically reconnect the city.
- Use original assets and the existing local Blender/Python/Godot workflow. Keep native sources, export manifests and provenance.

## Verified starting point

Implemented foundations include the elevated home, stove/water/storage/sleep, finite crew cache, authored timber, feeder isolation, replacement relay assignment, local power and charger, dual-monitor walkie, watch, optional personal letter, timed broadcasts, clinic stock/notices and staged infected introduction. Survival includes temperature, calories, hydration, fatigue, maintenance, bleeding/recovery and separate outbreak transmission.

The first-week receipt explicitly identifies remaining human pacing, combat feel and inhabited-town storytelling work. The infected use an articulated node rig with procedural gait; this is not yet a fully deforming character animation set. Radio performances are synthesized development speech.

Baseline arithmetic and exact input hashes are retained in `../validation/OPENING_PACING_BASELINE_2026-10-06.json`. Log files are in ignored `brave-and-cold/shots/opening-plan-2026-10-06/`.

### Pacing findings

The new-run start is Day 1 at 05:30. The current 48x clock produces a 30-real-minute day. The 570.547 m access path takes a nominal 2.972 minutes one way at the player's 3.2 m/s base walking speed; a return along this path alone takes 5.943 minutes. These are distance/speed estimates, not observed journey times. They omit the tower stairs, road-to-depot segment, acceleration, snow, fatigue, carrying burden, stops and exploration.

| Quantity | Current 30-minute day | Candidate 48-minute day |
| --- | ---: | ---: |
| Base clock rate | 48x | 30x |
| Initial 2-hour stove charge | 2.5 real minutes | 4 real minutes |
| One log in the lookout stove | 2.5 real minutes | 4 real minutes |
| Six-log rack, if fed into the stove | 15 real minutes | 24 real minutes |
| Initial stove + six stored logs + two carried logs | 22.5 real minutes | 36 real minutes |
| First infected cohort introduced, not necessarily encountered | 35 real minutes | 56 real minutes |
| Random grid failure, 48-72 elapsed game hours | 60-90 real minutes | 96-144 real minutes |
| Final public signoff | 143.125 real minutes | 229 real minutes |

All event times assume uninterrupted normal-speed awake play, with no pausing or sleep acceleration. Clock changes do not change physical movement speed. The candidate's longer time to full communications loss is a pacing cost, not automatically an improvement.

Current broadcast milestones: first morning starts after 37.5 real seconds; first distant incidents after 14.375 minutes; first midnight update after 23.125 minutes. At the candidate rate these become 60 seconds, 23 minutes and 37 minutes. No requirement is introduced to hear any of them.

At warm walking activity, with no consumption or additional costs, ten real minutes currently consume eight game hours: starting calories go from 2,000 to 440, hydration from 85% to 37%, and fatigue from 0 to 40. Under the arithmetic 48-minute candidate, the same physical walk consumes five game hours: 1,025 kcal, 55% hydration and 25 fatigue remain. Cold, sprinting and work can increase costs; these examples do not simulate actual thermoregulation or a full journey.

The initial lit stove can expire before even the nominal one-way access descent completes. Restocking before departure must be understandable, or starting heat needs adjustment; the first visit cannot rely on a player already knowing the fuel economy. Slowing the clock alone still leaves only four real minutes of initial burn, less than the nominal path return before the depot segment is included.

### Resource budget

Food stock totals 4,250 kcal across home and pack, plus 1,300 kcal in the finite crew cache: 5,550 kcal in these sources. The player's initial 2,000 body calories are separate. Filled water totals 3 L across home, pack and cache. Prepared water uses up to four 0.5 L containers and 20 game minutes of actual stove burn. These totals exclude town/clinic supplies and harvesting.

Initial heat totals 18 game hours only if all eight loose logs are brought to and fed into the stove, in addition to its initial two hours. A full stove accepts 16 game hours, so the player cannot load the entire initial reserve at once. Availability is different from effortless continuous heating.

The home battery is 144 Wh. Lamp + desk receiver + commissioned repeater + the unisolated crew spur draw 28 W, excluding walkie charging. Ideal endurance is 5.14 game hours. Isolating the 6 W spur extends that to 6.55 hours; it does not supply a fully lit eight-hour night. Docking/charging changes these figures. This should become an understandable power choice rather than an unexplained overnight failure.

Commissioning presently provides automatic transfer while the repeater is enabled. Receivers remain independent of that repeater. Do not write or reward the assignment as if it restored public or dispatch transmission. Make its actual benefit clear, and assess whether that benefit sufficiently rewards the first outing before adding further jobs.

## Batch P0: opening observations and pacing decision

Prerequisite defect: the radio diagnostic reaches `LookoutOpening.read_log` and emits a string-formatting error at line 338. The long service-log template has an unescaped literal hydration percentage alongside its task/directions substitutions. Existing assertions still pass because they check for static words, not successful substitutions. Before pacing implementation, correct that narrow presentation defect and verify the actual task and depot directions at every assignment stage, including the medical percentage text. It is recorded here rather than changed during planning.

First produce an uninterrupted current-baseline opening recording using a disposable test session. It must retain real survival, weather, inventory interactions, movement and population updates. Existing stationary GPU captures and seven-day temporal advancement are insufficient for this claim. Never overwrite the user's save slot.

Record separate segments: first orientation, stairs/gate descent, access path, road-to-depot approach, collecting the part, return, installation, preparation and overnight rest. Log active real time, game time, physical distance, supplies used, menu time, optional discoveries, interrupted actions, damage and return stock. Distinguish a familiar developer route from an unfamiliar player's route.

Compare the current day length with the 48-minute candidate only after isolating its compatibility work. The preferred hypothesis is that the longer candidate will permit more observation and fewer interruptions during a physically identical outing. Reject it if it replaces pressure with uneventful travel or excessive waiting for the collapse. Rebalance only the demonstrated pressure points; do not stretch every timer mechanically.

Keep note-reading paused as implemented. Inventory remains live; ensure time, listening and threats remain understandable while it is open. Preserve the accepted 50% reduction in active interaction waits. Game-hour cooking/rest/resource simulation and short real-time action waits are separate systems.

Clock-profile implementation must address radio offsets/captions, actual speech duration versus station reservations, the sleep catch-up divisor, sleep wake boundaries, world deadlines, weather durations and save restoration. Preserve an old save's previous base pace through a versioned default rather than silently changing its remaining reserves. Calendar position and shutdown deadlines must not reroll. Debug acceleration and sleeping must not replay speech skipped during a time advance.

Use constrained, readable initial weather as a candidate only if recordings show that the current first outing can become an unreasonable storm test. After orientation, ordinary uncertainty should resume. A forecast is approximate and must not promise deterministic weather from the current stochastic Weather system.

Proposed first-shift targets, to be adjusted using observed route length:

- Understand the immediate task within two active minutes without reading the full service manual.
- Make a concrete preparation choice within the first five active minutes.
- Complete a useful outing and return within approximately 15-25 active minutes; confirm the actual road segment before treating this as feasible.
- Leave one ordinary first outing and one warm overnight rest possible with sensible preparation, without requiring an unrelated early hunt.
- Limit pure stationary menu/hold work to roughly one quarter of active first-shift time. Travel remains part of gameplay, but an uneventful stretch longer than about two minutes requires an intentional atmosphere or navigation purpose.
- Establish ordinary expectations before local horror. The first local encounter can occur in the following shift; do not require an infected fight to complete the intro.

Deliverable: selected new-run pace, measured resource budget and explicit reasons for each balance adjustment. The 48-minute day remains a candidate until an actual comparison is recorded and reviewed.

## Batch P1: character continuity and authored evidence

Character functions: Elise is the city connection; June is institutional support becoming personal; Mara is a colleague connected to fieldwork and the route; Elliot is the recurring public voice; Sam Roy grounds medical disruption locally. Establish their relationships before expecting a missing name to carry emotional weight. Keep Elise's and Mara's eventual fates uncertain unless a later story decision explicitly resolves them.

Create a continuity ledger for every broadcast and clue: earliest knowledge, speaker's certainty, named location, corroborating evidence, practical relevance and any contradictions. Public speech concerns public events; dispatch concerns crew/service conditions. Some voices should misunderstand or lack information, but inaccuracies need recognizable intent rather than accidental inconsistency.

| Development | Existing signal | New evidence/presentation | Player relevance |
| --- | --- | --- | --- |
| Normal services | Day 1 weather/deliveries/clinic open | Recent work records, ordinary delivery expectation, unattended clinic explained by house calls | Player expects the trip and accommodation to be temporary |
| Distant disruption | Day 1 evening/midnight public reports | City reference and failed contact attempt, if implemented | Personal uncertainty; no survival objective locked behind listening |
| Resupply cancelled | Day 2 dispatch cancellation | Depot delivery slate or dated dispatch record changes | Reassess reserves; crew cache matters |
| Clinic under pressure | Day 2 screening/public warnings | Clear service-yard approach, moved triage equipment, visible treatment overflow traces | Player can understand changed access without radio |
| Mara stops answering | Day 2 evening dispatch; later clinic note | Recognizable crew equipment and an unfinished record near the named junction | Optional investigation with a defined location, no compulsory breadcrumb chain |
| Mains fail | Seeded 48-72-hour deadline | Actual lamp/cabinet/charger state, meaningful local automatic transfer | Preparation pays off without claiming town-grid restoration |
| Services abandoned | Day 3 onward | Unstaffed notices, packed supplies, interrupted work and persistent finite shelves | Supplies available; safety no longer implied by the building's purpose |
| Final silence | Day 4 dispatch end, Day 5 public signoff | Working receivers continue to exist without live content | Independent survival priorities replace external instruction |

The clinic already explains routine absence through house calls. Build on that; do not add a full civilian simulation simply to make the first visit credible. Do not play crowd or conversation loops that imply interactive people standing just outside the player's view when nobody is there.

Reduce repeated survival instructions in later writing. Retain useful early reminders, but let later calls carry changing relationships, uncertainty, interrupted plans and distinct vocal rhythm. Live speech should not monopolize every field interaction.

If attempting city contact becomes an interaction, define the communication service and limits first. The receive-only monitored public/dispatch handset is not automatically a city telephone. A failed attempt can express uncertainty without resolving Elise's fate or becoming another repeatable reward action.

Deliverable: revised original scripts, location/clue ledger and small blockouts of the evidence. Acceptance: the radio-informed and entirely radio-missed versions both make sense, while providing different knowledge.

## Batch P2: persistent location transitions and route production

Work within the existing lookout, three field stops, depot and clinic. Keep their distinct purposes: timber supplies heat; the cache provides limited emergency stock; feeder isolation improves battery endurance; the depot supplies the reserved part; the clinic supplies treatment. Do not add three additional equivalent cabinet errands.

Locations need ordinary-use, disruption and abandonment presentations. Reuse furniture and architecture. Use a few changed records, moved work objects, lighting changes and interrupted activities to make revisits legible. A shared global calendar/state decides deterioration; visit history decides what the player has already observed or collected. Neither should reset the other.

The world timeline advances even while a player remains in a location. Avoid teleporting furniture or supplies in their view. Apply harmless presentation changes naturally; defer disruptive prop swaps until safe visibility/clearance conditions exist without deferring logical power, broadcasts, threats or depletion. Reload must not refill shelves or bypass a persistent outcome. Keep a transition's authored dressing separate from inventory-owned objects.

Preserve current offscreen threat-cohort rules and refuge exclusion. Increasing infection stage must not place an enemy in view, inside the compound or directly on the player. A first planned encounter is a reusable scenario for tuning, not a mandatory invisible trigger that pins the player in place.

Initial original asset roster, sized from the actual scene and interactions rather than guessed from screenshots:

| Asset group | Purpose and production constraints |
| --- | --- |
| Depot delivery slate and shipping kit | Counter/wall-sized records, reusable carton/crate/strapping; reservation case remains accessible; no truck blocking the road |
| Electrical identification/details | Weathered lockout tags, mounting/hardware and cable details fitted to existing cabinets; maintain switch reach and walking clearance |
| Clinic triage/equipment kit | Screening sign, folding stand/chair and selected treatment props; keep both exits and collection shelves usable |
| Crew evidence set | A small distinctive field item plus an unfinished record associated with Mara; reused identifying colours/marks, uncertain outcome |
| Regional signs and landmark details | Legible at intended approach distances in snow and dusk; identity and navigation before decorative density |
| Lookout interaction details | Labels, reachable handles and selected wear/contact refinements; preserve stove direction, doors, stairs and current footprint |

Original Blender production: metre scale, applied transforms, documented bounds, deliberate origins, separate animated parts/pivots, material naming, UVs and mip-safe textures. Block out in Godot before detail work. Share wood/paint/metal/fabric palettes while reserving distinctive weathering for focal objects. Build collision only where player contact requires it; paper, cables and shelf dressing should not become walking obstacles.

Retain native `.blend` sources, seedable generators where appropriate, asset provenance, export hashes and actual in-engine review images. Use the established local toolchain. Higher texture resolution follows screen coverage, not a blanket library upgrade. Distant variants must be reviewed in movement, including visibility transitions and shadows.

Deliverable: a complete authored route with persistent state changes and a bounded original asset package. Acceptance: early, late and repeat visitors see consistent consequences; both clinic exits, the depot counter and tower stairs remain smoothly usable.

## Batch P3: infected and first-person presentation

Upgrade the existing infected art foundation to a deforming skeleton while retaining the current gameplay state machine, population pooling and save identities. Map existing articulated pivots to the new skeleton; keep hit/attack semantics independent from animation replacement. Do not create a second combat implementation for the new rig.

Required initial clips/transitions: idle, walk, turn, investigate, notice, approach, attack wind-up/contact/recovery, stagger, barrier strike and death. Review foot planting, shoulder motion, silhouette and root movement in player-height footage. Consistent joint axes and export orientation are prerequisites. Ordinary movement must not turn into foot sliding; pooled characters must reset animation and damage presentation correctly.

Use one clinic-approach scenario to verify detection, readable danger, avoidance and return. Test unnoticed entry, retreat after detection, successful evasion during attack anticipation, damage/treatment and a return visit with persistent deaths and stock. Audio must accurately communicate nearby threats rather than manufacture enemies that do not exist.

Current infected contact rolls hidden outbreak transmission separately from ordinary infection. Decide how a visible dangerous contact differs from a normal wound; explain uncertainty without displaying a false guaranteed diagnosis. Bandaging stops bleeding, ordinary medicines treat ordinary infection, and those actions cannot suggest that outbreak transmission was cured. Do not silently redesign the accepted infection outcome during an animation batch.

Retain anatomical hand proportions and fitted weapon/tool grips. Improve reach/switch/stove/treatment/drink handling, transitions, contact and clothing consistency. Visual follow-through must not duplicate inventory transactions, extend the accepted work waits or block urgent treatment. First-person and world-prop scales must agree.

Deliverable: one complete, readable danger-and-recovery encounter plus dependable recurring interactions. Acceptance: animation, audio and logical outcomes agree; interrupted actions remain resource-safe.

## Batch P4: coordinated atmosphere, materials and audio finish

Use the existing atmosphere capture tools at the lookout interior/deck, access descent, road junction, depot and clinic. Review clear, overcast, dusk, night and blizzard scenes plus doorway transitions. Establish lighting/material standards before finishing every new prop.

Priority defects from the current forest images: disconnected soft cloud shapes, repetitive close branch textures, thin flat foliage/snow surfaces, overly uniform broad snow slopes and weak ice/shore depth. Improve cloud mass, direct/ambient light, exposure, haze, snow brightness and forest shadow colour as a coherent candidate. A dramatic sky image cannot pass if ordinary ground views become unreadable.

Material production should unify painterly colour ranges, scale, roughness and snow accumulation. Add broad snow-shape variation and localized drift/contact details on the route before adding noisy microtexture. Snow rests on upward-facing/exposed surfaces; sheltered and frequently used places need different accumulation. Correct foliage repetition with silhouette/coverage/material decisions rather than only raising texture size.

Weather presentation uses the existing weather state. Coordinate approaching cloud, wind, flakes, visibility, particle sheltering and sound. Visual tuning must not accidentally change temperature costs, enemy night perception or movement collision. Snow cannot leak indoors; the outside landscape must remain coherent when the player steps through a doorway.

Foley roster: tower stairs/landings, equipment and cables, snow foot contact, clothing/tool handling, stove and kettle, receiver switches and sheltered/exposed wind. Mix the return-home transition as a reward for surviving exposure. Avoid constant loud ambience masking distant threats or broadcast intelligibility.

Define a short performance direction for each recurring radio voice before recording replacements. Keep development speech until a replacement is complete and validated. Changes to script, clip duration and captions are one coherent package; a longer performance must still fit its slot and dispatch reservation.

Deliverable: matched before/after stills and moving clips from repeated gameplay locations, accepted materials/audio and bounded performance evidence. Reject improved stills with flicker, visible card/LOD popping, shadow instability, swimming textures, indoor precipitation or new hitches.

## Implementation boundaries and save compatibility

Pacing centres on `systems/game_clock.gd`, `systems/lookout_assignment.gd`, `world/lookout_opening.gd`, the radio data, survival parameters and the narrow clock/sleep/save integration in `world/game_world.gd`.

Story and locations extend `systems/first_week_story.gd`, `world/first_week_route.gd`, `world/first_week_collapse.gd`, `world/clinic.gd` and their original assets. Reuse existing storage/actions/reading rather than duplicate them. Put new authored location state in focused modules instead of expanding the already large world coordinator with all the presentation logic.

Animation modifies the infected source/runtime presentation and existing viewmodel systems. Atmosphere centres on the current sky/cloud/snowfall/shaders and sound systems. Map rasters, road definitions and unrelated weapon mechanics remain outside these batches.

Give added state a versioned, conservative migration: no free supplies, duplicated issued cohorts, replayed transmissions or rerolled shutdowns. Persist logical state separately from transient playback/animation. Existing save meaning takes precedence over convenient new-run defaults.

## Validation and release order

Sequence: P0 observations/pacing -> P1 continuity/blockouts -> P2 location states/assets -> P3 character/interactions -> P4 coordinated finish -> full opening acceptance. Small visual studies can inform P1/P2, but final material production follows the accepted lighting standard.

Each implementation batch gets a focused branch/checkpoint and separate commits after inspection of the shared checkout. Preserve unrelated Claude/user changes. Do not hard-reset. Revert the relevant commits in reverse dependency order, removing runtime references before removing their assets. Keep comparison baselines and native sources recoverable. No remote push is implied.

Run relevant existing tests and add only meaningful coverage for new behaviour. Use disposable/in-memory save snapshots and separate diagnostic output. Headless tests establish logic and bounded movement assertions; actual rendered moving footage establishes visual quality and player feel.

Acceptance scenarios: assignment completed; assignment ignored; all broadcasts missed; early town visit; late clinic visit; cache exhausted; local power not repaired; backup exhausted; walkie left behind/depleted; overnight stove failure; wounded return; mid-transition save/reload; partial outbreak restoration; legacy save load; blocked/full inventory during collection.

Measure a moving populated route with weather, AI, combat, inventory and saving active at 1080p. Target 60 FPS on the documented GTX 1660/RTX 2060 class; measurements on GTX 1080 Ti do not prove that target. Report median, p95, p99 and individual hitches after warm-up, plus asset/import/save spikes. Existing frozen-camera measurements are baselines with stated limitations.

Completion requires that an unfamiliar player understands their immediate task, makes a meaningful preparation choice, recognizes changed support, can assess and avoid danger, reaches home without collision frustration, and chooses an independent next objective. A technical test pass alone does not close these criteria.

## Evidence gathered for this specification

Godot 4.7.2 existing headless diagnostics, `opening_seed=20261004`, all exit 0:

| Diagnostic | PASS assertions | Result |
| --- | ---: | --- |
| Lookout assignment | 27 | No assertion failures |
| Radio bulletins | 140 | No assertion failures; service-log formatting error recorded |
| First-week core | 33 | No assertion failures |
| First-week story/temporal integration | 38 | No assertion failures |
| Opening traversal | 5 grouped | No assertion failures; 64 free yard cases; local approach waypoint residual 0.238 m |

Total: 243 PASS assertions. The runtime formatting error means this is not error-free opening acceptance. The traversal residual is the test's arrival distance, not a collision-error measurement. It tests the local compound approach, not the entire tower-to-depot journey. Restricted-environment engine-log/certificate-store errors and existing shutdown warnings are retained in the receipt; this is not a leak-free-runtime claim.

P0 implementation update: the service-log substitution defect is corrected, with checks at all four assignment stages and two actual-renderer UI resolutions. New lookout runs use the 48-minute candidate day and eight game hours of initial stove heat; saved runs retain their awake pace and remaining resources. Radio seeking/captions and accelerated sleep use the saved awake pace. The baseline and candidate both complete the same scripted depot/repair/return route in 546.57 active seconds. The candidate returns with 3.45 game hours of heat, 1,122 kcal, 57.8% water and 36.57°C core; the baseline returns with no heat, 444 kcal, 41.5% water and 32.85°C core, without consuming carried supplies on either trip. A separate finite-stock preparation and eight-hour sleep fixture passes. Full values and diagnostic limits are recorded in the implementation receipt.

Outstanding acceptance: record the unfamiliar-player orientation, preparation, optional exploration and first-night experience, then judge whether the slower calendar introduces excessive waiting for collapse. The scripted familiar route uses actual movement, collision and world survival, but direct interaction callbacks and frozen individual entity processing; it is not that human recording or a populated performance benchmark. Do not mark P0 experience acceptance or P1-P4 production complete from these checks.
