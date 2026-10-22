extends SceneTree
## Alive L1 review: ravens over a kill (far / mid / landed / telephoto), aurora from the lookout deck
## (north, overhead, snow tint) vs the same night without. -> res://shots/ambient/
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func secs(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0): await process_frame
func shot(id: String) -> void:
	await frames(20)
	root.get_texture().get_image().save_png("res://shots/ambient/" + id + ".png"); print("AMB_CAPTURE ", id)
func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261022)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/ambient"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 12.5; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.rifle_up = false; w.hud.visible = false
	var al: AmbientLife = w.ambient_life
	al.voices_enabled = false
	for f in al.flocks.duplicate(): al._free_flock(f)
	var lk: Node3D = w.fire_lookout
	var deck: Vector3 = lk.to_global(Vector3(0, FireLookout.DECK_Y + 1.6, -3.0))   # outside walkway, north side
	var out_dir: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var pt: Vector3 = lk.approach_point(14.0); w.player.place(pt.x, pt.z)
	var pp: Vector3 = w.player.global_position
	var cp: Vector3 = lk.global_position + out_dir * 75.0; cp.y = w._ground_y(cp.x, cp.z)
	var kill := Node3D.new(); w.add_child(kill); kill.global_position = cp; kill.add_to_group("carcasses"); kill.set_meta("scent_age_s", 900.0)
	var body := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.35; cm.height = 1.5; body.mesh = cm
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.35, 0.25, 0.18); body.material_override = bm
	kill.add_child(body); body.rotation_degrees = Vector3(0, 0, 90); body.position = Vector3(0, 0.3, 0)
	al._scan()
	var f: Dictionary = al.flocks[0]
	await secs(4.0)
	var c := Camera3D.new(); c.fov = 62; c.near = 0.05; root.add_child(c); c.make_current()
	c.global_position = deck; c.look_at(cp + Vector3(0, 18, 0), Vector3.UP)
	await shot("ravens_far_110m")
	c.fov = 14; await shot("ravens_far_telephoto")
	c.fov = 55
	var mid: Vector3 = cp - out_dir * 30.0; mid.y = w._ground_y(mid.x, mid.z) + 1.7
	c.global_position = mid; c.look_at(cp + Vector3(0, f.base_h, 0), Vector3.UP)
	await shot("ravens_mid_30m")
	f.ts = 30.0; f.quiet = 60.0
	var t0 := Time.get_ticks_msec()
	while f.state != "ground" and Time.get_ticks_msec() - t0 < 15000: await process_frame
	await secs(1.0)
	var near := cp + Vector3(-6, 0, 3); near.y = w._ground_y(near.x, near.z) + 1.5
	c.global_position = near; c.look_at(cp + Vector3(0, 0.2, 0), Vector3.UP)
	await shot("ravens_landed_6m")
	c.fov = 30; await shot("ravens_landed_zoom")
	c.fov = 62
	# ---- aurora from the lookout deck
	w.clock.hour = 23.5
	var north: Vector3 = deck + out_dir * 100.0
	al.force_aurora = 0.0; await secs(1.0)
	c.global_position = deck; c.look_at(north + Vector3(0, 45, 0), Vector3.UP)
	await shot("night_north_no_aurora")
	al.force_aurora = 1.0; await secs(1.5)
	await shot("aurora_north")
	c.look_at(deck + Vector3(0, 100, 0) + out_dir * 45.0, Vector3.UP)
	await shot("aurora_overhead")
	c.global_position = deck; c.look_at(deck + out_dir * 80.0 + Vector3(0, -22, 0), Vector3.UP)
	await shot("aurora_snow_tint")
	al.force_aurora = 0.0; await secs(1.5)
	await shot("snow_no_aurora")
	quit(0)
