extends SceneTree
## Raven mesh / shader turntable: glide, flap up, flap down, folded, folded+peck. -> res://shots/ambient/bird_*.png
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	root.size = Vector2i(1600, 900)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.85, 0.88, 0.92); e.ambient_light_color = Color(0.6, 0.65, 0.75); e.ambient_light_energy = 0.6
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); root.add_child(sun)
	var al := AmbientLife.new(); root.add_child(al); al.world = null
	al._mesh = AmbientLife.bird_mesh(); al._mat = ShaderMaterial.new(); var sh := Shader.new(); sh.code = AmbientLife.BIRD_SHADER; al._mat.shader = sh
	var mi := al._make_mm(5)
	var mm := mi.multimesh
	var cus := [Color(0, 0, 0, 0), Color(1.57, 1, 0, 0), Color(-1.57, 1, 0, 0), Color(0, 0, 1, 0), Color(0, 0, 1, 1)]
	for i in 5:
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, 0.42 if i >= 3 else 0.0), Vector3((i - 2) * 1.6, 0, 0)))
		mm.set_instance_custom_data(i, cus[i])
	var c := Camera3D.new(); c.fov = 40; root.add_child(c); c.make_current()
	c.global_position = Vector3(0, 2.2, 5.0); c.look_at(Vector3(0, 0, 0), Vector3.UP)
	await frames(10)
	print("custom0 ", mm.get_instance_custom_data(3), " uses ", mm.use_custom_data)
	root.get_texture().get_image().save_png("res://shots/ambient/bird_poses.png")
	c.global_position = Vector3(1.6, 0.25, 1.1); c.look_at(Vector3(1.6, 0, 0), Vector3.UP)
	await frames(5)
	root.get_texture().get_image().save_png("res://shots/ambient/bird_poses_side.png")
	quit(0)
