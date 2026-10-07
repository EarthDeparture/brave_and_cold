extends "res://tests/visual/capture_worker_detail.gd"
func run()->void:
	create_timer(60).timeout.connect(func()->void:quit(2));root.size=Vector2i(1200,900)
	var scene:=Node3D.new();root.add_child(scene)
	var env:=WorldEnvironment.new();scene.add_child(env);env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.13,.17,.22)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.75,.83,.94);env.environment.ambient_light_energy=.7
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-45,-25,0);sun.shadow_enabled=true
	var plane:=MeshInstance3D.new();scene.add_child(plane);plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(15,15)
	var shader:=Shader.new();shader.code="shader_type spatial; varying vec3 p; void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float line=max(step(.97,fract(p.x*2.0)),step(.97,fract(p.z*2.0))); ALBEDO=mix(vec3(.60,.70,.80),vec3(.25,.35,.45),line);ROUGHNESS=.95;}"
	var material:=ShaderMaterial.new();material.shader=shader;plane.material_override=material
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.position=Vector3(0,1.35,-4.1);camera.look_at(Vector3(0,.95,0));camera.fov=45
	var old:=actor(scene,"res://assets/infected/skin/winter_worker_skin.glb");var current:=actor(scene,Zombie.MODEL)
	old.position=Vector3(-.65,0,.8);current.position=Vector3(.65,0,.8)
	for pair:Array in [[old,"Before"],[current,"Current"]]:
		var label:=Label3D.new();scene.add_child(label);label.text=pair[1];label.font_size=44;label.pixel_size=.003;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3(pair[0].position.x,2.05,0)
	current._gait_speed=.8;current.speed_now=.8;current.state=Zombie.State.INVESTIGATE
	var out:="res://shots/worker-detail/motion";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for i in 8:await process_frame
	for frame in 48:
		old.position.z-=.8/24;current.position.z-=.8/24
		old._phase+=(1.0/24)*.8*TAU/1.05
		for i in 2:
			var wave:=sin(old._phase+i*PI);var amp:=.8/Zombie.CHASE_SPEED*.48
			old._legs[i].rotation.x=wave*amp;old._knees[i].rotation.x=-maxf(0,-wave)*amp*.9
			old._arms[i].rotation.x=.08-wave*amp*.3;old._elbows[i].rotation.x=.15+amp*.1
		old._model.rotation.z=sin(old._phase*.5)*.035;old._deform_skin()
		current._animate(1.0/24)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/%03d.png"%frame)
	print("WORKER_MOTION_CAPTURE_COMPLETE");quit()
