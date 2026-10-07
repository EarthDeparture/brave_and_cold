extends SceneTree
## Standalone actual skin review; no world saves or gameplay state.
func _initialize()->void:call_deferred("run")
func run()->void:
	create_timer(60).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1200,900)
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();env.environment=Environment.new();scene.add_child(env)
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.13,.16,.20)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.55
	env.environment.ambient_light_color=Color(.78,.85,.95)
	var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-45,-25,0)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.position=Vector3(1.8,1.35,-2.8);camera.look_at(Vector3(0,1.05,0))
	var z:=Zombie.new();scene.add_child(z);z.set_process(false)
	z._model=(load(Zombie.MODEL) as PackedScene).instantiate();z.add_child(z._model)
	for candidate:Node in z._model.find_children("*","Skeleton3D",true,false):z._skin=candidate as Skeleton3D;break
	for ap:AnimationPlayer in z._model.find_children("*","AnimationPlayer",true,false):ap.stop()
	for side:String in ["l","r"]:
		for pair:Array in [["zombie_arm_",z._arms],["zombie_leg_",z._legs],["zombie_knee_",z._knees],["zombie_elbow_",z._elbows]]:
			var driver:=z._model.find_child(pair[0]+side,true,false) as Node3D;pair[1].append(driver)
			z._skin_drivers[z._skin.find_bone("skin_"+String(driver.name))]=driver
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/opening-quality/infected"))
	for id:String in ["rest","walk","windup","impact","recovery"]:
		z._phase=0;z._state_t=.2;z.state=Zombie.State.IDLE;z.speed_now=0;z._attack_windup=-1
		if id!="rest":z.state=Zombie.State.CHASE;z.speed_now=1.4
		if id=="windup":z._attack_windup=.30
		if id=="impact":z._attack_windup=.03
		if id=="recovery":z._cd=.8
		z._animate(.12)
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://shots/opening-quality/infected/"+id+".png")
	print("INFECTED_SKIN_CAPTURE_COMPLETE");quit()
