# Lookout door, stove and service-log fixes — 2026-10-04

Baseline: `a6becb0`; rollback tag `checkpoint/pre-lookout-door-stove-log-2026-10-04`. Branch `codex/lookout-door-stove-log`. Local integration only; no push.

## Changes and play test

Restart the game and Continue an existing opening save, or start New Game. The door opens/closes with the existing wheel/E action system. It swings into the room and refuses to start its swing through an occupant; step back toward the room center or onto the porch if prompted. From inside, select Barricade door with hammer/plank/nail, or Pull off door plank. It uses the cabin's original material costs, noise, tool wear and halved action timing: 3 seconds to nail, 1.5 seconds to remove. Three planks maximum; boarded or broken doors cannot be toggled. Each board absorbs damage before the door. Door pose, HP, board count and partial board damage survive loading. Older saves without the new door block load it open, matching the old fixed doorway and avoiding trapping a saved player at the threshold.

The Blender generator separates the closed leaf into `lookout_door`; runtime reparents it to the authored hinge and animates it. The old baked open-leaf collider is removed. Player and creature contacts follow the actual angle and are limited to the upper elevation; ground movement beneath the tower remains free. Closed leaf also blocks weapon traces. This change supplies the door damage API; it does not introduce new zombie tower-climbing AI.

The original stove mesh, cast hardware, kettle, ember face, front light and interaction target rotate together about the unchanged flue axis, approximately 126.03 degrees toward the room center. Its body uses matching rotated collision; fuel/cooking/heat rules are unchanged.

E on the desk log now opens a paper-style, scrollable modal with current work, depot bearing/distance, communication channels, local power instructions and overnight stock notes. Escape or the X closes it. Survival, time and broadcasts pause during reading; cursor, HUD and player-input state restore afterward. The panel has fixed viewport bounds so long text cannot push the footer/X off-screen.

## Verification

Godot 4.7.2, Blender 5.2.2. Tests use in-memory save snapshots, not the user's save slot.

- Focused door/stove/log test: 35 assertions, zero failures. Includes both-direction closed contacts, open passage, shared creature resolver, weapon traces, ground clearance, actual tween angles, occupied swing refusal, cancelled/completed barricades, costs, damage and old-save migration. Modal checks include bounded layout, blocked gear shortcut, paused time, Escape without opening pause menu, and a real viewport-routed mouse press/release on X without an attack.
- Full opening save/load: 53 assertions, zero failures; fresh world restores reinforced door and partial damage.
- Lookout geometry: 23 assertions, zero failures; actual world integration adds ascent, room entry, shelter, saves and descent (34 assertions total), zero failures. Traversal explicitly opens the door first.
- Jump: 45 assertions, zero failures.
- Opening track/perimeter traversal: 5 grouped assertions, 64 free headings, zero failures.
- Shoreline: 28 crossings per 30/60/120 Hz, zero blocked frames; actual 21.41 m tower ascent/descent, zero blocked frames.
- Walking surfaces: 192 route cases, full 2.56 km road both directions plus entrances/bridges, zero failures. Max contact error 0.00001522 m; max camera step change 0.00607364 m (same as baseline).
- GLB validators pass: tower 13,474 triangles, 8 meshes/materials, no degenerate triangles; home detail 10,750 triangles, 14 surfaces. Updated receipts match runtime bytes and original sources.

Actual Forward+ D3D12 GPU captures reviewed for closed/open exterior, interior barricades, room-facing stove day/night, and service-log modal at 1600×900 and 800×600. An initial container-layout overflow was caught and corrected before integration. Existing Godot shutdown leak/deprecation warnings remain; final test logs have no script/parse errors.

Evidence: ignored `brave-and-cold/shots/lookout-door-stove-log-2026-10-04`. Capture script: `tests/visual/capture_lookout_fixes.gd`. Revert the single feature commit to undo this package, preserving subsequent user/Claude changes; do not hard-reset the shared checkout.
