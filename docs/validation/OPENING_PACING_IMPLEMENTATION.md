# Opening pacing candidate — 2026-10-06

Implemented the first production batch on `codex/opening-pacing`. The recoverable pre-change checkpoint is `checkpoint/pre-opening-pacing-2026-10-06` at `edb43c4`. This is a pacing and guidance change; the story, location assets, character animation and atmosphere batches remain outstanding.

## Delivered behaviour

- A **new lookout assignment run** uses a 48-real-minute day (30 game seconds per real second) and starts with eight game hours of lit-stove heat. The six stored and two carried logs are unchanged and finite. Each log still supplies two game hours. Starting heat lasts 16 awake real minutes; the full initial heat reserve, including all eight loose logs, totals 24 game hours or 48 awake real minutes, if collected and fed into the stove.
- Existing saves without clock metadata retain their original 30-minute day. Updated saves preserve their own awake rate. Loading never refills the stove or rerolls shutdown deadlines. Non-assignment fresh survival runs retain their original pace.
- The clock stores the awake rate separately from accelerated sleep. Public/dispatch playback offsets, captions and population sleep catch-up follow that rate. The scheduled 06:00, 12:00, 17:00 and midnight slots, dispatch exclusions, expired-broadcast behaviour and existing short interaction waits remain in effect.
- Fixed the service-log formatting failure caused by an unescaped literal percentage. Actual current work, depot bearing and first-aid guidance now appear correctly; collected parts update the return instruction.

## Why these balance changes

Slowing the day alone would leave only four real minutes of initial stove burn. The measured depot outing exceeds nine minutes before orientation, reading, supplies, navigation mistakes or optional stops. Eight initial game hours leave a useful return-home fire while still requiring deliberate refuelling for longer trips and overnight rest. No hunger, water, temperature or movement coefficients were reduced.

The calendar change has a cost: the first infected cohort moves from 35 to 56 awake real minutes; the seeded grid shutdown moves from 60–90 to 96–144 minutes; final public silence moves from about 143 to 229 minutes. These remain independent of job completion. Sleep advances the calendar. The longer opening is a playtest candidate, not an accepted claim that waiting and tension are solved.

## Measured developer route

Both profiles used seed `20261004`, the same physical waypoints and the actual player controller. The walkie was taken, the ground cabinet inspected, the existing logging access and road followed, the reserved relay collected, and the cabinet installed/verified before returning upstairs. Both completed with no unreachable waypoint and repair stage 3.

| Return result | Baseline | Candidate |
| --- | ---: | ---: |
| Active simulated real time | 9 min 6.57 s | 9 min 6.57 s |
| Remaining stove heat | 0 game hours | 3.45 game hours |
| Calories | 444 kcal | 1,122 kcal |
| Water | 41.5% | 57.8% |
| Core temperature | 32.85°C | 36.57°C |

Neither trip consumed the carried food, water or firewood. The baseline could benefit from preparation and consumption; this comparison measures the unprepared continuous outing, not whether the old opening is impossible. A separate evening fixture used actual inventory consumption: one can of beans, one water serving, the two carried logs and two rack logs. Eight hours of accelerated sleep completed warm, fed, hydrated and rested, with the awake rate restored.

Measurement limits: fixed 30 Hz scripted movement; direct action callbacks using existing waits; no exploration/menu time; actual world survival, weather and population tick; individual entity process/animation frozen. This is not unfamiliar-player footage, combat verification or a frame-time benchmark. Disposable in-memory saves and diagnostic output were used; user saves were not touched.

## Validation

Eight diagnostic runs passed, totalling **593 PASS assertions**: opening pacing (50), public/dispatch radio at candidate and baseline rates (141 each), lookout opening (53), first-week core (33), first-week story (38), watch/walkie/door (46), and stair turns/rail pressure (91).

Actual Vulkan Forward+ renders on the GTX 1080 Ti were inspected for service-log readability at 1280×720 and 800×600, starting inventory/watch, and the heated lookout interior. They do not establish the documented target-hardware performance or a graphical overhaul. Existing shutdown object/RID warnings and restricted-environment engine-log/certificate errors remain recorded in the diagnostics; no new script/parse failures or service-log formatting errors were found in the selected final runs.

Full route samples, normalized source hashes, diagnostic/capture hashes and limitations are in `OPENING_PACING_IMPLEMENTATION_2026-10-06.json`. Local render/log files are under ignored `brave-and-cold/shots/opening-pacing-2026-10-06/`.

A headless editor import registered the changed scripts and generated their UID sidecars, but was not a clean editor run: restricted access to the Windows Godot settings/cache directories also caused the unchanged Terrain3D editor plugin's `DoubleSlider._ready` to receive a nil editor setting. That editor-only error is recorded separately from the eight passing runtime diagnostics. The Terrain3D addon was not modified in this batch.

## Try and revert

Use **New Game** for the new pace and initial fire. Continuing an old save deliberately retains its prior pace and fuel. For developer comparison, pass `-- opening_pace=baseline opening_seed=20261004`; the same seed with the default profile uses the candidate. This flag selects fresh-run defaults and does not overwrite a loaded save's profile.

This batch is a separate local commit with no push. To reject it, revert that commit on a working branch after preserving any later changes. Avoid a hard reset of the shared checkout. The checkpoint tag identifies the exact pre-change code. Candidate saves add a clock pace field but retain the prior clock/calendar and resource fields; keep a copy of any playtest save before comparing versions. No automated rollback should replace the user's save file.

Next acceptance work is a normal first-shift/first-night playtest, including preparation, missed broadcasts and an assignment ignored. Then proceed to P1's character continuity and authored evidence, followed by persistent location dressing, infected presentation and coordinated atmosphere/material production.
