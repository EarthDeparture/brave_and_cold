# Atmosphere polish and the next MVP milestones

Status: implementation plan only. No gameplay, rendering, assets or saves changed by this planning task.
Date: 2026-10-03.
Verified baseline: `8a623693988c371a976d6a304151c78cdf4a37ae`.
Local rollback tag: `checkpoint/pre-atmosphere-2026-10-03`.
Reserved candidate branch: `codex/atmosphere-polish`, starting at the baseline.
Shared checkout remains on `codex/lookout-radio-opening`. Git LFS object and pointer verification passed. No push is planned.

## Objective and quality standard

Deliver a more coherent, painterly winter atmosphere, then complete one convincing lookout-to-town survival experience. The target is the consistency and readability of the supplied Long Dark references: controlled colour families, recognisable silhouettes, atmospheric distance, warm refuge lighting and believable transitions.

A brighter scene, more texture detail or more expensive clouds is not evidence of improvement. Assess the whole frame in motion, including hands, nearby branches, snow, ice and interiors. The current hand rigs are functional but their anatomy and poses have not reached the desired art standard. Keep that work visible in the quality backlog.

Preserve the existing map layout, terrain, buildings, tower geometry, stairs, repaired ice coverage and movement support. The first atmosphere pass does not rebalance resources, action times, weather probabilities or enemy behaviour.

## Recovery and collaboration rules

1. Keep the baseline tag fixed. It contains the recent hand, ice, movement and action-duration updates; rejecting atmosphere work must not remove those fixes.
2. Begin implementation in a separate managed worktree from the reserved branch. Claude's shared checkout must not be switched, reset or overwritten. Check for intervening changes before integration.
3. Make a small commit for each reviewable stage. Record its parent, changed paths, screenshots, validation and known limitations. Preserve an accepted checkpoint after each accepted stage.
4. Keep baseline captures separate from candidate captures. Never overwrite the before images. Store camera, resolution, time, weather, wind, seed, cloud phase, rendering settings and commit identity in a capture manifest.
5. Keep a developer comparison option for the old and candidate atmosphere during iteration. Use the same world state for comparisons. If the old presentation cannot remain intact cheaply, compare the two isolated checkouts instead of maintaining a large duplicated renderer.
6. Rejecting the latest isolated stage means returning to the previous accepted candidate checkpoint. After integration, reverse the specific upgrade commits and review the result against any later edits. Do not perform a repository-wide hard reset or bulk file restoration in the shared checkout.
7. Rendering rollback must not rewind player progress. Use separate test saves or a verified backup of the real save before persistence tests. New weather fields must be optional so the baseline game can ignore them. Later story/content changes require their own save-compatibility decision before testing.
8. Before rollback or merge, check for uncommitted work and preserve it. A Git checkpoint does not capture ignored screenshots, caches or a live save, so those require their own handling.
9. After restoring assets, allow Godot to reimport them and verify the exported asset hashes, relevant gameplay checks and comparison scene. Successful Git restoration alone is not the final recovery check.

## Current findings that determine the order

| Finding | Consequence |
| --- | --- |
| `SkyRig` already interpolates day/night colours and weather overrides | Retain the working clock/weather foundation; establish better art targets first. |
| One main light switches between solar and fixed night directions at 05:30 and 18:30 | Review continuity around both boundaries and midnight, not only still images. |
| `CloudLayer` has a fixed lighting offset and fixed real-time drift | Clouds do not follow changing sunlight or weather wind. |
| Clouds are a separate unshaded plane, with distance fading and fog disabled | Horizon appearance and visible cloud colour need explicit review against fog and world lighting. |
| Main-world environment settings differ from the older look-development scene | Use the complete game for acceptance captures; the old harness alone can give misleading results. |
| `Zombie.night_factor` and building night state currently derive from sun energy | Cosmetic brightness tuning can change AI or lamp behaviour. Resolve this dependency before colour experiments. |
| `Weather.to_dict()` stores only state and remaining duration, and the world save omits weather | Existing helpers are insufficient for faithful restoration of a storm or its future sequence. |
| Indoor fog/ambient adjustments affect the shared environment | Looking outside through a window can change the outdoor view; test thresholds and transitions. |

## Immediate atmosphere stages

### A0 — Reproducible baseline and visual targets

Capture the current complete game before editing rendering. Use the actual lookout deck, lakeshore, forest path and an interior looking outside. Establish five matched scenarios:

