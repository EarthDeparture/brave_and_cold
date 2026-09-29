# Main menu review

Files: `scenes/main_menu.tscn`, `scripts/main_menu.gd`, `project.godot`.

Automated validation passed on Godot 4.5.1: headless editor import and a
temporary smoke script checking the configured run scene, initial keyboard
focus, idle survival clock/warmth, Start loading `main.tscn` with gameplay
unpaused, and Quit exiting successfully.

Human review required:

- Run the project normally: the title, Start, and Quit appear before gameplay.
- Resize the window: the menu stays centered and both buttons remain readable.
- Use Tab / Shift+Tab or arrow keys and Enter / Space to activate buttons; Start has initial focus.
- Wait on the menu, then click Start: `main.tscn` loads and gameplay runs with full starting warmth and day one at dawn.
- Launch again and click Quit: the application exits.

No separate planner brief was supplied or found in the workspace.
