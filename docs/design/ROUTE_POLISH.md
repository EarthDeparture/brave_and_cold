# Winter route and compound gate

The lookout approach now reads as a lightly used maintenance footpath, distinct from the plowed town road. Its narrow packed centre, intermittent gravel, irregular snow margins and Kestrel Seven markers connect the technician's assignment to the world. Existing terrain, surveyed route data, trees, buildings, sign anchors and finite work-stop stock remain intact.

The compound gate takes 1.25 real seconds for a full eased swing. Pressing interact again reverses from its current angle. The collision leaf follows that angle for the player, infected and wildlife. If its swept volume would enter an actor, it holds position and the prompt asks for clearance; it resumes when the space clears. Refuge protection applies after closing and latching. Optional saved angle/target fields preserve a partial swing, while old Boolean-only saves retain their endpoint behavior. Original positional latch, hinge and stop clips accompany the new hinge and latch geometry.

The lookout ribbon uses nine lateral samples and metric UVs. Its centre rises 7.5cm; margins descend to 5mm and blend into the terrain. Rendered triangles and walk support come from the same rows. A redundant 85cm endpoint backtrack is removed only from the generated ribbon, preventing folded faces at the compound. The original survey and waypoints remain available. Cabin/store paths receive the same material with tapered endpoint opacity.

The town road retains its grading, bridges and walking profile. Independent wear on each side, broken wheel exposure, restrained surface relief and transparent snow margins reduce the mirrored, rectangular appearance. A saved cosmetic surface mask responds to snowfall over two game hours and relaxes over eight hours in clear weather; underlying winter snow remains. It does not change movement, solar output or resource simulation.

Five original route markers stand outside the walking lane, clear of nearby trunks. Sparse small stones and twigs sit on shoulders. A circular concrete drainage outlet faces downhill and has a terrain-following runoff bed; it is not a simulated water system. Marker stems and the headwall share swept collision with actors, while small grit remains step-through detail. New scenery consumes no global gameplay RNG and avoids the persistent crew stops.

All four assets have editable metre-scale Blender sources, GLB exports, original local graphics and byte/bounds receipts. The assets contain 2,158 / 754 / 996 / 184 triangles respectively. No provider models or downloaded artwork are used.

The whole batch is isolated on `codex/route-polish`, based on `8462bf3`. `checkpoint/pre-route-polish-2026-10-07` retains the prior state. Revert this batch's single commit for a complete rollback; retain subsequent unrelated work. The old build ignores the new optional save fields.
