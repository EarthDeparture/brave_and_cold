# Opening quality implementation and review

This pass makes the lookout-to-town opening easier to prepare for, improves the visible forest and repeated hand interaction, turns the existing infected foundation into a deforming character, and connects hunting to the route and the food economy. It preserves the surveyed terrain, existing roads, trails, building footprints and tree collision. Recovery starts at `checkpoint/pre-opening-quality-2026-10-07` (`0703c7b`); work is on `codex/opening-quality`, locally, without a push.

## Delivered

- Six original Blender conifer families, each with near/far exports, bark fissures, needle sprays and supported snow. Separate green and loaded sprays share one runtime atlas. The bank preserves all 115,845 tree roots, species, transforms and trunk circles, with stable saved felling. Dead trees and birch remain in the existing library. Early solid foliage, thin crowns, flat caps and a costly two-sampler snow pass were rejected during review.
- The winter worker has an eleven-bone weighted skin and seven editable Blender preview clips. Existing gameplay state drives actual travel-based gait, attack anticipation/contact/recovery, investigation and stagger. Logical drivers, damage timing and pooled identities remain authoritative. Weight checks caught an inner-sleeve assignment error before admission; the corrected skin has no stretching spikes in the tested attack.
- Six finite deer on fresh opening saves occupy two natural habitats off the logging route. Existing saves restore their surviving animals. Crouching and terrain/trunk cover affect sight while audible noise remains effective. Raw meat/fish require cooking and share conserved energy with the existing cooked/dried portions. Separate saved food-age and scent-age clocks advance across sleep; old food-only saves derive a compatible scent age.
- An original metric enamel flask replaces the home, pickup and hand bottle. Its hollow neck, rolled rim and separate cap support the drinking pose. Actual skin/corrective vertices exposed a 15 mm finger overlap; the fitted release/offset reduces the tested maximum to **1.94 mm bare / 2.52 mm gloved**, with hundreds of near-contact vertices. Existing weapon, empty-hand, watch and work rigs remain intact.
- Four timber and three ice heel/toe samples use non-repeating selection while preserving spatial/shelter selection. The service log opens with the actual assignment, clock, stove/rack stock, prepared water and walkie charge. Collected-but-stored relay parts produce truthful retrieval advice. Completion points the player toward independent supply choices.
- Clouds use broader density transitions, directional thickness, shaded undersides and bounded edge light. Sky palette, exposure, weather rules, survival temperature and darkness response remain unchanged.

Editable native sources are under `tools/blender/generated/forest_quality/`, `infected_skin/` and `opening_props/`. Generators and actual-byte validators are retained. Asset receipts include source/runtime digests, finite geometry/weights, dimensions, budgets and original texture/audio provenance. Production used existing Blender 5.2.2, Python and Godot 4.7.2. No provider assets or external spend were used.

Review the retained [forest before](opening-quality-2026-10-07/forest-before.png), [forest after](opening-quality-2026-10-07/forest-after.png), [gloved flask](opening-quality-2026-10-07/drink-gloved.png) and [actual field plan](opening-quality-2026-10-07/field-plan.png). They show real Godot renders; the isolated grip fixture uses neutral lighting. The fuller render bank is local under `brave-and-cold/shots/opening-quality/`.

## Engine verification

Thirteen focused suites report **704 passed checks, zero failures**. [The receipt](opening-quality-2026-10-07/tests.json) records individual counts, summaries and local log digests. It includes:

| Coverage | Result |
|---|---|
| Whole-map visual-bank migration | 68 checks; identical roots/species/transforms/collision; near/far felling and replay |
| Infected deformation | 16 checks; bind error 0.024 mm; attack vertex movement 1.014 m; worst tested edge stretch 1.162 |
| Opening, habitats and persistence | 30 checks; three natural-spawn seeds; five surviving animals and an aged kill retained on real reload |
| Cooking and preservation | 50 + 69 checks; conserved portions, finite stock and interruption behavior |
| Collapse/clinic encounters | 185 checks; attack wind-up/single hit/evasion, staging, pooling and local evidence |
| Hand/weapon/action rig | 70 checks, including actual bare/gloved flask contact and cap visibility |
| Power/opening/door/log | 29 + 50 + 35 checks; depleted recovery, assignment pacing and actual modal close behavior |
| Walking and route | 31 checks; full 570 m trail in both directions at 30/60/120 simulation FPS |
| Atmosphere/audio | 6 + 65 checks; continuity/gameplay equivalence and audio envelopes; new sample selection also checked above |

Route contact error was 0.0000153 m and maximum tested vertical frame acceleration 0.00670 m. This covers the surveyed trail; it is not a claim that every possible terrain contact has been manually played. Raw GLB validation separately passes all twelve forest exports, 9,792 infected vertices and the 2,398-triangle flask; seven new audio files pass hash/envelope checks.

