extends SceneTree
## Plan A5 review -> res://shots/stealth/: the awareness eye (faint / suspicious / chased) and a suspicious zombie staring.
var w: Node3D
var z: Zombie
var zp: Vector3
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(6)
	var img := root.get_texture().get_image()
	img.save_png("res://shots/stealth/" + id + ".png")
	var c := img.get_region(Rect2i(800 - 160, 450 - 120, 320, 200))   # the crosshair area, for judging the eye
	c.resize(640, 400, Image.INTERPOLATE_LANCZOS)
	c.save_png("res://shots/stealth/" + id + "_crop.png"); print("STEALTH_CAPTURE ", id)

func hold(s: float, face := true) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		z.global_position = zp
		if face:
			var to: Vector3 = w.player.global_position - zp
			z.rotation.y = atan2(-to.x, -to.z)
		await process_frame

func run() -> void:
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261026)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/stealth"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true; w.clock.hour = 15.0; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.world_events.enabled = false
	w.ambient_life.voices_enabled = false
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var dir := Vector3(-od.z, 0, od.x)
	zp = lk.global_position + od * 45.0; zp.y = w._ground_y(zp.x, zp.z)
	z = w._add_zombie(zp, 502)
	var pp: Vector3 = zp + dir * 15.0
	w.player.place(pp.x, pp.z)
	w.player.yaw = atan2(dir.x, dir.z)
	w.player.pitch = -0.03
	w.stealth_vis_override = 0.35
	z.awareness = 0.0
	await hold(0.7)
	await shot("eye_faint")
	await hold(2.0)
	print("STEALTH aware=", z.awareness, " sus=", z.suspicious, " state=", z.state)
	await shot("eye_suspicious")
	w.stealth_vis_override = 1.0
	await hold(2.5)
	await shot("eye_chase")
	quit(0)
