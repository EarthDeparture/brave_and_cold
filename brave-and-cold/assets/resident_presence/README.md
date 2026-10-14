# Resident presentation derivative

Original project geometry derived from the preserved `modular_human` master. Editable native source: `tools/blender/generated/resident_presence/resident_presence.blend`; reproducible derivative: `tools/blender/gen_resident_presence.py`. The preceding native master and exports remain intact.

Metre scale, 45 bones, eight runtime pose drivers, skin weights and the existing triangle/surface budgets are preserved. Module collections retain the hidden anatomical body and fitted clothes for further editing. `rowan`, `sam`, `lin` and `infected_preview` share the rig; only the three named residents use these exports in gameplay. Anonymous pooled infected retain their existing model.

The Head module has a named `Blink` shape key. Zero is open and one is closed. Its target moves existing eyelid vertices; it does not add bones or animation clips. Eye winding was inspected and required no repairs. The revised eye material reduces broad glare. In Godot, `ResidentPresence` drives private morph values and private eye materials for independent blinking and limited eye/head attention. It uses a separate cosmetic RNG and adds no save fields, dialogue gates or stock changes.

Use `tools/validate_resident_presence.py` for actual export/source checks. Godot deformation/contact suites accept `-- <id> resident_presence` for `test_modular_human_skin.gd` and `-- resident_presence` for `test_modular_human_gait.gd`. `test_resident_presence.gd` checks runtime behavior, real morph/skin data and illness support. Captures and measurements are documented in `docs/reviews/RESIDENT_PRESENCE_REVIEW_2026-10-14.md`.

This is an editable local asset family. Distinct facial anatomy, fitted occupational wardrobe, measured prop grips and an oral cavity for future recorded dialogue are subsequent work.
