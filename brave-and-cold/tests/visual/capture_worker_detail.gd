extends SceneTree
## Matched old/new imported worker at encounter distance; no saves.
func _initialize()->void:call_deferred("run")
func actor(scene:Node3D,path:String)->Zombie:
	var z:=Zombie.new();scene.add_child(z);z.set_process(false)
	z._model=(load(path) as PackedScene).instantiate();z.add_child(z._model)
	for n:Node in z._model.find_children("*","Skeleton3D",true,false):z._skin=n as Skeleton3D;break
	for ap:AnimationPlayer in z._model.find_children("*","AnimationPlayer",true,false):ap.stop()
	for side:String in ["l","r"]:
		for pair:Array in [["zombie_arm_",z._arms],["zombie_leg_",z._legs],["zombie_knee_",z._knees],["zombie_elbow_",z._elbows]]:
			var joint:=z._model.find_child(pair[0]+side,true,false) as Node3D;pair[1].append(joint)
			z._skin_drivers[z._skin.find_bone("skin_"+String(joint.name))]=joint
	z._bind_skin_drivers();return z
func run()->void:
	create_timer(60).timeout.connect(func()->void:quit(2));root.size=Vector2i(1400,900)
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();scene.add_child(env);env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.16,.21)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.75,.83,.94);env.environment.ambient_light_energy=.6
	env.environment.tonemap_mode=Environment.TONE_MAPPER_ACES;env.environment.ssao_enabled=true
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=.8;sun.shadow_enabled=true
	var floor_mesh:=MeshInstance3D.new();scene.add_child(floor_mesh);floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(12,12)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.67,.75,.82);mat.roughness=.96;floor_mesh.material_override=mat
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=45;camera.position=Vector3(1.65,1.45,-3.0);camera.look_at(Vector3(0,1.03,0))
	var lamp:=SpotLight3D.new();camera.add_child(lamp);lamp.spot_range=12;lamp.spot_angle=35;lamp.light_color=Color(1,.9,.73);lamp.light_energy=2;lamp.visible=false
	var out:="res://shots/worker-detail";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for variant:String in ["before","after"]:
		var z:=actor(scene,"res://assets/infected/skin/winter_worker_skin.glb" if variant=="before" else Zombie.MODEL)
		for lighting:String in ["overcast","headlamp"]:
			lamp.visible=lighting=="headlamp";sun.visible=not lamp.visible;env.environment.ambient_light_energy=.10 if lamp.visible else .6
			for pose:String in ["rest","attack","face"]:
				z.speed_now=0;z._gait_speed=-1;z._phase=0;z.state=Zombie.State.IDLE;z._attack_windup=-1
				if pose=="attack":z.state=Zombie.State.CHASE;z._attack_windup=.12
				z._animate(.1)
				camera.position=Vector3(.35,1.7,-.85) if pose=="face" else Vector3(1.65,1.45,-3)
				camera.look_at(Vector3(0,1.65,-.01) if pose=="face" else Vector3(0,1.03,0))
				for i in 5:await process_frame
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+variant+"-"+lighting+"-"+pose+".png")
		z.free()
	print("WORKER_DETAIL_CAPTURE_COMPLETE");quit()
