extends SceneTree
## Frame cost of a cabin blaze in view at 1080p (night): no fire / blaze 30 m / blaze collapsed / smoulder.
var w: Node3D
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func measure(label: String) -> void:
	var vp := root.get_viewport_rid()
	await frames(30)
	var cpu: Array[float] = []; var gpu: Array[float] = []; var ft: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 240:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0); last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	for a in [cpu, gpu, ft]: a.sort()
	print("PERF %-22s frame %.2f ms  cpu %.2f  gpu %.2f" % [label, ft[120], cpu[120], gpu[120]])
func run() -> void:
	Engine.max_fps = 0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1920, 1080); SaveGame.pending = {}; seed(5)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.world_events != null and bool(w.get("built")): break
	w.out_path = ""; w._autosave_t = -100000; w.player.god = true; w.clock.day = 5; w.clock.hour = 22.5; w.clock.time_scale = 0.0
	w.weather.set_state(0, true); w.weather.locked = true
	w.world_events.enabled = false
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var cb: Cabin = w.cabins[3]
	var hc := Vector3.ZERO
	for o in w.cabins: hc += o.global_position
	hc /= float(w.cabins.size())
	var out: Vector3 = cb.global_position - hc; out.y = 0; out = out.normalized()
	var p: Vector3 = cb.global_position + out * 30.0
	w.player.place(p.x, p.z)
	w.player.yaw = atan2(out.x, out.z)
	w.player.pitch = 0.15
	await frames(60)
	await measure("no fire")
	var now: float = w.clock.total_game_s
	w.world_events.start_fire(3, now - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.2)
	await create_timer(30.0).timeout
	await measure("blaze (roof on)")
	cb.on_fire.start_s = now - CabinFire.IGNITE_S - CabinFire.BLAZE_S * 0.5
	await create_timer(20.0).timeout
	await measure("blaze (collapsed)")
	cb.on_fire.start_s = now - CabinFire.IGNITE_S - CabinFire.BLAZE_S - CabinFire.SMOULDER_S * 0.2
	await create_timer(10.0).timeout
	await measure("smoulder")
	quit(0)