Local captures review matched route/weather/gate views, five skin poses, twenty-four bare/gloved action phases, and the live field-plan modal. The route capture freezes particles for consistent surface/lighting comparison; the moving diagnostic uses active weather. Captures and tests are local Godot evidence, not canonical or sealed Game Development Studio bundles. Existing sandbox log/certificate, editor Terrain3D slider and shutdown RID/ObjectDB warnings remain; no new parse/runtime errors are present in accepted runs.

## Moving diagnostic

Final [legacy](opening-quality-2026-10-07/performance-baseline.json) and [candidate](opening-quality-2026-10-07/performance-candidate.json) receipts compare current gameplay with the two visual profiles on the GTX 1080 Ti / Forward+ D3D12 at actual 1920 × 1080. Four moving cases each use three 12-second repeats, discarding three seconds of warm-up. Normal player physics, world time, survival, weather and AI remain active; god mode prevents damage interruptions and audio is muted. Population target is 250, with actual activation counts reported separately.

| Moving case | Legacy median ms | Candidate median ms | Candidate P95 range ms | Frames >33 ms | Peak active infected |
|---|---:|---:|---:|---:|---:|
| Logging forest | 19.50 | 22.01 | 23.38–24.10 | 0 | 2 |
| Town road | 14.88 | 21.72 | 23.07–23.25 | 1 | 18 |
| Storm route | 17.40 | 19.44 | 21.62–21.93 | 0 | 20 |
| Clinic encounter | 15.93 | 17.39 | 20.45–23.88 | 9 | 59 |

Median columns are the median of three per-run medians; P95 is the range of the three per-run percentiles, not a pooled percentile. Hitch counts sum the measured frames. Each repeat walks about 33–34 m in forest/storm, 36–38 m on the road and 25 m at the clinic, with roughly 360 game seconds and measurable calorie use. Storm activation differs between profiles; both clinic runs reach 59 active infected. The final bank adds about 2.5 ms in forest and 6.8 ms on the open road against the legacy profile. It is a quality/cost tradeoff, not a universal performance improvement. Dense-forest medians improve from the rejected 34.48 ms resource revision to 22.01 ms while retaining the reviewed close crown detail. Occasional clinic spikes remain a priority for a separate reproducible actor/activation profile; these runs do not identify their cause.

The costly separate-sampler snow revision is rejected. Packing the same paint into one atlas retains the visual result while avoiding its extra sampling path, but did not materially improve the observed timings by itself. Smaller 64 m rendering groups and a 100 m near range replace the legacy 128 m / 140 m configuration. The last bounded refinement removes a redundant crossed spray at distance; far crowns now use 238–374 triangles while the close 2,552–3,916-triangle crowns remain intact. Whole-map identity, collision and felling checks still pass; close-route captures retain the crowns. Changes remain bounded to forest resources/material/LOD configuration. These local timings do not establish hardware comparability, statistical significance, power-state control or causal proof. They are not a full baseline-commit comparison and exclude combat, maximum town density, autosave IO and human play.

## Acceptance and next production gates

Use a **fresh save slot** for the new hunting habitats. Play preparation → cabinet inspection → depot outing → return → first night, then revisit the changed clinic. Judge the new trees at walking speed and across LOD transitions; listen to ice/timber variations and check the flask in bare/gloved use. The [session protocol](../design/OPENING_QUALITY_PLAYTEST.md) covers silent news, ignored optional work, exhausted power, injury/storm, natural hunting, full-pack food processing and mid-transition reload.

Unfamiliar-player acceptance and final directed human radio performance require people playing/listening/recording; neither has been claimed. Runtime preview clips do not establish authored foot planting, facial acting or death performance. Hunting still needs a natural player session; three seeded habitat checks do not establish multi-week ecological balance. This pass adds visual/action and survival quality while retaining those explicit production gates.

For a visual-only comparison, launch with `-- forest_crowns=baseline sky_clouds=baseline`. This retains the current gameplay. Full rollback uses reverse-order revert commits from this branch; do not reset the shared checkout or rewind player saves. The original native models remain available.

Local implementation checkpoints, in application order:

1. `d11aa16` — forest, cloud material and native production sources.
2. `a06653b` — infected skin and runtime deformation.
3. `7297400` — hunting habitat, sight cover, food and scent persistence; visual comparison arguments.
4. `d5ba4f9` — fitted flask, surface audio and actual-state opening log.

The following QA/review commit records this document, diagnostics and receipts. Full reversal starts with that QA commit, then the four implementation commits above in reverse order. A visual-only comparison is available without removing gameplay improvements.
