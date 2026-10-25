extends SceneTree
## Not headless. Menu goes live, then New Game: the menu must cross back to the lookout
## still, free the 3D scene, hand the loading overlay a visible backdrop and build the world.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: print("LIVE2GAME FAIL timeout"); quit(2))
	root.size = Vector2i(1600, 900)
	var m: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(m); current_scene = m
	await m._go_live_now()
	await create_timer(5.0).timeout
	var live: bool = m._live
	var dio: Node = m._diorama
	m._new_game_now()
	await create_timer(0.7).timeout
	var ov := LoadingOverlay.current
	var shot_dir := ProjectSettings.globalize_path("res://shots")
	root.get_texture().get_image().save_png(shot_dir + "/live2game_loading.png")
	var bg_ok := false
	if ov != null:
		for tr in ov.find_children("*", "TextureRect", true, false):
			if (tr as TextureRect).modulate.a > 0.95: bg_ok = true
	var w: Node = null
	for i in 3000:
		await process_frame
		if current_scene != null and current_scene != m and is_instance_valid(current_scene): w = current_scene
		if w != null and bool(w.get("built")): break
	print("LIVE2GAME live=%s diorama_freed=%s overlay=%s overlay_bg=%s world_built=%s" % [live, not is_instance_valid(dio), ov != null, bg_ok, w != null and bool(w.get("built"))])
	quit(0)
