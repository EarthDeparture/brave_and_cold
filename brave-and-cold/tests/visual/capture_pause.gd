extends SceneTree
## Pause menu and its Options page over the live game (MenuStyle).
var w: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920, 1080); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/menu"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for i in 700:
		await process_frame
		if w.hud != null and w.opening != null: break
	for i in 30: await process_frame
	w.pause_menu.open()
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("res://shots/menu/after_pause.png"); print("PAUSE_SHOT main")
	w.pause_menu._show_options()
	for i in 10: await process_frame
	root.get_texture().get_image().save_png("res://shots/menu/after_pause_options.png"); print("PAUSE_SHOT options")
	w.pause_menu.resume()
	quit(0)
