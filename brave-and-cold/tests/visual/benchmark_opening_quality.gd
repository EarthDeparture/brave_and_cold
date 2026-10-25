extends SceneTree
## Normal game processing + actual physics walking at 1080p, fixed-duration cases.
## Benchmark god mode prevents interruption; survival, AI, weather remain active.
var w:Node3D
var options:Dictionary={}
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	create_timer(240).timeout.connect(func()->void:quit(2))
	for arg:String in OS.get_cmdline_user_args():
		var p:=arg.split("=",true,1);options[p[0]]=p[1] if p.size()>1 else "1"
	var out:String=options.get("capture_out","res://shots/opening-quality/performance/candidate")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);AudioServer.set_bus_mute(0,true)
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.collapse!=null and w.reading!=null:break
	if w.collapse==null:quit(1);return
	if w.opening_state.seed_value!=int(options.get("opening_seed",20261004)):
		push_error("Benchmark requires opening_seed=20261004 (or an explicit matching seed)");quit(1);return
	w._frames=100;w.out_path="benchmark-no-autosave";w._autosave_t=-10000
	w.player.sim_on=true;w.player.frozen=false;w.player.god=true;w.player.noclip=false;w.player.cam.fov=70
	w.opening_zombie_count=250;w.opening_state.last_s=96*3600;w.collapse.update(0)
	w.clock.day=5;w.clock.total_game_s=96*3600;w.opening_state.align_calendar(5,12,w.clock.total_game_s,true)
	root.content_scale_size=Vector2i(1920,1080);DisplayServer.window_set_size(Vector2i(1920,1080));root.size=Vector2i(1920,1080)
	await process_frame;await RenderingServer.frame_post_draw
	if root.get_texture().get_width()!=1920 or root.get_texture().get_height()!=1080:push_error("Incorrect benchmark resolution");quit(1);return
	var path:Array=w.fire_lookout.site.path.points_world_xyz
	var a:Array=path[70];var b:Array=path[110];var road:Vector2=w.road.points[180];var end:Vector2=w.road.points[208]
	var cases:Array=[{"id":"logging-forest","a":Vector2(a[0],a[2]),"b":Vector2(b[0],b[2]),"weather":Weather.S.CLOUDY,"hour":12.0},{"id":"town-road","a":road,"b":end,"weather":Weather.S.CLEAR,"hour":12.0},{"id":"storm-route","a":Vector2(a[0],a[2]),"b":Vector2(b[0],b[2]),"weather":Weather.S.BLIZZARD,"hour":17.0}]
	var clinic:Clinic=w.collapse.clinic
	var entry:=clinic.to_global(Vector3(8,0,10));var exit:=clinic.to_global(Vector3(8,0,35))
	cases.append({"id":"clinic-encounter","a":Vector2(entry.x,entry.z),"b":Vector2(exit.x,exit.z),"weather":Weather.S.CLOUDY,"hour":12.0})
	for scenario:Dictionary in cases:
		for repeat in 3:
			w.player.sim_dir=Vector3.ZERO;w.player.place(scenario.a.x,scenario.a.y);w.needs.calories=2000;w.needs.water=85;w.needs.fatigue=0;w.body.core=37
			w.clock.hour=scenario.hour;w.weather.lock_state(scenario.weather);w.weather.advance(120,0)
			var start_s:=Time.get_ticks_msec();var samples:Array[float]=[];var process_ms:Array[float]=[];var active_max:=0;var proxy_max:=0
			var entry_frames:Array[float]=[];var population_us:Array[int]=[];var entry_population_us:Array[int]=[];var pool_min:int=w.pop.pool.size()
			var initial:Vector3=w.player.position;var game_start:float=w.clock.total_game_s;var last:=Time.get_ticks_usec();var low_cal:float=w.needs.calories
			while Time.get_ticks_msec()-start_s<12000:
				var toward:Vector2=(scenario.b-Vector2(w.player.position.x,w.player.position.z)).normalized()
				w.player.sim_dir=Vector3(toward.x,0,toward.y);w.player.yaw=atan2(-toward.x,-toward.y);w.player.pitch=-.055;w.player.rotation.y=w.player.yaw;w.player.cam.rotation.x=w.player.pitch
				await process_frame;await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				if Time.get_ticks_msec()-start_s>=3000:
					samples.append(float(now-last)/1000);process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);population_us.append(w.pop.last_tick_us)
				else:entry_frames.append(float(now-last)/1000);entry_population_us.append(w.pop.last_tick_us)
				pool_min=mini(pool_min,w.pop.pool.size())
				last=now;active_max=maxi(active_max,w.pop.active.size());proxy_max=maxi(proxy_max,w.pop.proxy_n);low_cal=minf(low_cal,w.needs.calories)
			w.player.sim_dir=Vector3.ZERO;samples.sort();process_ms.sort()
			entry_frames.sort();population_us.sort();entry_population_us.sort()
			var n:=samples.size();var hitches:=0
			for value:float in samples:if value>33.333:hitches+=1
			var row:={"case":scenario.id,"repeat":repeat+1,"frames":n,"median_ms":samples[n/2],"p95_ms":samples[int(n*.95)],"p99_ms":samples[int(n*.99)],"max_ms":samples[-1],"hitches_over_33ms":hitches,"engine_process_median_ms":process_ms[n/2],"walked_m":Vector2(initial.x,initial.z).distance_to(Vector2(w.player.position.x,w.player.position.z)),"game_seconds_advanced":w.clock.total_game_s-game_start,"calories_used":2000-low_cal,"active_infected_max":active_max,"proxy_max":proxy_max}
			row.merge({"entry_p99_ms":entry_frames[int(entry_frames.size()*.99)],"entry_max_ms":entry_frames[-1],"population_tick_p99_us":population_us[int(n*.99)],"population_tick_max_us":population_us[-1],"entry_population_tick_max_us":entry_population_us[-1],"pool_min":pool_min})
			rows.append(row);print("OPENING_MOTION ",JSON.stringify(row))
			if repeat==0:root.get_texture().get_image().save_png(out+"/"+scenario.id+".png")
	var receipt:={"gpu":RenderingServer.get_video_adapter_name(),"renderer":"Forward+ D3D12","resolution":[1920,1080],"opening_seed":w.opening_state.seed_value,"forest_crowns":options.get("forest_crowns","winter"),"sky_clouds":options.get("sky_clouds","winter"),"forest_near_end_m":w.forest.near_end,"forest_group_m":w.forest._chunk_m,"population_target":250,"samples":rows,"limitations":"Four 12-second moving cases, three repeats, 3-second warmup. Actual Player physics, world survival/weather and normal AI processing active. God mode prevents damage interruptions, inventory consumption is disabled, audio muted. Same current gameplay code in both visual profiles; not a baseline-commit comparison. Does not cover combat, full town density, autosave IO or human play. Population activation can vary with elapsed simulation and movement; compare the recorded active counts as well as frame times."}
	receipt["implementation"]=options.get("implementation","unlabelled")
	receipt["limitations"]="Four 12-second moving cases, three repeats. First three seconds retained as entry data; subsequent nine seconds form warm metrics. Actual Player physics, survival/weather and normal AI processing remain active. God mode, muted audio and disabled inventory consumption avoid interruptions. Assignment seed verified before cohort issuance. Population activation can vary with elapsed simulation and movement; compare recorded active counts. Local frame intervals and population tick timers, not GPU attribution or a statistical causal result. Does not cover combat, full town density, autosave IO, minimum hardware or human play."
	var f:=FileAccess.open(out+"/manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  "));f.close()
	w.queue_free();await process_frame;SaveGame.pending={};print("OPENING_MOTION_COMPLETE");quit()
