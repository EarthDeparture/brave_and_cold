extends SceneTree
## Deterministic full-world art review. Does not load or write a player's save.
var world: Node3D
var output := ""
var records: Array[Dictionary] = []
var options := {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	output = String(options.get("capture_out", "res://shots/atmosphere/baseline"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0, true)
	SaveGame.pending = {}
	world = load("res://world/game_world.gd").new()
	root.add_child(world)
	for i in 600:
		await process_frame
		if world.hud != null:
			break
	if world.hud == null:
		push_error("World failed to become ready.")
		quit(1)
		return
	await process_frame
	_freeze(world)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.hud.hide()
	world.viewmodel.hide()
	if options.has("hands"):
		world.viewmodel.mode=String(options.hands)
		world.viewmodel._cur=world.viewmodel.mode
		world.viewmodel._equip=1.0
		world.viewmodel.freeze_t=0.0
		world.viewmodel.glove_item=String(options.get("gloves",""))
		world.viewmodel.show()
		world.viewmodel._process(0.0)
	world.snowfall.use_fixed_seed = true
	world.snowfall.seed = 42
	world.snowfall.fixed_fps = 60
	world.snowfall.speed_scale = 0.0
	var camera: Camera3D = world.player.cam
	camera.fov = 75.0
	camera.make_current()
	world.terrain.set_camera(camera)
	var tower: FireLookout = world.fire_lookout
	var lake_y: float = world.ice.ice_at(-1.0, 803.0)
	var forest_y: float = world.player._eye_ground(-120.0, 133.0)
	var locations := [
		{"id":"lookout","eye":tower.to_global(Vector3(-3.45, FireLookout.DECK_Y + 1.7, 0)), "target":Vector3(0, 85, 0), "inside":0.0},
		{"id":"lake","eye":Vector3(-1,lake_y+1.7,803), "target":Vector3(-80,lake_y+8,620), "inside":0.0},
		{"id":"forest","eye":Vector3(-120,forest_y+1.7,133), "target":Vector3(-160,forest_y+4,50), "inside":0.0},
		{"id":"interior","eye":tower.to_global(Vector3(1.7,FireLookout.DECK_Y+1.7,0.6)), "target":tower.to_global(Vector3(-1.3,FireLookout.DECK_Y+1.6,-2.7)), "inside":1.0}
	]
	var states := [
		{"id":"clear","hour":12.0,"state":Weather.S.CLEAR},
		{"id":"overcast","hour":12.0,"state":Weather.S.CLOUDY},
		{"id":"dusk","hour":17.2,"state":Weather.S.CLEAR},
		{"id":"night","hour":23.0,"state":Weather.S.CLEAR},
		{"id":"blizzard","hour":12.0,"state":Weather.S.BLIZZARD}
	]
	for state in states:
		for location in locations:
			if options.has("only") and String(options.only) != String(state.id) + "-" + String(location.id):
				continue
			world.player.global_position = location.eye
			camera.global_position = location.eye
			camera.look_at(location.target)
			world.clock.hour = state.hour
			world.weather._t = 0.0
			world.weather.lock_state(state.state)
			world.weather.advance(120.0,0.0)
			if world.sky_rig.has_method("set_cloud_offset"):
				world.sky_rig.set_cloud_offset(Vector2(0.17,0.08))
			elif world.sky_rig.clouds != null:
				world.sky_rig.clouds._t = 120.0
				world.sky_rig.clouds._process(0.0)
			world.sky_rig.apply_hour(state.hour)
			if world.sky_rig is AtmosphereRig:
				print('SKY_INPUT ',state.id,' state=',world.weather.state,' overcast=',world.weather.overcast,' coverage=',world.weather.coverage,' uniform=',world.sky_rig.material.get_shader_parameter('overcast'),' sun=',world.sun.light_energy)
			if world.sky_rig.has_method('snow_tint'):
				world.snowfall.set_light_tint(world.sky_rig.snow_tint())
			var indoor: float = location.inside
			if world.sky_rig.has_method("apply_shelter"):
				world.sky_rig.apply_shelter(indoor)
			else:
				world.env.fog_density *= lerpf(1.0, world.INDOOR_FOG_MULT, indoor)
				world.env.ambient_light_energy *= lerpf(1.0, world.INDOOR_AMBIENT_MULT, indoor)
				world.env.ambient_light_color = world.env.ambient_light_color.lerp(Color(0.62,0.50,0.42),0.3*indoor)
			var night: float = clampf(1.0-world.sun.light_energy/0.7,0.0,1.0)
			if "gameplay_night_factor" in world.sky_rig:
				night = world.sky_rig.gameplay_night_factor
			for cabin in world.cabins:
				cabin.set_night(night)
			for i in 5:
				world.snowfall._process(0.0)
				await process_frame
			world.snowfall.visible = world.weather.precip > 0.02
			if world.snowfall.visible:
				world.snowfall.restart(true)
				world.snowfall.request_particles_process(4.0)
			for i in 45:
				await process_frame
			var samples: Array[float] = []
			for i in 100:
				var start := Time.get_ticks_usec()
				await process_frame
				await RenderingServer.frame_post_draw
				samples.append(float(Time.get_ticks_usec()-start)/1000.0)
			samples.sort()
			var id: String = String(state.id)+"-"+String(location.id)
			var path := output.path_join(id+".png")
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("Capture failed: "+path)
				quit(1)
				return
			var record := {"id":id,"hour":state.hour,"weather":state.id,"eye":_vector(location.eye),"target":_vector(location.target),"inside":indoor,"fov":camera.fov,"median_ms":samples[50],"p99_ms":samples[98],"file":path,"sha256":FileAccess.get_sha256(path),"overcast":world.weather.overcast,"cloud_coverage":world.weather.coverage,"fog_density":world.env.fog_density,"sun_energy":world.sun.light_energy,"particle_tint":str(world.snowfall._winter_material.get_shader_parameter("flake_tint")) if world.snowfall._winter_material!=null else "legacy"}
			records.append(record)
			print("ATMOSPHERE_CAPTURE ", JSON.stringify(record))
	var manifest := {"schema":1,"capture_script":"tests/visual/capture_atmosphere.gd","atmosphere":options.get("atmosphere","baseline"),"resolution":[root.size.x,root.size.y],"gpu":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"engine":Engine.get_version_info().string,"population":"disabled for isolated renderer comparison","wind_phase_s":120,"particle_seed":42,"cloud_offset":[0.17,0.08],"captures":records}
	var sources := {}
	for path in ["res://world/game_world.gd","res://world/sky_rig.gd","res://world/atmosphere_rig.gd","res://systems/weather.gd","res://world/snow_fall.gd","res://world/shaders/winter_sky.gdshader","res://world/shaders/winter_snow.gdshader","res://world/shaders/frozen_water.gdshader","res://data/terrain/terrain_winter_assets.tres","res://assets/textures/atmosphere/cloud_fields.png"]:
		sources[path]=FileAccess.get_sha256(path)
	manifest["source_hashes"]=sources
	manifest["render_settings"]={"msaa":root.msaa_3d,"ssao":world.env.ssao_enabled,"tonemap":world.env.tonemap_mode,"sun_bias":world.sun.shadow_bias,"sun_normal_bias":world.sun.shadow_normal_bias,"sun_shadow_distance":world.sun.directional_shadow_max_distance}
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("ATMOSPHERE_CAPTURE_COMPLETE ",records.size())
	quit()

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze(child)

func _vector(v: Vector3) -> Array[float]:
	return [v.x,v.y,v.z]
