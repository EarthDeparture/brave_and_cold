# Watch, dual-monitor handset and charging

Gear (Tab) now shows a permanent watch reading the live world calendar, including crafting/storage views and legacy survival worlds. A minute-boundary floating-point formatting issue was corrected. Gear is initialized during world setup so Tab also works before the first gameplay process frame. The wrist model and look animation remain the later stage requested by the user.

New assignments start with one fully charged handset in a visible desk cradle. Aim and press E to take it; use the cradle to dock it again. Gear shows its location, charge and monitoring/charging status. This is unique tracked equipment, without a normal inventory weight or pack slot. Older assignment saves preserve the formerly carried handset, supplied at full charge; schema 3 saves preserve exact charge and dock/carry location. Outage dates, pantry and job progress are preserved.

The carried handset monitors dispatch and public news. The desk receiver remains public-only and independently switchable. A nearby working desk owns public playback, preventing doubled voices. Away from home, or when the desk receiver is off/unpowered, the charged handset receives the same live bulletin at its remaining speech offset. The docked handset remains a spatial desk receiver, audible nearby; it cannot reach a remote player. Empty carried batteries lose both signals. A powered cradle can operate a docked empty handset. Forgotten/depleted devices and sleep can still cause missed broadcasts, with no replay queue. Public slots remain 06:00, 12:00, 17:00 and closing-day 00:00, with globally reserved windows keeping dispatch clear. Dispatch wakes a sleeper only when their handset is operational and carried or nearby; public does not wake them.

## Initial balance and power

Capacity 12 Wh; monitoring 0.5 W: about 24 game hours per full carried charge. Charger input 6 W with 80% efficiency and active monitoring gives 4.3 Wh/hour net, about 2 hours 47 minutes empty-to-full. Full docked monitoring draws only 0.625 W. The cradle uses mains or enabled finite backup alongside existing loads, then falls back to the handset's own battery when home power is exhausted. Integration splits at grid failure, handset-full and home-empty boundaries, including long sleep advances. A low-battery reminder occurs at 15%, resetting above 20%. Percentage rounds upward while charge remains, so 0% means empty.

## Presentation and door behavior

Original Blender handset/cradle: olive polymer, rubber, fittings, speaker vents, PTT switch, controls, lettering and antenna; three semantic mesh nodes, seven materials, 4,510 triangles and 401,292 bytes. No downloads, providers or external textures. Generator and native .blend are preserved. The game-dev CLI was unavailable; the established local Blender/Python production path was used. Actual GLB normals, indices, nondegeneracy, source/binary hashes and display parenting are validated. The handset disappears from the cradle when carried; its display darkens without receiver power. Cradle indication is amber charging, green full, dark when unpowered/empty. Render review moved the LED to an exposed front ledge for visibility.

The tower door opens/closes through an occupied swing without pushing actors. An actor genuinely embedded by the closing leaf can step clear on either side. Ordinary repeated walking contact remains blocked by a stationary closed leaf. Barricades, damage, weapon traces and saving remain intact. No terrain, stair, map placement or existing furniture collision geometry changed.

## Validation and play-test

Eight suites pass 432 checks: 66 charge/integration, 46 watch/handset/occupied-door, 27 assignment, 140 live bulletin/calendar/audio/sleep, 35 door/barricade/log reader, 53 opening/save/power, 29 radio/tree/log/plank, 36 survival props. Final import has no script/parse errors. All 30 original speech clips pass PCM/hash/script, timing and schedule preflight; three dispatch scripts/audio/captions now describe portable public monitoring and desk charging. Audio receipt writers use explicit LF for reproducible regeneration.

Eight Forward+ Direct3D12 captures cover desk/model contact, amber LED, empty cradle, inventory watch/charge, midnight, crafting at 1280x720, outside public reception and empty-battery inventory. Capture script: `brave-and-cold/tests/visual/capture_watch_walkie.gd`. Ignored evidence: `brave-and-cold/shots/watch-dual-monitor/`. Machine-readable receipt accompanies this document. Existing interpolation deprecation and shutdown CanvasItem/ObjectDB/resource diagnostics remain. Human play-test is pending; automated and rendered validation is complete.

Play-test Tab while time advances; take the handset with E and leave during a public slot; switch the desk radio off nearby; dock it and check amber/green; save/load partly charged; operate the door while standing in its swing and step clear after closing. Diagnostics do not overwrite or generate user saves.

## Revert

Pre-change checkpoint: `checkpoint/pre-watch-dual-monitor-2026-10-05`, commit `6e7bab656b7aba967a0ae3ae51153eb07d85fe43`. Feature branch: `codex/watch-dual-monitor-charging`, one local commit. Revert that feature commit to preserve unrelated subsequent work, then refresh Godot imports. No push is performed.
