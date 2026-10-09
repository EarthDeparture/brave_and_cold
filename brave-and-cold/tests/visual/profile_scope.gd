extends SceneTree
## GPU/CPU cost of looking through 9x glass with the normal vs scope forest LOD, and hip view.
var w: Node3D
func _initialize() -> void: call_deferred("run")
func measure(label: String) -> void:
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 30: await process_frame
	var gpu: Array[float] = []; var cpu: Array[float] = []
	for i in 120:
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp)); cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	gpu.sort(); cpu.sort()
	print("SCOPE_PROFILE %s gpu_ms=%.2f cpu_ms=%.2f" % [label, gpu[60], cpu[60]])
	get_root().get_texture().get_image().save_png("res://shots/scope/profile_%s.png" % label)
func run() -> void:
	root.size = Vector2i(1920, 1080); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/scope"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 12.0)
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	w.player.yaw = 2.3; w.player.pitch = -0.12
	w.inv.add("ridge_scout_rifle"); w.inv.use("ridge_scout_rifle"); w.rifle_up = true
	await measure("hip")
	w.aim_override = true; w.player.zoom_i = 2
	await measure("scope9x_scaled")
	var f: ForestScatter = w.forest
	w.set_process(false); f.set_view_scale(1.0)
	w.player.set_process(true)
	await measure("scope9x_unscaled")
	quit(0)