| State | Proposed artistic target | Main rejection condition |
| --- | --- | --- |
| Clear winter noon | Readable blue shadows, blue sky, soft snow highlights, distinct mountains | Clipped snow, excessive saturation, weak foreground/distance separation |
| Overcast noon | Substantial cloud mass, cooler muted palette, gentle contrast | A uniformly washed-out frame or sharp sunny illumination beneath heavy cloud |
| Dusk | Warm low horizon, cooler foreground, clouds belonging to the sunset palette | Orange applied indiscriminately to every surface or sudden shadow changes |
| Clear night | Recognisable nearby silhouettes and useful local light | Unusable darkness, daylight-like visibility, or misleading moon/shadow direction |
| Blizzard daylight | Low visibility, coherent wind and snowfall, shelter contrast | Arbitrary visual obstruction, indoor snowfall, or missing near navigation cues |

The minimum baseline is 20 still views plus short moving samples. Record additional skyward views and doorway transitions where those expose defects. Keep hands and tools visible in selected images; they are part of the scene's colour and scale judgement.

Use deterministic scenario time and weather. Control cloud phase and wind rather than allowing different random conditions to bias comparisons. A frame difference is diagnostic evidence, not a score for artistic quality.

Measure the same deck-to-ground, forest and shoreline routes on the same hardware/settings. Record frame-time median and 99th percentile after warm-up. Agree on representative reference frames before producing new art.

Gate: baseline captures and performance evidence exist; each target has a concrete visual comparison. No rendering changes in this stage.

### A1 — Protect behaviour and tune the basic light relationships

Preserve the existing gameplay day/night response while separating it from the render intensity we will tune. Check zombie perception/night values and building lamp state at representative clock/weather combinations before and after this separation. Any intentional gameplay rebalance is a later change.

Tune sky gradients, ambient light, direct light, fog colour and snow highlight range together, initially using the current cloud geometry. Start with clear and overcast noon, then dusk and night. Inspect hands, wood, metal, ice and snow under every proposed palette.

Change a limited group of related controls per iteration and describe the hypothesis: for example, reducing pale ambient wash should improve depth without making the path unreadable. Avoid compensating for a poor model by globally increasing contrast or darkness.

Gate: clear/overcast states are distinct; local warm lights remain meaningful; surface colours hold together; daytime and nighttime gameplay responses are unchanged. Review a playable candidate and matched images before moving on.

### A2 — Continuous celestial lighting and better cloud shapes

Resolve the abrupt light-direction switches. Maintain coherent light direction, sky glow and shadow behaviour through dawn, dusk and midnight. Choose an art-directed winter sun path consistent with the intended setting; do not introduce a full latitude/season simulator for this pass. Avoid changing playable day length as a side effect.

Make cloud highlights respond to the actual light direction. Make cloud motion respond to weather wind with stable accumulated movement, so a wind change cannot teleport the pattern. Keep visual motion calm in clear weather and plausibly stronger in storms.

Evaluate a lightweight sky-integrated cloud presentation or a curved layer against the baseline plane. Choose the smallest approach that produces convincing horizon coverage and overhead silhouettes. Integrating visible clouds with sky lighting must be checked for colour consistency and rendering cost. Detailed volumetrics, dramatic lightning and auroras are deferred.

Define recognisable cloud masses and broken edges using restrained detail. Test upward/downward camera rotation, looking across the valley from the deck, and travelling across the map. A dramatic cloud still does not pass if it swims, repeats obviously, reveals an edge or flickers during movement.

Gate: smooth transitions; consistent light direction; convincing cloud silhouettes and horizon; no sudden pattern jumps or visible layer edges; performance within the comparison budget.

### A3 — Weather, shelter transitions and persistence

Coordinate clouds, fog, snowfall and wind sound using the existing weather state. Preserve the existing weather probabilities, temperature offsets and resource costs. Choose visibility based on readable landmarks and intended exposure rather than fog density in isolation.

Check how the global indoor environment adjustment affects the landscape through windows. Enter and leave the cabin and lookout repeatedly in clear weather, at dusk and during a blizzard. The room should feel sheltered without making the outside sky or distant terrain change implausibly as the player crosses the doorway.

Add faithful weather restoration only after presentation parameters are stable. Store current state, remaining duration, blended values and the information needed to continue wind and future random weather consistently. Preserve random state losslessly. Cloud movement should resume without a visible jump; its presentation phase must not alter the gameplay weather sequence.

