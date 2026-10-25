# Lookout stairs, receiver indicators and fallen logs — 2026-10-04

Baseline: `631dc80`. Reversible checkpoint tag: `checkpoint/pre-lookout-stairs-radio-logs-2026-10-04`. Feature branch: `codex/lookout-stairs-radio-logs`. Local integration only; no push.

## What changed

The old elevated-surface guard required all four capsule offsets to have floor, then rejected an entire step at a boundary. This eroded the turn landing into a narrow strip and stopped lateral movement along its inner edge. The controller now follows the actual, height-aware rail segments and preserves sliding along a boundary. Feet still require support; upper levels still select floors by foot height. Deck barriers, furniture, the moving door, jump clearance and ground beneath the tower keep their existing contracts. Global movement/camera tolerances were not loosened.

Continuous momentum tests exposed a second snag at paired inner terminal posts. The Blender source retracts the rail ends from 12 cm to 32 cm and joins the close inner ends with a single nose, rather than leaving an overlapping end-cap pocket. The same geometry drives local collision. Old saves starting in the changed rail clearance can move outward freely. Terrain, roads, trees, building placement, tread/floor heights and tower height are unchanged. Binary comparisons of every attribute and index array confirmed all seven non-rail meshes were unchanged. RNG state is preserved around the additional rail geometry so existing vertex-color variation is retained.

The existing desk receiver now has labeled front-panel lenses: green POWER, yellow DISPATCH, blue PUBLIC. Both lenses are dark when the receiver is off or has no local electricity. Turning the receiver or tuning updates them immediately; mains failure, backup power, battery exhaustion and loaded state also update them. A lit receiver can be silent between broadcasts or after the distant transmitter fails: these are local receiver and tuning indicators, not a signal-strength or replay promise. Labels respond to scene lighting; lenses are small emissive surfaces, not colored room lights. The service log explains the colors.

Fallen trunks previously rendered child geometry at the tree's world coordinates while their root stayed at `(0,0,0)`. The interaction checked that root, so distant logs did not offer harvesting. The log root now sits at its real center, and aiming checks the visible portion of its segment under the view ray, including either end of long/sloped logs. Existing and newly felled logs work after loading. Completion rechecks the hatchet, prevents duplicate harvesting, and retains overflow drops.

The existing production chain is preserved: equip the hatchet, aim at the fallen trunk, hold E to split it into firewood and sticks. Splitting remains 2.5 seconds. Gear > Craft > **Split firewood into planks** consumes one firewood and produces two planks with a hatchet; its existing timing, costs and yield are unchanged. The recipe name, firewood description and harvest message now explain this path.

## Validation

Godot 4.7.2 and Blender 5.2.2. Tests use in-memory snapshots rather than the user's save slot.

- Stair-turn regression: 91 assertions, zero failures. Actual Player ascent/descent through all ten flights at 30/60/120 FPS, five lateral offsets up to ±16 cm, continuous momentum through turns, original 3.5 cm waypoint acceptance. Includes sustained downhill input into both rails with no backward jitter in the tested runs, landing sliding, side-fall protection, ground clearance and nine overlapping-save escape cases. Before the fix, the original focused run failed all 28 tested groups; adding momentum caught the paired-post pocket before final integration.
- Receiver/wood gameplay: 30 assertions, zero failures. Actual outside-fence forest tree chopping, fall callback, aim at both ends and middle, fresh save/load, cancelled work, missing hatchet, single finite harvest, firewood-to-plank crafting and full-pack drops. Receiver tests cover immediate toggles, both channels, silence, blackout, backup restoration, battery exhaustion and distant source shutdown.
- Existing regressions: lookout floor/shelter/save migration 23 assertions; jump 45; door/stove/reading modal 35; full opening save/load 53; track/perimeter traversal 5 grouped assertions including 64 free headings. All passed. Shoreline checks retained 28 crossings per frame rate and zero blocked frames; centered tower ascent/descent remained successful.
- GLB validation: 13,582 triangles, eight mesh/material groups, zero degenerate triangles; below the 15,000-triangle budget. Final runtime SHA-256: `5e00d75ff83d598bb13c3b2b62127987c7a51d3e67dc2d98e9cb4d82bf0e07fd`.
- Triangle/body clearance audit: 870 sampled route positions, 13,960 exact triangle checks, zero obstructed samples. Outgoing low risers retain the audit's explicit step-contact classification. This is sampled clearance, not proof of every possible approach.
- Forward+ D3D12 GPU captures reviewed at 1600×900: receiver off, dispatch/public daylight, public nighttime, no local power, top descent and joined inner nose. First render caught an occluded power LED behind existing display trim; placement was corrected and recaptured. Seven non-rail mesh comparisons and actual import verified the asset change.

Existing shutdown leak and physics-interpolation deprecation warnings remain. Final gameplay logs have no script or parse errors. The local `game-dev` CLI is unavailable; this package uses the repository's existing original Blender generator and GLB/clearance validators. No provider jobs, paid assets or external licenses were used.

Ignored evidence: `brave-and-cold/shots/lookout-stairs-radio-logs-2026-10-04` in the shared checkout. Revert this package's feature commit to undo it without discarding later work; do not hard-reset the shared project.

## Next polish priorities

1. **Show supply depletion accurately.** Pantry food and the loose wood pile currently disappear as groups at zero. Individual visible stock should track remaining quantities, so the player can judge a dwindling reserve before opening a menu.
2. **Give recovered resources real pickup forms.** Overflow items use generic blocks. Recognizable split firewood, plank bundles and loose sticks would make the repaired harvesting loop readable and worth seeing; keep their quantity, weight and save behavior authoritative.
3. **Make interaction feedback consistent.** Cutting, processing, stoking, barricading and maintenance need matched hand contact, tool motion, local sound and completion feedback. Prioritize the actions players repeat instead of adding more scenery around an unclear interaction.
4. **Play a complete resupply loop before expanding the map.** Descend, harvest, make planks, board the door, visit the depot, return, heat the room and survive a power loss. Measure time, calories, hatchet wear, carried weight and battery use together; isolated tests cannot establish this loop's tension or balance.
