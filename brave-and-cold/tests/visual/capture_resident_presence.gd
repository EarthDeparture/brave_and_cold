extends SceneTree
var stage:Node3D
var model:Node3D
var camera:Camera3D
var head:MeshInstance3D
var eye:StandardMaterial3D
func _initialize()->void:call_deferred("run")
func shot(id:String)->void:
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/resident-presence/"+id+".png");print("PRESENCE_CAPTURE ",id)
func run()->void:
	create_timer(90).timeout.connect(func()->void:quit(2))
	root.content_scale_size=Vector2i(720,720);DisplayServer.window_set_size(Vector2i(720,720));root.size=Vector2i(720,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/resident-presence"))
	stage=Node3D.new();root.add_child(stage);var env:=WorldEnvironment.new();stage.add_child(env);env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.035,.05,.06)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.75,.78,.82);env.environment.ambient_light_energy=.45
	var key:=OmniLight3D.new();stage.add_child(key);key.position=Vector3(-.9,2.1,-1.3);key.light_energy=1.2;key.omni_range=5
	model=(load("res://assets/resident_presence/rowan.glb") as PackedScene).instantiate();stage.add_child(model)
	for m:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if m.find_blend_shape_by_name("Blink")>=0:head=m
		for surface in m.mesh.get_surface_count():
			var mat:=m.mesh.surface_get_material(surface) as StandardMaterial3D
			if mat!=null and mat.resource_name=="HumanEye":eye=mat.duplicate() as StandardMaterial3D;m.set_surface_override_material(surface,eye)
	assert(head!=null and eye!=null)
	camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.28;camera.near=.02
	camera.position=Vector3(0,1.694,-.7);camera.look_at(Vector3(0,1.694,0))
	head.set_blend_shape_value(head.find_blend_shape_by_name("Blink"),0);await shot("open")
	head.set_blend_shape_value(head.find_blend_shape_by_name("Blink"),.5);await shot("half")
	head.set_blend_shape_value(head.find_blend_shape_by_name("Blink"),1);await shot("closed")
	head.set_blend_shape_value(head.find_blend_shape_by_name("Blink"),0);eye.uv1_offset=Vector3(-.075,0,0);await shot("gaze-right")
	eye.uv1_offset=Vector3(.075,0,0);await shot("gaze-left")
	eye.uv1_offset=Vector3(0,.035,0);await shot("gaze-up")
	eye.uv1_offset=Vector3.ZERO;eye.roughness=.60;eye.metallic_specular=.25;await shot("eye-material-candidate")
	eye.uv1_offset=Vector3.ZERO;camera.position=Vector3(.65,1.694,-.08);camera.look_at(Vector3(0,1.694,0));await shot("profile-open")
	head.set_blend_shape_value(head.find_blend_shape_by_name("Blink"),1);await shot("profile-closed")
	stage.queue_free();await process_frame;print("RESIDENT_PRESENCE_CAPTURE_COMPLETE");quit()