Support older saves with missing optional fields. Test a save made mid-transition, a save made during a blizzard, accelerated time/sleep and repeated reloads. Do not reroll a better forecast on every load. Test saves must not overwrite the player's real session.

Gate: cloud/wind/snow/audio describe the same conditions; room cover and outdoor readability survive transitions; weather remains coherent after reload; old saves still load.

### A4 — Consolidate and decide what is actually better

Review all 20 matched views and the moving samples, including the darker and less flattering states. Run the full day/night cycle and transitions into and out of a blizzard. Recheck shoreline, lookout stairs, fishing and viewmodel behaviour only where the integration could affect them.

Provisional performance guardrail: no greater than 5% median frame-time increase or 10% 99th-percentile increase across three matched warmed runs. Treat these as planning thresholds, not measured guarantees. Repeat a noisy result before drawing conclusions. A noticeable new hitch or motion defect is a failure even when averages pass.

The user's visual preference is decisive. Classify a candidate as better, mixed or worse, with a specific reason. Retain improvements that work across scenes; revise or discard the rest. After two iterations without a clear improvement to a particular element, reconsider the approach instead of layering more controls onto it.

Deliver the playable candidate, comparison images, a short change summary, remaining defects and the exact rollback checkpoint. Merge only the accepted stages. Remove redundant experiments while keeping the verified baseline recoverable in Git.

## Implementation boundaries

Expected atmosphere files: `world/sky_rig.gd`, `world/cloud_layer.gd`, relevant environment sections of `world/game_world.gd`, and focused rendering assets/tests. `systems/weather.gd` and the world save integration enter scope only for A3. `world/snow_fall.gd` or audio changes require an observed consistency defect, not an automatic rewrite.

No changes to the terrain raster, existing structure placement, lookout geometry, ice coverage/interpolation, movement collision, inventory economy, combat damage or action timing in the atmosphere pass. If a defect requires crossing these boundaries, document and isolate it rather than bundling it into a colour iteration.

The old look-development presets must not become a second independently maintained source of truth. Acceptance always uses the complete game. Tests and capture helpers belong in versioned source; generated captures and private test-save backups remain ignored.

## Following milestones toward the MVP

1. **First-person and nearby art quality.** Under the accepted lighting, revisit the blocky fists, wrist transitions, item contact, branch silhouettes and repetitive ice detail. Keep rig correctness separate from visual acceptance. Compare each revised asset in the same scenes; preserve its own prior asset checkpoint. Do not remodel the whole forest in one iteration.
2. **A usable lookout refuge.** Connect warmth, bed, storage and lighting to the elevated room, then establish dependable protected access. Confirm unreachable enemies beneath/outside the refuge do not incorrectly block sleep or saving. Safety still consumes food and heating fuel. Keep the current terrain and buildings intact.
3. **One meaningful technician job and site power.** Inspect a fault, identify a needed part, repair it and observe improved local service. Use the existing tools/inventory/action foundations. Interrupted jobs and reloads must not duplicate costs or rewards. Establish limited site power and backup supply without simulating a complete electrical network.
4. **Independent collapse and optional radio.** Start the opening at the intended pre-collapse stage rather than the current default outbreak population. Persist chosen event times and population phase. Build a small placeholder broadcast schedule tied to world time; tuning late, sleeping, missing a message or losing receiver power must not queue a replay. Public transmitter availability and local receiver power are distinct.
5. **One coherent town expedition.** Use the current road, hamlet/store foundations and a small number of distinct loot destinations. Add practical evidence of the failed delivery and collapse. The player can leave early, ignore the radio and return to a functioning refuge. Avoid a friendly-town population simulation for this first opening.
6. **Complete-experience polish.** Play work, preparation, expedition, danger, return and recovery through save/reload. Review interaction prompts, audio, threat readability, performance and supply balance together. Expand content only after this experience is understandable and compelling to an unfamiliar player.

Each following milestone gets its own branch/checkpoint, acceptance tests and compatible test saves. Atmosphere acceptance does not imply the hands, opening narrative or full game have reached the reference's final quality.

## First implementation deliverable

A0: reproducible baseline captures, measured frame-time baseline and agreed artistic targets. Then A1: a small playable lighting candidate with a specific hypothesis and direct before/after comparison. This keeps the first experiment useful, bounded and easy to discard.
