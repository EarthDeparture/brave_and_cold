# Cottage review

Run the project. WASD/arrows move; mouse looks; Shift sprints; Escape releases the cursor.
Approach either north-wall window, aim at its pane, and press E within 3 metres.

Human review required:
- Confirm the room has solid walls, floor, ceiling, and a warm glowing hearth.
- Left window starts unboarded; right window starts boarded.
- E toggles boards, blue light, and pane emission together; repeating E restores the previous appearance.
- Toggling one window leaves the other window and hearth unchanged.
- Distant windows cannot be toggled. Walls/windows block walking.

Automated checks (from the workspace root):
```
godot --headless --path brave-and-cold --editor --import --quit
godot --headless --path brave-and-cold --script res://tests/test_cottage.gd
godot --headless --path brave-and-cold --script res://tests/test_player.gd
```

All three checks passed with Godot 4.5.1. The existing renamer runner was also attempted;
`tests/test_rename_variable.gd:52` calls `quit()` on RefCounted and fails compilation.
No planner brief was present, so its specific file/test checklist could not be verified.
