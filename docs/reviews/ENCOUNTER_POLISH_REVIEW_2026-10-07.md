# Encounter polish review

This pass replaces the infected's rigid tip-over with joint acting and supported settlement, restores the clinic's missing visible entrance ramps, and keeps supply displays synchronized with real inventory. It also prepares inactive model resources during the quiet opening to reduce construction work during encounters. The surveyed terrain, roads, trail alignment, walking endpoints, finite cohort totals, damage timing and save schema remain unchanged.

Branch: `codex/opening-quality`. Recovery: `checkpoint/pre-encounter-polish-2026-10-07` at `579f58c`. Local work only; no push. The detailed delivery and following priorities are in [the plan](../design/ENCOUNTER_POLISH_PLAN.md).

## Delivered and reviewed

- Infected: an asymmetric 0.85-second collapse uses the existing original eleven-bone skin. Knees buckle, arms splay, the head turns and the torso settles. Death and removal from hostile targeting happen immediately; the visual animation cannot issue damage. A pending sleeper-rise tween is cancelled. Reuse clears death time, support samples and body membership. Vault reaching now deforms the weighted arms after the logical joints change.
- Ground support: shared extremal weighted vertices provide visual support probes. The fall aligns to the local grade. Ground heights are cached at 10 cm spacing, with the higher support at discontinuous thresholds. These are visual samples; gameplay collision is unchanged. An initial pose was rejected because its arms drove beneath the floor and lifted the torso. A later pose was flattened and reviewed in the engine. This is authored procedural acting on the existing rig, not a physics ragdoll or a replacement animation graph. Native Blender preview clips and original geometry are unchanged.
- Clinic access: the old ramps used world-space vertices and then inherited the clinic transform again. Inspection placed their rendered geometry around Y=506 while the real entrance was around Y=253. Both ramps now use clinic-local geometry, correct upward faces, mapped timber grain and 7 cm thickness. Their visible top matches the existing walking ramp. In-world review caught this defect when a correctly supported corpse appeared to float over invisible timber.
- Supplies: clinic shelf and roadside cache node bindings are cached once. Inventory signals update them on withdrawal, deposit, spoilage and reload; the world no longer searches their scene trees every frame. Five dressing packages, two antiseptic bottles and the antibiotic package follow actual finite quantities. Roadside stock groups show availability. The cache lid eases into its endpoints and reverses without a positional snap.
- Encounter resources: at most one inactive worker is built per eligible preparation tick, no faster than every 50 ms, up to the existing 60-active resource capacity. Construction defers within 30 m of a living threat. Reserve objects use a separate negative identity range, consume no global random rotation, and stay outside alive counts, save lists, hostile groups and noise listeners. The first living acquisition receives the normal identity. Ordinary population generation and kills remain finite.
- Verification: the moving fixture now checks the assignment seed instead of assuming a global RNG seed also fixes the time-derived outbreak seed. Initial entry frames and population tick cost are retained separately from warm metrics. A stale pacing assertion was corrected: a collected relay outside the pack requires retrieval; a carried relay permits installation. Gameplay guidance was already correct.

Actual-engine views: [previous rigid fall](encounter-polish-2026-10-07/rigid-before.png), [settled pose](encounter-polish-2026-10-07/settled-after.png), [body on the restored clinic ramp](encounter-polish-2026-10-07/clinic-settled.png), [full shelf](encounter-polish-2026-10-07/clinic-stock-full.png) and [withdrawn supplies](encounter-polish-2026-10-07/clinic-stock-withdrawn.png). The previous-fall image reconstructs the old tip-over from the same attack pose in the same neutral fixture. The clinic images use the actual world. These captures are local review evidence, not sealed Game Development Studio runs.

## Verification

Eight focused suites pass **410 checks, zero failures**. [The receipt](encounter-polish-2026-10-07/tests.json) records summaries and local log hashes.

| Coverage | Checks |
|---|---:|
| Skin, forty-pose cache equivalence, five death variants, slopes, threshold, vault and reuse | 42 |
| Inventory signals and cache hinge | 15 |
| Bounded reserve construction and identity allocation | 9 |
| Clinic, both ramps, finite cohorts, damage timing, evasion and actual world reload | 192 |
| Route resources and real reload | 33 |
| Day pace, carried/dropped relay guidance, finite overnight preparation and legacy reload | 51 |
| First-week timeline and finite stock | 38 |
| Habitat, field plan, nutrition and persistence | 30 |

