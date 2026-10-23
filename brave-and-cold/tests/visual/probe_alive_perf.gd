extends SceneTree
## Frame cost of the alive systems at 1080p: drift (wind 15), tracks (full pools), ravens (3 flocks), each toggled.
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func measure(label: String) -> void:
	var vp := root.get_viewport_rid()
	await frames(30)
	var pr: Array[float] = []; var cpu: Array[float] = []; var gpu: Array[float] = []; var ft: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 240:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0); last = now
		pr.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	for a in [pr, cpu, gpu, ft]: a.sort()
	print("PERF %-22s frame %.2f ms  process %.2f  cpu %.2f  gpu %.2f  draws %d" % [label, ft[120], pr[120], cpu[120], gpu[120], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
func run() -> void:
	Engine.max_fps = 0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080); SaveGame.pending = {}; seed(5)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w._autosave_t = -100000; w.player.god = true; w.story_skip_to(1, 11.0); w.clock.hour = 13.0; w.clock.time_scale = 0.0
	w.weather.set_state(1, true); w.weather.locked = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var lk: Node3D = w.fire_lookout
	var od: Vector3 = (lk.to_global(Vector3(0, 0, -1)) - lk.global_position).normalized()
	var bp: Vector3 = lk.global_position + od * 40.0
	w.player.place(bp.x, bp.z)
	w.player.yaw = atan2(-od.x, -od.z)
	# fill the pools: tracks + blood everywhere in view
	var at: AnimalTracks = w.animal_tracks
	for i in AnimalTracks.POOL:
		var p: Vector3 = bp + od * randf_range(2, 40) + Vector3(-od.z, 0, od.x) * randf_range(-20, 20)
		at.stamp(["deer", "wolf", "bear", "hare"][i % 4], p, randf() * TAU, i % 2 == 0)
	for i in AnimalTracks.BLOOD_POOL:
		at.blood(bp + od * randf_range(2, 40) + Vector3(-od.z, 0, od.x) * randf_range(-20, 20), 0.3)
	var al: AmbientLife = w.ambient_life
	for k in 3:
		var n := Node3D.new(); w.add_child(n); var kp: Vector3 = bp + od * (60.0 + k * 30.0); kp.y = w._ground_y(kp.x, kp.z)
		n.global_position = kp; n.add_to_group("carcasses"); n.set_meta("scent_age_s", 900.0)
	al._scan()
	w.ground_drift.force_wind = 15.0
	await frames(120)
	await measure("all on (wind 15)")
	w.ground_drift.force_wind = 0.0; await frames(200)
	await measure("drift off")
	w.ground_drift.force_wind = 15.0; await frames(120)
	at.visible = false
	await measure("tracks hidden")
	at.visible = true
	for f in al.flocks: (f.mi as Node3D).visible = false
	al.set_process(false)
	await measure("ravens off")
	al.set_process(true)
	w.ground_drift.force_wind = 0.0; at.visible = false; al.set_process(false)
	for f in al.flocks: (f.mi as Node3D).visible = false
	await frames(200)
	await measure("all alive off")
	print("PERF height_samples/frame with drift: see ground_drift.height_samples")
	quit(0)
