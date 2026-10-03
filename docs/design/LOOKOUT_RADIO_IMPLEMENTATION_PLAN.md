# Lookout and radio-site opening: implementation plan

Status: proposed implementation plan; no gameplay changes made.
Baseline: `14fe799` on `rework/gdd-architecture`, pushed to origin before this branch was created.
Enhancement branch: `codex/lookout-radio-opening`.

## Accepted direction

- A city-based electrical maintenance technician is temporarily assigned to major power-supply maintenance at a remote radio installation in northern Canada.
- Accommodation is the elevated cabin of the neighbouring out-of-season fire lookout. No separate ground-level residential cabin is required at the worksite.
- The lookout is a dependable refuge. Safety is desirable; limited resources and useful destinations motivate leaving it.
- A fenced work compound provides breathing room. Equipment enclosures and storage are workplaces, not additional homes.
- The assignment initially feels ordinary. Missed deliveries, failing communications, infrastructure loss, and evidence in town gradually reveal the collapse.
- Public broadcasts are optional, scheduled against world time, and not replayed after their transmission. Missing one must not block survival or story progression.
- The nearby radio installation is a local relay, not the origin of every public broadcast. Successful maintenance cannot reverse the wider collapse.
- The existing valley and survival systems remain the foundation. This plan does not require multiplayer, friendly crowds, branching dialogue, seasonal terrain replacement, or destructible tower supports.

## Critical implementation findings

### An elevated building cannot use the current ground-building contract unchanged

`world/cabin.gd` uses horizontal containment (`contains_xz`), horizontal wall resolution (`resolve`), and a floor query that returns the cabin floor for any matching horizontal coordinate. Its entry ramp assumes a short rise from terrain. `entities/player/player.gd` selects ground and shelter using those queries and drives movement as a `Node3D` over sampled surfaces.

Simply lifting a cabin would make the space beneath it behave as its interior, could pull actors onto the upper floor, and could give ground-level actors upstairs wall collisions. Shelter, heat, indoor fog, snow queries, and sound muffling also depend on horizontal containment. Zombie and predator movement use the same family of building queries.

The first deliverable must distinguish ground, stair/deck surfaces, and the actual room volume. Do not assume the configured Jolt physics engine supplies this behaviour to the current custom movement automatically.

### The current safe-rest rules do not express a secure lookout

`world/game_world.gd` blocks sleep and automatic saving based largely on distance to hostiles and hordes. A creature safely outside a fence or beneath a tower could therefore prevent rest indefinitely. Refuge safety needs to reflect reachable access and the accepted secure boundary, while cold, bleeding, and other genuine survival problems remain relevant.

### Saves do not identify an elevated player location

Player save data contains x/z and view angles, but not y or a surface/location identity. Loading calls `Player.place`, which resolves a ground surface again. An elevated room and the space beneath it can share x/z. Save restoration must preserve the correct level without teleporting between them.

Building state is currently restored by array position. New story objects should have stable identities so adding a lookout or changing placement does not attach old state to another building. Existing weather and damage-state omissions must not be copied into the new systems.

### The current world starts after the collapse

`GameWorld._ready` seeds a default population of 700 zombies, including sleepers placed at buildings. The proposed opening needs an explicit distinction between the earlier assignment and the later survival world. New-game setup and loading must not seed the same populations twice.

The refuge must not rely solely on a spawn exclusion radius. Roaming populations can travel toward sound and light, and the current movement model does not establish general fence collision or safe vertical access.

## Reuse and integration boundaries

