extends SceneTree
## Actual viewmodel action poses; no inventory transactions or world saves.
func _initialize()->void:call_deferred("run")
func run()->void:
	create_timer(60).timeout.connect(func()->void:quit(2));root.size=Vector2i(1600,900)
	var env:=WorldEnvironment.new();env.environment=Environment.new();root.add_child(env)
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.19,.23,.28)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.75,.83,.95);env.environment.ambient_light_energy=.60
	env.environment.tonemap_mode=Environment.TONE_MAPPER_ACES
	var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-45,-25,0)
	var p:=Player.new();root.add_child(p);p.set_process(false);p.set_physics_process(false)
	p.cam=Camera3D.new();p.add_child(p.cam);p.cam.current=true;p.cam.near=.015;p.cam.fov=70
	var vm:=Viewmodel.new();vm.player=p;vm.detail_enabled=true;p.cam.add_child(vm);vm.set_process(false);vm.mode="fists";vm._cur="fists";vm._equip=1
	var out:="res://shots/opening-quality/interactions/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for gloves:bool in [false,true]:
		vm.glove_item="hide_mitts" if gloves else ""
		for action:String in ["drink","treat","reach","hammer"]:
			vm.begin_work(action,2)
			for t:float in [.25,.50,.75]:
				vm.update_work(t*2);vm._process(0)
				for i in 4:await process_frame
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+action+("_gloved" if gloves else "_bare")+"_%02d.png"%int(t*100))
			vm.end_work(false)
	print("OPENING_INTERACTIONS_CAPTURE_COMPLETE");p.free();quit()
