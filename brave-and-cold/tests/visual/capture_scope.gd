extends SceneTree
## Visual review of every sight type from the tower deck, plus a promoted zombie at range.
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(45)
	get_root().get_texture().get_image().save_png("res://shots/scope/" + id + ".png"); print("SCOPE_CAPTURE ", id)
func sling(id: String) -> void:
	if w.inv.count(id) < 1: w.inv.add(id)
	w.inv.use(id); w.rifle_up = true; w.player.zoom_i = 0
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/scope"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	w.story_skip_to(1, 11.0)
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	var eye: Vector3 = w.player.position
	var target := Vector3.INF
	for k in 24:
		var a := k * TAU / 24.0; var p: Vector3 = w._ground(eye.x + sin(a) * 210, eye.z + cos(a) * 210)
		var clear := true
		for s in range(1, 40):
			var q := eye.lerp(p + Vector3.UP * 1.3, s / 40.0)
			if w._ground(q.x, q.z).y > q.y - .5: clear = false
		if clear: target = p; break
	if not target.is_finite(): target = w._ground(eye.x + 150, eye.z)
	w.pop.add_virtual(target); w.pop.add_virtual(target + Vector3(3, 0, 2))
	var to := target + Vector3.UP * 1.2 - eye
	w.player.yaw = atan2(-to.x, -to.z); w.player.pitch = asin(to.normalized().y)
	w.aim_override = true
	sling("ridge_scout_rifle"); await shot("ridge_3x")
	w.player.zoom_step(2); await shot("ridge_9x")
	sling("expedition_rifle"); w.player.zoom_step(2); await shot("expedition_12x_zombie_210m")
	w.set_process(false); w.forest.set_view_scale(1.0); await shot("expedition_12x_without_scope_lod"); w.set_process(true)
	sling("north_service_rifle"); await shot("service_tube_dot")
	sling("compact_patrol_rifle"); await shot("compact_reflex")
	sling("brush_lever_rifle"); await shot("brush_block_sight")
	sling("ranger_box_rifle"); w.player.stamina = 5.0; w.body.core = 35.0; await shot("ranger_4x_cold_winded")
	quit(0)