| Existing element | Reuse | Required distinction or extension |
| --- | --- | --- |
| `world/cabin.gd` | Stove, bed interactions, interior lighting, storage-related positions, window ideas | Separate lookout structure and vertical access; do not replace every town cabin |
| `entities/player/player.gd` | First-person control, stamina, inventory-related slowdown | Height-aware surface selection and controlled traversal |
| `world/game_world.gd` | World assembly and connections to survival/UI | Named home/refuge rather than assumptions that `cabins[0]` is every kind of home; keep new feature state out of additional monolithic blocks |
| `systems/game_clock.gd` | Authoritative world calendar and elapsed game time | Scheduled events advance through sleep and time jumps |
| `systems/weather.gd` and `world/sky_rig.gd` | Exposure, visibility, atmosphere | Work and observation respond to existing conditions; preserve weather on load |
| `systems/inventory.gd` and `systems/recipe_db.gd` | Parts, consumables, tool condition, existing resources | A small maintenance inventory rather than a complete new crafting game |
| Existing timed interaction/crafting patterns | Interruptible work, action prompts, resource costs | Maintenance jobs have durable state and idempotent completion |
| `systems/game_audio.gd` and `systems/sfx.gd` | Audio settings and presentation conventions | Diegetic receiver playback separate from AI noise events |
| `systems/noise_bus.gd` | Consequences of audible work | Receiver playback does not automatically emit global threat cues; choose acoustic effects deliberately |
| `systems/population.gd` | Existing virtual/active populations and hordes | Phase-dependent world pressure, protected access, no reseeding on load |
| Store/hamlet/road systems | First expedition route and supplies | Authored destinations with evidence that matches the story |
| `systems/save_game.gd` | Session handoff and serialization entry point | Versioned story, site, receiver, supply, and vertical-location state |
| `ui/dev_menu.gd` and existing tests | Debug controls and scenario conventions | Focused scenario checks with nonzero failure exits; avoid further concentrating all tests in the dev menu |

Proposed responsibilities, with names to be settled during implementation: lookout structure/access, refuge safety, site power, maintenance jobs, collapse timeline, and broadcast scheduling/receiver. These are ownership boundaries, not a mandate for a large framework.

## Delivery order and acceptance gates

### 1. A functioning elevated home

Build one authored lookout beside a radio installation on the existing valley. Use a staircase as the proposed first traversal option; a ladder would introduce a separate movement mode. Provide a deck, room, stove, bed, storage, and safe entrance. Preserve ordinary ground-level buildings elsewhere.

Acceptance:
- Walk from terrain to the living room and back without snapping, clipping, or leaving the intended route.
- Actors beneath the room remain on the ground and do not become indoor occupants.
- Supports and stairs have their intended movement boundaries; neighbouring wildlife and enemies do not inherit the upstairs floor.
- Indoor warmth, lighting/fog, snowfall cover, and sounds match the correct space.
- Save/reload in the room, on the deck, on stairs, and underneath the tower restores the correct location.

Do not begin broadcast production until this essential structural change is reliable.

### 2. A dependable refuge and a reason to leave

Establish the fenced work compound, entrances, and ground equipment/storage. The room and secured compound express intentional safety. No routine surprise siege or forced destruction of the player's home is required.

Acceptance:
- Threats outside the protected boundary do not enter through movement shortcuts.
- Nearby but inaccessible threats do not block safe sleep and autosaving indefinitely.
- Safety does not bypass cold, hunger, injury treatment, or resource use.
- Existing fire/light attraction can affect the surrounding world without contradicting the protected boundary.

Review food, heating fuel, medicine, and equipment reserves as one supply economy. Give adequate notice of shortages. Do not make all resources fail together, and do not place indefinite sources of every essential inside the compound.

### 3. One meaningful maintenance loop

Implement a small connected job sequence: inspect power equipment, obtain a specific replacement or consumable, perform the repair, and verify improved service. Work takes place at the installation rather than on the radio tower's upper structure.

Reuse existing timed actions and inventory/tool patterns. Tasks should affect equipment condition or service availability, not merely mark a checklist. Weather and daylight influence whether an outing is sensible.

