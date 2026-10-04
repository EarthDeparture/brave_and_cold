# Winter atmosphere upgrade review

Date: 2026-10-03. Status: implemented candidate ready for player review. No GitHub push.
Baseline: `8a623693988c371a976d6a304151c78cdf4a37ae`.
Recovery tag: `checkpoint/pre-atmosphere-2026-10-03`.
Renderer stage: `12b3ccd`; baseline/capture stage: `40ff58c`.
Candidate branch: `codex/atmosphere-polish`.

## Observed improvement

The complete game now has a sky-integrated cloud field with sun-directed highlights, continuous sun and moon lighting, a blended distant horizon, controlled blue winter shadows and warm dusk highlights. Four-sample antialiasing and softer shadows improve nearby branches and silhouettes. Snow normal strength is reduced using a separate terrain presentation resource with identical texture references. Ice retains its existing geometry and coverage, with the repeating bright surface artifacts removed.

Storm snowfall uses smaller soft flakes whose brightness follows the sky. Existing roof contact remains, with an additional draw mask for particles born underneath a roof. Looking outside from the lookout retains the storm's depth instead of clearing the global fog at the doorway. These are visible improvements in the matched game renders; player preference remains the acceptance decision.

[Daylight and dusk before/after](../../brave-and-cold/shots/atmosphere/review/before-after.png).
[Surface and shelter comparisons](../../brave-and-cold/shots/atmosphere/review/surface-shelter-comparisons.png).
[All 20 final views](../../brave-and-cold/shots/atmosphere/review/all-20-final-views.png).
[Moving comparison](../../brave-and-cold/shots/atmosphere/review/moving-before-after.gif).
[Machine-readable validation receipt](atmosphere_validation_receipt.json).

The source renders remain 1600 x 900. Comparison sheets resize and label actual captures; they contain no repainted or synthetic improvements. The GIF is a review export of 40 real frames per variant and is excluded from performance measurements.

## Iteration decisions

Seven full-scene iterations plus targeted captures were used. Rejected experiments exposed a duplicate cloud layer, cloud hashing artifacts, excessive colour conversion, a hard haze boundary and a Terrain3D resource duplication problem that lost texture references. The final candidate removes those failures. The new original periodic bitmap replaces unstable procedural noise, and the explicit presentation resource preserves terrain textures.

These experiments are retained only as ignored diagnostic captures. Runtime source contains the final implementation and the intentional legacy comparison option. No experimental terrain, mesh or imported hand changes are included.

## Validation

All six focused suites passed: atmosphere, survival, frozen water, shoreline walking, fire lookout and viewmodel. The atmosphere checks cover 14,405 clock/weather combinations against the previous enemy/lamp darkness curve, continuous solar direction through the full day, storm depth through shelter, cloud phase JSON restoration, a matched future weather sequence over 24 game hours and legacy weather dictionaries.

Shoreline tests cross the shore 28 times at each of 30/60/120 FPS with zero blocked frames. Maximum measured vertical bumps are 1.82/1.62/0.79 cm. Lookout ascent and descent also report zero blocked frames. Ice topology retains its authored elevations, underside, footprint and 0.32 m thickness. Hand tests retain item grips, clothing selection and action timing.

Final captures cover clear, cloudy, dusk, night and blizzard states at the lookout, lake, forest and room. Camera positions, targets, FOV, clock, weather, wind phase and image SHA256 values were verified by the review builder. Selected bare rifle, gloved axe and night rifle views were also inspected. Generated diagnostics do not load or write a player save.

Final renderer captures show no new script or shader errors. Existing Terrain3D interpolation deprecation and shutdown RID/ObjectDB warnings also occur in the baseline. Headless editor import completes successfully but also reports dummy texture/resource leaks at shutdown; these are recorded separately from shader/script compilation.

## Rendering cost

Godot 4.7.2, Forward+, D3D12, NVIDIA GTX 1080 Ti, 1600 x 900, VSync disabled. Values below are medians across three warmed runs: 360 observed frames per run. Median p99 is the median of the three per-run p99 values, rather than a pooled percentile.

| Moving scenario | Before median / p99 ms | After median / p99 ms | Added median ms |
| --- | ---: | ---: | ---: |
| Lookout deck, clear | 10.741 / 11.940 | 14.995 / 16.592 | 4.254 |
| Forest, cloudy | 8.043 / 9.516 | 10.768 / 12.719 | 2.725 |
| Shoreline, dusk | 8.332 / 9.494 | 11.100 / 13.228 | 2.768 |
| Shelter to balcony, storm | 8.514 / 9.798 | 11.449 / 13.387 | 2.935 |
| Forest, night | 7.969 / 9.503 | 11.642 / 14.298 | 3.673 |
| Accelerated sky cycle | 7.103 / 8.452 | 9.680 / 11.860 | 2.577 |
| Forest, active gameplay and default population | 7.898 / 8.956 | 10.870 / 12.795 | 2.972 |

The first six cases freeze gameplay processes to isolate rendering. The last leaves world and creature simulation active while moving a frozen, invulnerable player; it is a short representative check, not a full campaign or horde stress test. Additional engine process observations are preserved in the receipt. Wall-clock observations should not be interpreted as a universal FPS guarantee.

The initial provisional 5% median / 10% p99 budget is **not met**. This candidate intentionally carries a measurable high-quality rendering tradeoff, consistent with the user's priority for a major visual improvement. The observed median increases are 33–46%. The lookout is closest to a 16.67 ms frame budget; its engine process median is 16.715 ms. Do not claim a universal locked 60 FPS. Further optimisation should preserve the accepted art and use matched captures.

## Persistence and scope

Weather now saves current blended values, remaining state duration, gust phase and lossless RNG seed/state strings. Cloud motion phase is optional save data. Older saves remain readable; the baseline ignores new fields. Test helpers never overwrite `user://save.json`.

Terrain raster, placement, tower model, stairs, ice footprint/collision, walking code, inventory economy, damage and action durations are unchanged. Enemy night response and building lamp timing remain tied to the exact previous lighting curve. Hand meshes and poses are preserved in this atmosphere stage.

## Rejection and rollback

Keep the recovery tag fixed. It resolves to the baseline including the earlier hand, ice, stair and shorter-action fixes. Preserve any new local work, Claude changes and player save before recovery.

To compare without changing Git, the developer option `atmosphere=baseline` selects the previous sky, clouds, terrain normals, ice presentation and snowfall. This is a visual comparison; the expanded optional weather persistence still exists in the upgraded executable.

For complete rollback, revert the atmosphere validation commit, renderer commit `12b3ccd` and baseline/capture commit `40ff58c` in reverse order, checking intervening changes before each step. Reimport, rerun the relevant checks and compare the restored game to the before captures. Avoid a shared-checkout hard reset. Rendering rejection must not rewind player progress.

## Next quality and MVP work

First review this lighting in ordinary play, especially low-light tools, the tower panorama and a storm doorway. The next asset work should target nearby tree branch shapes, hand silhouettes/materials and item contact under these fixed scenes. Keep each asset revision separately reversible. Cloud overhead edge softness and night readability remain useful player-review points.

Then complete the lookout refuge and one technician repair task, followed by scheduled optional radio broadcasts and one purposeful town supply expedition. The opening story, power failure and town expansion remain future milestones; this renderer pass does not claim they are implemented.
