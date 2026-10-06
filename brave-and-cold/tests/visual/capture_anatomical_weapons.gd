extends SceneTree
## Actual live viewmodel review, without loading terrain or changing saves.
var p: Player
var vm: Viewmodel
var output := "res://shots/anatomical-weapons"
var records: Array = []
func _initialize() -> void: call_deferred("run")
func capture(id: String) -> void:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(id+".png")
	root.get_texture().get_image().save_png(path)
	records.append({"id":id,"sha256":FileAccess.get_sha256(path)})
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var env := WorldEnvironment.new(); root.add_child(env); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(.075,.095,.115)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(.8,.87,1); env.environment.ambient_light_energy = .65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sun := DirectionalLight3D.new(); root.add_child(sun); sun.rotation_degrees = Vector3(-50,-20,0); sun.light_energy = 1.0
	p = Player.new(); root.add_child(p); p.set_process(false); p.set_physics_process(false)
	p.cam = Camera3D.new(); p.add_child(p.cam); p.cam.current = true; p.cam.near = .015; p.cam.fov = 70
	vm = Viewmodel.new(); vm.player = p; vm.detail_enabled = true; p.cam.add_child(vm); vm.set_process(false)
	vm.freeze_t = 0; vm._equip = 1; vm._clock = 0
	for gloves: String in ["","hide_mitts"]:
		vm.glove_item = gloves; var tag := "bare" if gloves == "" else "glove"
		vm.mode = "fists"; vm._cur = "fists"; vm._swing_t = -1; vm._fire_t = -1; vm._guard_k = 0; vm._process(0); await capture("empty-"+tag)
		vm._guard_k = 1; vm._process(0); await capture("guard-"+tag)
		vm.swing(false); vm.freeze_t = .14; vm._process(0); await capture("punch-"+tag)
		vm._swing_t = -1; vm._guard_k = 0; vm.mode = "axe"; vm._cur = "axe"; vm._process(0); await capture("axe-"+tag)
		vm.begin_work("hammer",2); vm.update_work(.6); vm._process(0); await capture("hammer-"+tag); vm.end_work(false)
		for id: String in WeaponPresentation.IDS:
			vm.equip_weapon(id); vm.mode = "rifle"; vm._cur = "rifle"; vm._equip = 1; vm._fire_t = -1; vm._swing_t = -1
			p.aim_k = 0; p.cam.fov = 70; vm._process(0); await capture(id+"-hip-"+tag)
			p.aim_k = 1; p.cam.fov = 36; vm._process(0); await capture(id+"-aim-"+tag)
			p.aim_k = 0; p.cam.fov = 70; vm.fire(); vm.freeze_t = .62; vm._process(0); await capture(id+"-action-"+tag); vm._fire_t = -1
			var clip := "reload_insert" if id == "brush_lever_rifle" else "reload_empty"
			vm.play_weapon_clip(clip); vm._weapon_clip_t = .40 if id == "brush_lever_rifle" else .85; vm._process(0); await capture(id+"-reload-"+tag); vm.cancel_weapon_clip()
		vm.equip_weapon("timber_bolt_carbine")
		for kind: String in ["reach","drink","treat"]:
			vm.begin_work(kind,1.7); vm.update_work(.85); vm._process(0); await capture(kind+"-"+tag); vm.end_work(false)
		vm.watch_override = true; vm._process(.5); await capture("watch-"+tag); vm.watch_override = false; vm._process(.5)
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"hands_sha256":FileAccess.get_sha256("res://assets/models/viewmodel/anatomical_hand_rig.glb"),"captures":records},"  ")); file.close()
	print("ANATOMICAL_WEAPON_CAPTURE_PASS shots=",records.size()); quit()
