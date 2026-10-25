extends SceneTree
func _initialize()->void:call_deferred("run")
func actor(scene:Node3D,id:int)->Zombie:
	var z:=Zombie.new();scene.add_child(z);z.set_process(false);z._id=id
	z._model=(load(Zombie.MODEL) as PackedScene).instantiate();z.add_child(z._model)
	for node:Node in z._model.find_children("*","Skeleton3D",true,false):z._skin=node as Skeleton3D;break
	for ap:AnimationPlayer in z._model.find_children("*","AnimationPlayer",true,false):ap.stop()
	for side:String in ["l","r"]:
		for pair:Array in [["zombie_arm_",z._arms],["zombie_leg_",z._legs],["zombie_knee_",z._knees],["zombie_elbow_",z._elbows]]:
			var joint:=z._model.find_child(pair[0]+side,true,false) as Node3D;pair[1].append(joint)
			z._skin_drivers[z._skin.find_bone("skin_"+String(joint.name))]=joint
	z._bind_skin_drivers();return z
func run()->void:
	create_timer(60).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1400,900)
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();scene.add_child(env);env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.11,.15,.19)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.72,.80,.90);env.environment.ambient_light_energy=.5
	env.environment.ssao_enabled=true;env.environment.ssao_radius=.5
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-50,-25,0);sun.shadow_enabled=true
	var floor_mesh:=MeshInstance3D.new();scene.add_child(floor_mesh);floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(12,12)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.67,.75,.82);mat.roughness=.95;floor_mesh.material_override=mat
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=48;camera.position=Vector3(1.8,1.9,-2.8);camera.look_at(Vector3(0,.30,-.8))
	var out:="res://shots/encounter-polish/collapse";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var z:=actor(scene,78)
	z.state=Zombie.State.CHASE;z.speed_now=1.4;z._attack_windup=.1;z._animate(.1)
	var initial:Array[Vector3]=[]
	for joint:Node3D in z._arms+z._legs+z._knees+z._elbows:initial.append(joint.rotation)
	# Reconstruct the previous rigid tip-over from the identical attack pose.
	z._model.rotation.x=-PI/2;z._model.position.y=.12
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/rigid-before.png")
	z._model.rotation=Vector3.ZERO;z._model.position=Vector3.ZERO;z._die()
	for row:Array in [["buckle",.32],["settling",.70],["settled",1.0]]:
		z._death_pose(row[1])
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+row[0]+".png")
	z.activate(Vector3.ZERO,79);z.set_process(false);z._die();z._death_pose(1)
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/opposite-settled.png")
	print("COLLAPSE_CAPTURE_COMPLETE");quit()
