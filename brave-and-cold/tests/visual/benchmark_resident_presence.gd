extends SceneTree
var w: Node3D
func _initialize() -> void:call_deferred("run")
func median(a: Array[float]) -> float:a.sort();return a[a.size()/2]
func run() -> void:
	create_timer(180).timeout.connect(func() -> void:quit(2));root.size=Vector2i(1920,1080)
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);AudioServer.set_bus_mute(0,true)
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.town_life!=null and w.gear!=null:break
	w._frames=100;w.out_path="benchmark-no-autosave";w._autosave_t=-10000;w.player.god=true;w.player.frozen=true
	var life: TownLife=w.town_life
	w.player.position=life.store.to_global(Vector3(.1,1.85,1.35));w.player._ready_ground=true;w.player.rotation=Vector3.ZERO
	var direction: Vector3=life.store.to_global(Vector3(2.52,1.2,.2))-w.player.position
	w.player.yaw=atan2(-direction.x,-direction.z);w.player.pitch=atan2(direction.y,Vector2(direction.x,direction.z).length())
	w.player.cam.rotation=Vector3(w.player.pitch,w.player.yaw,0)
	w.clock.hour=12;w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0);w.sky_rig.apply_hour(12)
	root.content_scale_size=Vector2i(1920,1080);DisplayServer.window_set_size(Vector2i(1920,1080));root.size=Vector2i(1920,1080)
	for i in 90:await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_width()==1920 and root.get_texture().get_height()==1080,"Timing requires actual 1080p viewport")
	var vp:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(vp,true)
	var rows: Array=[]
	for variant: String in ["off","on","on","off","off","on"]:
		for a: TownResident in life.actors.values():a.visible=variant=="on";a.set_process(variant=="on")
		var frames: Array[float]=[];var gpu: Array[float]=[];var cpu: Array[float]=[];var draws: Array[float]=[]
		var start:=Time.get_ticks_msec();var last:=Time.get_ticks_usec();var visible_max:=0
		while Time.get_ticks_msec()-start<8000:
			await process_frame;await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			if Time.get_ticks_msec()-start>=2000:
				frames.append((now-last)/1000.0);gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp));cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				var visible_count:=0
				for a: TownResident in life.actors.values():
					if a.visible and w.player.cam.is_position_in_frustum(a.global_position+Vector3.UP):visible_count+=1
				visible_max=maxi(visible_max,visible_count)
			last=now
		assert(variant=="off" or visible_max>0,"Enabled sample must see a resident")
		frames.sort();var row:={"variant":variant,"frames":frames.size(),"median_ms":median(frames),"p95_ms":frames[int(frames.size()*.95)],"gpu_median_ms":median(gpu),"render_cpu_median_ms":median(cpu),"draws_median":median(draws),"resident_nodes":life.actors.size(),"visible_centres_max":visible_max}
		rows.append(row);print("PRESENCE_BUDGET ",JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/resident-presence-world"))
	var file:=FileAccess.open("res://shots/resident-presence-world/timing.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"gpu":RenderingServer.get_video_adapter_name(),"engine_arguments":OS.get_cmdline_args(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.get_texture().get_width(),root.get_texture().get_height()],"seed":w.opening_state.seed_value,"scope":"Same current quiet-day shop scene, resident visibility/processing on versus off. Six alternating eight-second runs with two-second warmup. Terrain, weather, post effects, props and anonymous reserve unchanged. Local diagnostic, uncontrolled host load; not a previous-commit comparison or minimum-spec acceptance."},"\t"));file.close()
	w.queue_free();await process_frame;SaveGame.pending={};print("PRESENCE_BUDGET_COMPLETE");quit()