The skin tests evaluate actual weighted vertices, including standing, attacking, heavy, crawling and sleeping deaths. Tested collapse edge stretch stays below 1.285, with no sleeve spikes. Tested inclined support and the threshold keep the mesh above the floor within the 12 mm rejection tolerance. The final actual-world fall update samples measure 0.609 ms median / 1.335 ms maximum over twenty phases, down from 1.471 / 2.101 ms before support caching. These are headless script timings for one body, not a concurrent-combat frame budget.

The parser caught an unsupported packed-array operation during the ground-cache revision; it was corrected before accepted tests. Accepted logs contain no script errors. Existing sandbox log/certificate errors and shutdown CanvasItem/ObjectDB warnings remain; do not classify those as new gameplay failures or suppress them from raw logs.

## Moving 1080p diagnostic

Baseline runtime `579f58c`, final runtime `0f13238`; same corrected fixture, assignment seed 20261004, population target 250, Forward+ D3D12, GTX 1080 Ti, actual 1920×1080 render. Four twelve-second moving cases, three repetitions each. First three seconds are recorded as entry, then nine seconds as warm metrics. Physics walking, AI, survival and weather remain active. God mode, muted audio and disabled inventory consumption prevent interruptions.

| Case | Baseline median ms | Final median ms | Baseline / final warm frames above 33.3 ms |
|---|---:|---:|---:|
| Logging forest | 22.310 | 22.130 | 1 / 0 |
| Town road | 22.215 | 21.964 | 1 / 3 |
| Storm route | 19.765 | 19.601 | 0 / 1 |
| Clinic encounter | 18.189 | 17.149 | 1 / 2 |

Medians are the median of three run medians. Warm hitch counts are totals across those runs, not rates or statistical significance. [The comparison](encounter-polish-2026-10-07/performance-comparison.json) retains each entry maximum, P95 range, active peak and minimum available pool; [baseline](encounter-polish-2026-10-07/performance-baseline.json) and [final](encounter-polish-2026-10-07/performance-candidate.json) retain the complete raw metrics.

Clinic entry population ticks measure 5.453 / 4.430 / 0.233 ms before versus 0.342 / 0.322 / 0.367 ms after. Prepared resources are available without reducing population: clinic peaks are 55 / 59 / 59 before and 56 / 59 / 59 in the final run. The first pass differs by one active actor; these are comparable seeded moving scenarios, not identical fixed-step AI workloads. The initial forest entry population maximum falls from 23.756 to 6.085 ms; remaining quiet preparation still has a cost and consumes bounded memory for the inactive resources.

The isolated clinic refresh median falls from 22.3 to 4.25 microseconds per direct call, and it now runs only on inventory changes. The isolated skin-call difference is small (7.39 to 6.62 microseconds); the forty-pose equivalence test matters more than attributing a frame improvement to that microbenchmark. Raw [baseline](encounter-polish-2026-10-07/presentation-baseline.json) and [candidate](encounter-polish-2026-10-07/presentation-candidate.json) receipts retain all three runs.

**This pass removes substantial encounter-construction work, but does not eliminate frame spikes.** Warm outliers total three in the baseline and six in the final diagnostic, despite similar or lower medians/P95 ranges. Town/storm entry maxima also remain around 47–54 ms while their measured population ticks are below 0.5 ms. Their cause is unresolved. Host power/load are uncontrolled; no GPU attribution, statistical causal claim, minimum-hardware result, autosave result or full-combat result is claimed. Keep the next investigation focused on renderer/terrain/host timing instead of reducing encounter density or claiming these spikes are fixed.

## Recovery and next acceptance

Implementation order: `d5d71fd` resource/supply preparation; `a92563b` infected collapse; `0f13238` visible clinic ramps and regression fixtures; then the receipt commit containing this review. To undo this pass, stop play and revert these commits in reverse order. Do not hard-reset the shared checkout, rewind user saves or revert the previous opening-quality pass.

The next production priorities are close character anatomy/clothing and planted movement, recurring work-hand contact, then the particular town/interior views exposed by a first-night/clinic session. An unfamiliar player must still validate preparation, optional missed broadcasts, depleted power, injury, changed clinic evidence and the return decision. Directed human radio performances remain a separate production task. The plan defines that sequence; this review does not claim those future assets or a human acceptance session have been delivered.
