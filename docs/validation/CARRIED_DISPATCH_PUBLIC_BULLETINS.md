# Carried dispatch and scheduled public bulletins — 2026-10-05

Baseline `7ee88c5311d116ca76ed2386393d0252e7840c54`. Branch `codex/carried-dispatch-public-bulletins`. Reversible checkpoint `checkpoint/pre-carried-dispatch-2026-10-05`. Local integration only; no push.

## Player experience

New assignments begin at **05:30**, giving time to read the desk log and switch on the public receiver before the first 06:00 bulletin. The receiver starts switched off as before. Its green lens reports local power; its blue lens identifies public reception. There is no channel-switch action.

Field dispatch comes through an always-listening, player-owned personal walkie. Reception is non-spatial and independent of the desk switch, lookout mains, local battery and maintenance state. Dispatch captions are yellow; public captions are blue and only appear within the desk's 12 m audio range. Public sound remains spatial at the desk. No new held walkie model, selectable inventory item, outgoing conversation or player response system is claimed.

The public station has twenty original bulletins across five narrative days:

| First lived day | Content |
|---|---|
| 06:00 | Ordinary weather, operating services and deliveries |
| 12:00 | Recap of that morning |
| 17:00 | Unconfirmed violent incidents on the other side of the country |
| Closing 00:00 | Multiple cities affected; emergency services failing |

Later mornings advance the situation, noon recaps that morning, and the afternoon/midnight reports escalate toward isolation and practical self-sufficiency. The final public signoff is the midnight closing Day 5. The calendar reads Day 6 at that instant. Twenty-four-hour schedule entries explicitly represent this closing-day midnight, preventing the first serious bulletin from airing at the beginning of Day 1.

Ten dispatch calls occur at 08:00, 14:00 and 20:00 on Days 1–3, with a final 08:00 call on Day 4. Early calls support the technician assignment; later calls cancel delivery, report loss of contact and release the player to survive independently. Part collection and repair guidance is conditional, so finishing the job early does not contradict the dialogue.

## Time, power and missed broadcasts

The calendar anchor derives from the saved day/hour/elapsed clock, rather than assuming every game began at a fixed hour. Debug starts and legacy saves therefore keep public bulletins on the wall clock. New games have a fixed five-day station arc and the existing seeded 48–72 elapsed-hour mains outage. Transmitter reserve and home reserve are independent.

Each public slot reserves thirty game minutes plus a two-minute guard on each side. Dispatch is prohibited throughout those windows regardless of whether the desk is off, out of power, out of range, or whether the public station has already failed. Authoring validation compares full dispatch windows against every recurring public reservation. Runtime suppression also rejects an accidentally overlapping call.

Actual speech ends before the reserved slot ends. Live-entry expiry uses measured audio duration, so going to sleep after a dispatch clip has finished cannot cause a phantom wake-up during the remaining reserved interval.

The walkie wakes a sleeping player for live dispatch. Accelerated sleep lands on the call boundary, uses only the elapsed portion for healing/catch-up, then returns to the normal clock. Public bulletins never wake the player. Reading still pauses play. The sleep policy follows the communicated default; it can be changed if the player wants dispatch to be missable too.

There are no queues, repeat clips or backlog menus. Tuning, approaching the desk or loading midway receives the remaining live audio. Short captions use actual synthesis word times and reveal the current spoken chunk; arriving late does not expose an entire earlier script. Once the clip ends, its speech and captions remain gone.

Existing saves retain their on/off choice, battery, assignment, pantry, grid deadline and source deadline. Obsolete work/public channel selection is discarded; the desk becomes public-only and the carried receiver is supplied. Earlier saved transmitter deadlines can end reception before the full new five-day arc. **Start New Game to experience the complete sequence.** Saves without opening state retain their original survival mode.

## Production and validation

All scripts are original project writing. Thirty mono PCM16 22050 Hz clips are generated locally using Windows System.Speech: David for public news, Zira for dispatch. These are development synthesized voices, not directed actor performances. Public audio has a wider voice band, quieter noise and a two-tone station ident; dispatch has a narrower handset band, squelch and acknowledgement tone. Raw speech stays separate from the processed assets, so regeneration never filters a previously filtered recording.

The speech generator explicitly uses 16000 Hz source output to keep SAPI word-position times aligned with its waveform, then resamples for the shipped clips. The manifest records actual voice/rate, script and PCM hashes, measured length, caption chunks and processing provenance. Preflight verifies all thirty assets, their non-silent/unclipped PCM, script/caption agreement, caption boundaries and slot fit.

Six gameplay scripts pass **320 assertions**, including twenty exact calendar slots, guard boundaries, every dispatch window, malformed overlap suppression, remote reception, mains/backup failure, late audio seeks, speech-only captions, missed transmissions, sleep boundary/wake/phantom-wake handling, legacy clock migration, fresh-world restoration, existing tree/log/plank gameplay, door/log modal behaviour, and survival props/work feedback. Godot 4.7.2 imports and final tests contain no GDScript parse/script errors. Existing shutdown CanvasItem/ObjectDB/resource warnings and interpolation deprecations remain.

Seven Forward Plus/D3D12 1600×900 GPU captures were reviewed: receiver off/on, noon captions, first midnight report, service log, outside dispatch, and dispatch after local power failure. The review also repaired previously garbled service-log punctuation and shortened opening messages to avoid clipping. These captures check device/UI presentation, not a five-day human play test or a new terrain/rendering pass.

The Windows export preset explicitly includes both runtime JSON files and excludes QA shots. A resource pack was mounted from an otherwise empty fixture project: its schedule, caption manifest and all thirty imported audio streams load without the source project. This verifies radio package admission; it is not a claim that a full standalone Windows executable was played through.

Evidence: `brave-and-cold/shots/radio-bulletins-2026-10-05` in the shared checkout. Reproducible checks: `tools/audio/validate_lookout_broadcasts.py`, `tests/test_radio_bulletins.gd`, and `tests/visual/capture_radio_bulletins.gd`. Audio receipt: `RADIO_BULLETINS_AUDIO_RECEIPT.json`.

## Design implications to keep testing

The separation gives the player dependable work contact while making outside-world news depend on returning home, receiver power and deliberate listening. None of the new broadcasts gates a recipe, part or survival action. Essential work directions remain in the service log, so optional story cannot strand progression.

Removing dispatch's maintenance dependency changes the first job's incentive: commissioning now rewards automatic home backup, rather than permission to hear dispatch. The repeater's existing twelve-watt draw and automatic-transfer coupling are preserved and explained truthfully. Disabling it saves charge but prevents automatic transfer; manual backup and the personal receiver remain available. An actual lookout-to-depot-and-back play test should assess whether that maintenance reward warrants the journey and whether the radio schedule competes usefully with cold, supplies and travel.

The personal receiver deliberately has no consumable battery or off switch in this version, matching the requested dependable dispatch. It cannot make a collapsed dispatch network resume after its final call. Reports about outside hospitals, communities and relief crews are narrative information, not newly simulated town facilities or rescue events. Expanded town geometry, encounter staging and actor voice production remain separate work.

Undo by reverting the feature commit while preserving subsequent shared work; the checkpoint identifies the complete prior radio implementation. Do not hard-reset a checkout that Claude or the player has changed.
