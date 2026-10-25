extends SceneTree
## Actual imported meshes and live forest shader, with no player save or world mutation.
const NAMES := ["snow_pine_open", "snow_fir_full", "snow_spruce_wind", "snow_snag", "winter_birch"]
var scene: Node3D
var camera: Camera3D
var trees: Array[MeshInstance3D] = []
var outputs: Array[Dictionary] = []
var destination := "res://shots/tree_diversity/gallery"

func _initialize() -> void: call_deferred("run")

func mesh_at(path: String) -> Mesh:
	var imported := (load(path) as PackedScene).instantiate()
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 1)
	var result: Mesh = (meshes[0] as MeshInstance3D).mesh
	assert((meshes[0] as Node3D).transform.is_equal_approx(Transform3D.IDENTITY))
	imported.free()
	return result

func shot(id: String) -> void:
	for frame in 16: await process_frame
	await RenderingServer.frame_post_draw
	var path := destination.path_join(id + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	outputs.append({"id": id, "file": path, "sha256": FileAccess.get_sha256(path)})
	print("TREE_REVIEW_CAPTURE ", id)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("capture_out="): destination = arg.trim_prefix("capture_out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	root.msaa_3d = Viewport.MSAA_4X
	scene = Node3D.new(); root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(.055, .070, .083)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.68, .78, .90); env.ambient_light_energy = .55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	environment.environment = env; scene.add_child(environment)
	var sun := DirectionalLight3D.new(); scene.add_child(sun)
	sun.rotation_degrees = Vector3(-42, -30, 0); sun.light_color = Color(1, .97, .9)
	sun.light_energy = 1.45; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	var ground := MeshInstance3D.new(); scene.add_child(ground)
	var plane := PlaneMesh.new(); plane.size = Vector2(110, 90); ground.mesh = plane
	ground.position.x = 18; ground.position.y = -.01
	var snow := StandardMaterial3D.new(); snow.albedo_color = Color(.64, .72, .80); snow.roughness = .95
	ground.material_override = snow
	var mat := ShaderMaterial.new(); mat.shader = load("res://world/shaders/boreal_detail.gdshader")
	mat.set_shader_parameter("bough_albedo", load("res://assets/environment_detail/textures/bough_albedo.png"))
	mat.set_shader_parameter("diversity_albedo", load("res://assets/environment_detail/tree_diversity/winter_twigs.png"))
	mat.set_shader_parameter("diversity_far_albedo", load("res://assets/environment_detail/tree_diversity/winter_boughs_far.png"))
	mat.set_shader_parameter("diversity_bark", load("res://assets/environment_detail/tree_diversity/winter_bark.png"))
	mat.set_shader_parameter("diversity_bark_normal", load("res://assets/environment_detail/tree_diversity/winter_bark_normal.png"))
	mat.set_shader_parameter("wind_speed", 0.0)
	for i in NAMES.size():
		var tree := MeshInstance3D.new(); scene.add_child(tree)
		tree.mesh = mesh_at("res://assets/environment_detail/tree_diversity/%s.glb" % NAMES[i])
		tree.position.x = i * 9.0; tree.scale = Vector3.ONE * 18.0
		tree.material_override = mat; trees.append(tree)
		var label := Label3D.new(); scene.add_child(label)
		label.text = ["OPEN PINE", "FULL FIR", "WIND SPRUCE", "DEAD CONIFER", "WINTER BIRCH"][i]
		label.position = Vector3(i * 9, -.65, 0); label.font_size = 48
		label.pixel_size = .010; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true; label.modulate = Color(.90, .94, 1)
	camera = Camera3D.new(); scene.add_child(camera); camera.make_current()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 29
	camera.position = Vector3(18, 11, 60); camera.look_at(Vector3(18, 9, 0))
	await shot("family-near")
	for i in trees.size(): trees[i].mesh = mesh_at("res://assets/environment_detail/tree_diversity/%s_far.glb" % NAMES[i])
	await shot("family-far")
	for i in trees.size(): trees[i].mesh = mesh_at("res://assets/environment_detail/tree_diversity/%s.glb" % NAMES[i])
	camera.position = Vector3(18, 11, -60); camera.look_at(Vector3(18, 9, 0))
	await shot("family-back")
	for i in 3:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = 55
		camera.position = Vector3(i * 9 + 3, 10, 9); camera.look_at(Vector3(i * 9, 10, 0))
		await shot(NAMES[i] + "-bough")
	var report := {"schema": 1, "engine": Engine.get_version_info().string, "gpu": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_driver_name(), "resolution": [root.size.x, root.size.y], "live_shader": FileAccess.get_sha256("res://world/shaders/boreal_detail.gdshader"), "captures": outputs}
	var file := FileAccess.open(destination.path_join("engine_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	scene.free(); print("TREE_REVIEW_COMPLETE"); quit()
