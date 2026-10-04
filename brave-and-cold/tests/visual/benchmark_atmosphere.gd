extends SceneTree
## Matched moving-camera benchmark with continuously updated sky and weather.
## Population is off for renderer comparison; live=1 exercises normal gameplay.
var world: Node3D
var output := "res://shots/atmosphere/motion"
var options := {}
var records: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=",true,1)
		options[p[0]]=p[1] if p.size()>1 else "1"
	output=String(options.get("capture_out",output))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0,true)
	SaveGame.pending={}
	world=load("res://world/game_world.gd").new()
	root.add_child(world)
	for i in 600:
		await process_frame
		if world.hud!=null: break
	if world.hud==null: quit(1); return
	await process_frame
	if not options.has("live"):
		_freeze(world)
	else:
		world.player.frozen=true
		world.player.god=true
		world._autosave_t=-10000.0
		world.sky_rig.set_process(false)
		world.weather.lock_state(Weather.S.CLOUDY)
		world.clock.time_scale=0.0
	world.hud.hide()
	world.viewmodel.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var camera: Camera3D=world.player.cam
	camera.fov=75.0
	camera.make_current()
	world.terrain.set_camera(camera)
	var tower:FireLookout=world.fire_lookout
	var cases := [
		{"id":"deck-day","hour":12.0,"weather":Weather.S.CLEAR,"a":tower.to_global(Vector3(-3.45,FireLookout.DECK_Y+1.7,-1.3)),"b":tower.to_global(Vector3(-3.45,FireLookout.DECK_Y+1.7,1.3)),"target":Vector3(0,85,0),"indoor":false},
		{"id":"forest-overcast","hour":12.0,"weather":Weather.S.CLOUDY,"a":Vector3(-120,0,133),"b":Vector3(-132,0,106),"target":Vector3(-160,12,50),"indoor":false},
		{"id":"shore-dusk","hour":17.2,"weather":Weather.S.CLEAR,"a":Vector3(-1,0,803),"b":Vector3(-15,0,786),"target":Vector3(-80,16,620),"indoor":false},
		{"id":"shelter-storm","hour":12.0,"weather":Weather.S.BLIZZARD,"a":tower.to_global(Vector3(0,FireLookout.DECK_Y+1.7,0)),"b":tower.to_global(Vector3(0,FireLookout.DECK_Y+1.7,2.95)),"target":tower.to_global(Vector3(0,FireLookout.DECK_Y+1.6,6)),"indoor":true},
		{"id":"forest-night","hour":23.0,"weather":Weather.S.CLEAR,"a":Vector3(-120,0,133),"b":Vector3(-132,0,106),"target":Vector3(-160,12,50),"indoor":false},
		{"id":"sky-cycle","hour":0.0,"weather":Weather.S.CLEAR,"a":Vector3(-1,0,803),"b":Vector3(-1,0,803),"target":Vector3(-180,170,620),"indoor":false}
	]
	var repeats:=1 if options.has("film") else 3
	var steps:=240 if options.has("film") else 360
	for scenario in cases:
		if options.has("only") and options.only!=scenario.id: continue
		for repeat in repeats:
			world.weather._t=0.0
			world.weather.lock_state(scenario.weather)
			if world.sky_rig is AtmosphereRig:
				world.sky_rig.set_cloud_offset(Vector2(0.17,0.08))
			elif world.sky_rig.clouds!=null:
				world.sky_rig.clouds._t=120.0
			var samples:Array[float]=[]
			var cpu_samples:Array[float]=[]
			for frame in steps+60:
				var frame_start := Time.get_ticks_usec()
				var t:=clampf(float(frame-60)/float(steps-1),0.0,1.0)
				var eye:Vector3=scenario.a.lerp(scenario.b,t)
				if scenario.id.begins_with("forest") or scenario.id.begins_with("shore") or scenario.id=="sky-cycle":
					eye.y=world.player._eye_ground(eye.x,eye.z)+1.7
				world.player.global_position=eye
				camera.global_position=eye
				camera.look_at(scenario.target)
				if scenario.id=="deck-day": camera.rotate_object_local(Vector3.UP,sin(t*TAU)*0.12)
				world.clock.hour=float(scenario.hour)+t*0.08
				if scenario.id=="sky-cycle": world.clock.hour=t*24.0
				world.weather.advance(1.0/60.0,0.0)
				world.sky_rig.apply_hour(world.clock.hour)
				if world.sky_rig.has_method("_process"): world.sky_rig._process(1.0/60.0)
				if world.sky_rig.clouds!=null: world.sky_rig.clouds._process(1.0/60.0)
				var sheltered:bool=tower.contains_room(eye) if scenario.indoor else false
				world._indoor_k=move_toward(world._indoor_k,1.0 if sheltered else 0.0,1.0/30.0)
				if world.sky_rig is AtmosphereRig:
					world.sky_rig.apply_shelter(world._indoor_k)
					world.snowfall.set_light_tint(world.sky_rig.snow_tint())
				elif world._indoor_k>0:
					world.env.fog_density*=lerpf(1.0,world.INDOOR_FOG_MULT,world._indoor_k)
					world.env.ambient_light_energy*=lerpf(1.0,world.INDOOR_AMBIENT_MULT,world._indoor_k)
					world.env.ambient_light_color=world.env.ambient_light_color.lerp(Color(0.62,0.5,0.42),0.3*world._indoor_k)
				world.snowfall._process(1.0/60.0)
				await process_frame
				await RenderingServer.frame_post_draw
				if frame>=60:
					samples.append(float(Time.get_ticks_usec()-frame_start)/1000.0)
					cpu_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
				if options.has("film") and frame>=60 and (frame-60)%6==0:
					root.get_texture().get_image().save_png(output.path_join(String(scenario.id)+"-%03d.png"%((frame-60)/6)))
			samples.sort()
			cpu_samples.sort()
			var row:={"id":scenario.id,"repeat":repeat+1,"frames":samples.size(),"median_ms":samples[samples.size()/2],"p99_ms":samples[int(samples.size()*0.99)-1],"engine_process_median_ms":cpu_samples[cpu_samples.size()/2]}
			records.append(row)
			print("ATMOSPHERE_MOTION ",JSON.stringify(row))
			if repeat==0:
				root.get_texture().get_image().save_png(output.path_join(scenario.id+".png"))
	var manifest:={"schema":1,"atmosphere":options.get("atmosphere","winter"),"live_gameplay":options.has("live"),"performance_valid":not options.has("film"),"gpu":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"repeats":repeats,"scenarios":records}
	var file:=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")); file.close()
	print("ATMOSPHERE_MOTION_COMPLETE")
	quit()
func _freeze(node:Node)->void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): _freeze(child)
