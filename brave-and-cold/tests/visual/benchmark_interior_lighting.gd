extends SceneTree
## Frame cost of the interior lighting standard where it is worst: the hamlet, with
## several cabins (each 3 window pools + fill + fire bounce) in view, and inside the store.
## Alternating on/off samples at 1080p; local diagnostic only.
var w: Node3D
func _initialize() -> void:call_deferred("run")
func median(a: Array[float]) -> float:a.sort();return a[a.size()/2]
func aim(eye: Vector3, target: Vector3) -> void:
	w.player.position=eye;var d:=target-eye
	w.player.yaw=atan2(-d.x,-d.z);w.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	w.player.cam.rotation=Vector3(w.player.pitch,w.player.yaw,0)
func set_lights(on: bool) -> void:
	for il: Node in get_nodes_in_group("interior_lighting"):(il as Node3D).visible=on
func sample(label: String) -> Array:
	var vp:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(vp,true)
	var rows: Array=[]
	for variant: String in ["off","on","on","off","off","on"]:
		set_lights(variant=="on")
		var frames: Array[float]=[];var gpu: Array[float]=[]
		var start:=Time.get_ticks_msec();var last:=Time.get_ticks_usec()
		while Time.get_ticks_msec()-start<6000:
			await process_frame;await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			if Time.get_ticks_msec()-start>=1500:frames.append((now-last)/1000.0);gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			last=now
		var row:={"scene":label,"variant":variant,"median_ms":median(frames),"p95_ms":frames[int(frames.size()*.95)],"gpu_median_ms":median(gpu)}
		rows.append(row);print("INTERIOR_BUDGET ",JSON.stringify(row))
	return rows
func run() -> void:
	create_timer(240).timeout.connect(func() -> void:quit(2));root.size=Vector2i(1920,1080)
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);AudioServer.set_bus_mute(0,true)
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	w._frames=100;w.out_path="benchmark-no-autosave";w._autosave_t=-10000;w.player.god=true;w.player.frozen=true
	w.clock.hour=12;w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0);w.sky_rig.apply_hour(12)
	root.content_scale_size=Vector2i(1920,1080);DisplayServer.window_set_size(Vector2i(1920,1080));root.size=Vector2i(1920,1080)
	var centre:=Vector3.ZERO;var n:=0
	for i in range(1,w.cabins.size()):centre+=w.cabins[i].global_position;n+=1
	centre/=maxf(1,n)
	for cb: Cabin in w.cabins:cb.stove_fuel_s=4*3600
	aim(centre+Vector3(22,6,22),centre+Vector3(0,1,0))
	for i in 90:await process_frame
	var rows:=await sample("hamlet_%d_cabins"%n)
	var store: Store=w.stores[0]
	aim(store.to_global(Vector3(-2.5,Store.FLOOR_LOCAL_Y+1.6,1.6)),store.to_global(Vector3(2.4,Store.FLOOR_LOCAL_Y+.8,-1.6)))
	for i in 60:await process_frame
	rows.append_array(await sample("store_inside"))
	print("INTERIOR_BUDGET_GPU ",RenderingServer.get_video_adapter_name())
	w.queue_free();await process_frame;SaveGame.pending={};print("INTERIOR_BUDGET_COMPLETE");quit()