Acceptance:
- Each job has an observable purpose and outcome.
- Starting, interrupting, completing, and reloading a job do not duplicate rewards or consume resources twice.
- Jobs can be understood without hearing a particular public broadcast.
- The initial ordinary work remains useful after support disappears.

### 4. Site power and the independent collapse timeline

Model the supply feeding the site, a limited backup, and electrical consumers at a deliberately small scale. The stove remains wood-fired; grid loss does not suddenly replace the established thermal model. The exact incoming supply and backup arrangement are still design choices.

Introduce assignment, disruption, abandonment, and self-sufficiency states tied to elapsed world time. Use bounded per-run variation for failure dates while preserving causal order. Store selected dates and outcomes in the save instead of rerolling them on load.

Acceptance:
- Local repairs improve local service without restoring distant institutions.
- Site power, town power, and remote transmission availability can have different lifetimes.
- Sleep and accelerated time apply elapsed consequences once.
- The player can leave early, remain home, or miss broadcasts without freezing the collapse.
- Initial population setup represents the selected stage and remains consistent after load.

### 5. A finite radio schedule

Start with placeholder recordings/text to validate timing before investing in final voice production. Separate the work channel from public stations. Schedule each unique transmission with a stable ID, channel, start/end time, content, and source availability.

Time advances whether the receiver is off, out of range, or unattended. Sleeping through a transmission counts as missing it. Later reports may revisit the same subject, but the original transmission is not replayed automatically. No playback archive or collectible completion requirement is assumed.

Acceptance:
- Tuning in partway through a broadcast does not restart it.
- Saving/loading and repeated tuning cannot rewind the world schedule within that continuing session.
- A time jump over several broadcasts does not play them in a backlog.
- Receiver power and source transmission availability are distinct.
- Spoken content, optional readable presentation, and sound settings remain usable without mandatory listening.

Reloading an earlier save naturally returns to an earlier world state; preventing that or excluding players from developer tools is outside this MVP plan.

### 6. The failed delivery and first town expedition

Author one expected delivery/pickup point and one coherent failure, with physical evidence available even if messages were missed. Give the player a practical reason to enter town before starvation forces it. Connect the route to a few distinct destinations, such as food, tools/parts, and medicine, using the existing store and building foundations.

Acceptance:
- The radio and physical evidence describe a consistent situation.
- The first expedition has useful rewards, exposed choices, and a reason to return to the lookout.
- Early town visits remain possible; do not require a functioning civilian town simulation to make them coherent.
- The fiction explains transport and isolation without piling up unrelated barriers solely to trap the player.
- Home remains usable after the expedition; the transition is loss of support, not loss of the refuge.

## Whole-opening validation

Exercise listening and ignoring the radio; staying home and exploring early; sleeping across events; power loss during playback; interrupted maintenance; depleted backup; and save/reload before and after every major transition.

Assess the experience through one complete cycle: work at the site, notice disruption, prepare, obtain supplies in town, return, recover, and continue after reload. Verify that unfamiliar players understand their practical options even when all optional broadcasts are missed.

Benchmark the elevated view and populated town route on the same declared hardware/settings as the existing performance target. A high viewpoint can expose more terrain, forest chunks, shadows, and distant population than current ground-level travel. Do not promise fully detailed kilometre-distance town simulation merely because the tower has a clear sightline.

## Scope and outstanding choices

Not required for the first version: friendly crowds, branching dispatcher conversations, emergency vehicles, full electrical-network simulation, zombie climbing, tower collapse, multiplayer, or mandatory story objectives.

Still to settle: exact site location/height, gate/access arrangement, electrical supply and backup type, assignment duration and initial reserves, narrative failure-date ranges, radio station count, outbreak cause/knowledge limits, and treatment of old saves. Compatibility should be explicit: migrate safely where feasible or preserve old saves and explain incompatibility; do not silently reset them.

Immediate implementation priority: reliable elevated traversal and containment, followed by the refuge contract. The story depends on that space working before it depends on dialogue quantity.
