# Human foundation

Original metre-scale geometry authored in an empty Blender scene by `tools/blender/gen_modular_human.py`. Native master: `tools/blender/generated/modular_human/human_foundation.blend`. No imported earlier character meshes or external models.

The master retains hidden `Anatomical*` torso, arms, legs and feet under the fitted clothes. Reveal those objects and hide the garments to work on the underlying body. Head/neck/ears/lids, eyes, hands, jacket, trousers, boots, cap and apron are named modules on one rig. Clothing can be removed in the master; fitted replacements must preserve coverage and weights. Clothed exports omit the hidden body, preventing buried skin from drawing through garments.

The 45 bones include wrists and three joints on every digit. Eight `zombie_*` logical nodes retain the existing runtime pose interface. Hip, knee, ankle and sole dimensions preserve the established contact solver. Skeletal animation is driven by game state; these GLBs have no animation callbacks or damage events. Facial acting and interchangeable fitted body shapes remain the next production pass.

`rowan`, `sam` and `lin` share anatomy and rig with distinct baked cloth palettes. Rowan adds cap/apron. `infected_preview` demonstrates the same body with separate gray skin and worn cloth maps. Named residents retain their own clothing as they deteriorate; private material copies tint their skin. The anonymous infected still use the retained worker model pending a separate crowded-scene rollout.

Run `tools/validate_modular_human.py` for actual-byte hashes, bones, dimensions, surfaces, normalized weights, normals and triangle checks. In Godot use `tests/test_modular_human_skin.gd -- <variant>` and `tests/test_modular_human_gait.gd` for real deformation and contact tests. The manifest and validation report describe these local assets; they do not certify a provider package or user play acceptance.
