# Survival stock, resource props and work feedback — 2026-10-04

Baseline `394540b`. Branch `codex/survival-props-feedback`. Reversible checkpoint `checkpoint/pre-survival-props-feedback-2026-10-04`. Local integration; no push.

## Result and boundaries

Lookout stock now depletes one unit at a time: twelve loose firewood units, four tins and two food pouches at the new-game start. Removing/depositing food updates immediately through the chest contents signal. Taking wood checks pack capacity before changing either inventory or the reserve, then removes one displayed log. Save/load derives presentation from authoritative existing counts; there are no new inventory fields or quantities to migrate.

The previous permanently baked tins and crate were removed from the original tower mesh, and the old overlay food/wood groups remain hidden. Otherwise an empty pantry would still appear stocked. The original random palette samples are consumed without exporting those retired primitives. Binary comparisons confirm all seven other tower meshes—including stairs, rails, door, glazing and snow—are identical in every attribute/index array. Terrain and global locomotion are unchanged.

A shallow original tray keeps pouches visible and supported above the tins within the original rack. The folded wool now rests on its original shelf. Visible capacity is bounded to twelve logs, four tins and four pouches. Exact counts remain on the rack tag and in Gear; extra deposits are explicitly marked stored. The tag reports other stored inventory separately. Matches, bandages and arbitrary deposits are not individually modeled. This avoids pretending every stored item has a corresponding visible prop.

Dropped firewood, planks and sticks now use original Blender models: split cross-sections, bark, cut growth rings, beveled boards and tapered/forked branches. New 512px procedural bark, end-grain and canvas maps include subdued normal detail. Shared meshes and MultiMesh instances bound each drop to twelve logs, eight boards or sixteen sticks. Larger quantities retain their full existing pickup/save value and prompt count. These visuals create no solid collision bodies and retain the existing pickup footprint. Placement remains at the saved ground/floor origin; this is not a new physics settling system for every steep slope.

Timed log splitting, tree chopping, door/window barricading and lookout maintenance now own their work presentation. A new textured claw hammer shares the already fitted Shaft grip cross-section. The existing articulated bare/gloved hand skeleton and corrective shapes are reused. Work progress drives tool cycles and local sounds; the final strike aligns with completion. Repeated tree chops start at the previous impact and continue through recovery instead of snapping the wrist. Cancellation removes work feedback; successful completion has a short recovery. Releasing E, movement, jumping, damage, death, inventory, switching weapons or putting away the required tool interrupts appropriately. Attacking cancels work before weapon presentation. The previous delayed tree-chop callback was removed so it cannot outlive its originating action.

Presentation never spends resources, adds AI noise or applies damage. Existing action duration halving, yields, calories, tool wear and saved inventory remain authoritative. Work poses stay within ordinary arm reach and do not move the player or camera. They are first-person presentation, not universal world-space hand/tool contact at the outer interaction reach. Stove/gather/maintenance use a general articulated reach gesture; bespoke kettle, relay-component and menu-crafting handling remain further work.

## Evidence

Godot 4.7.2, Blender 5.2.2 LTS. User save slots were not written; gameplay tests use in-memory snapshots and fresh-world loads.

- Six scripts, **272 PASS assertions, zero failures**: stock/pickup/work 36; existing imported hand/weapon rig 27; receiver and actual forest harvesting 30; lookout door/stove/reading modal 35; full opening state/save/load 53; stair turns and rail pressure 91.
- Actual skinned hammer grip: bare penetration 0 mm, 1,602 vertices within 4 mm of the fitted handle; glove maximum penetration 0.984 mm, 2,878 nearby vertices. Both satisfy the existing 3.5 mm maximum penetration contract. Cuffs remain attached across sampled work poses.
- New tests cover immediate depletion/deposit, display overflow, full-pack preservation, finite reserve exhaustion, exact resource drop counts/condition, bounded large drops, fresh save/load, interruption, equipped rifle restoration, final recovery, repeated-chop wrist continuity and actual joined-tin UV range.
- Byte-level GLB validation checks source/asset hashes, finite vertices, normalized normals, UVs, indices, nondegenerate triangles, metre-scale grounded origins, self-contained textures and per-unit budgets. Units: wood 106 triangles; stick 112; plank 108; tin 436; pouch 108; tray 108; hammer 552. Each is below 2,000 triangles and 3 MB.
- Regenerated tower: 13,430 triangles, eight mesh/material groups, zero degenerates; below 15,000. SHA-256 `68311488deb4190705d6225400571ebbb9a7e7c7cf4d69b241fc3270a44a7985`. Existing body-clearance audit: 870 route samples and zero obstructed samples, with its existing explicit low-riser classification.
- Forward+ D3D12 GPU review at 1600×900: full/half/empty pantry, recovered resources, hammer/splitting/reaching with bare and gloved hands. The first review found collapsed tin-label UVs after Blender joining and pouches obscured by tins; both were corrected and recaptured. Captures are reviewed evidence, not a performance benchmark or proof of every possible item/surface contact.

Existing shutdown CanvasItem/ObjectDB/resource warnings and interpolation deprecations remain. Final tests/captures have no GDScript parse/script errors. The unavailable game-dev CLI was replaced by the repository's existing original Blender/Python workflow and byte-level validators. No provider jobs, third-party assets or paid generation were used.

Ignored evidence: `brave-and-cold/shots/survival-props-2026-10-04` in the shared checkout. Revert the feature commit to undo this package while preserving later work; do not hard-reset shared changes.

## Next decision that matters for the MVP

A complete human lookout-to-depot-and-back trip still needs balance validation. The existing forest-to-firewood-to-plank mechanics, barricading, maintenance, power and save paths pass their regressions, but separate tests do not establish the trip's tension. Store searches randomize hammer/nail supplies and mark search locations looted. The reserved relay part is guaranteed; optional shelter reinforcement is not. Before expanding the town, measure an actual journey's travel time, cold exposure, calories, carried mass, hatchet wear, finite depot yield and battery budget together, then decide which essentials must be discoverable reliably. Replace the remaining general reach gestures with fitted carried components as each action is stabilized.
