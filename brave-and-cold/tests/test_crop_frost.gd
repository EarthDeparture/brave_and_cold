extends SceneTree
## Existing crop geometry/material, advanced through partial frost, recovery and death.
## Optional -- capture uses a controlled light and writes shots/atomic-crops/*.png.
var checks := 0
var failures := 0
var capture := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func leaf(g: Greenhouse, i := 0) -> MeshInstance3D:
	for n: Node in g._plants[i].get_children():
		if n is MeshInstance3D and not n.is_queued_for_deletion() and (n as MeshInstance3D).material_override is ShaderMaterial: return n
	return null
func frost(g: Greenhouse, i := 0) -> float:
	return float((leaf(g, i).material_override as ShaderMaterial).get_shader_parameter("frost"))
func photo(label: String) -> void:
	if not capture: return
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://shots/atomic-crops/" + label + ".png") == OK, "capture " + label)
func run() -> void:
	capture = "capture" in OS.get_cmdline_user_args()
	var g := Greenhouse.new(); root.add_child(g); g.light = 1.0
	for i in 2:
		var p := Farming.new_plot(); p.crop = "beet" if i == 0 else "kale"; p.growth = 0.65; p.water = 1.0; g.plots.append(p)
		var n := Node3D.new(); g.add_child(n); n.position.x = i * 0.6; g._plants.append(n)
	g.refresh_all(); await process_frame
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/atomic-crops"))
		root.size = Vector2i(900, 700)
		var we := WorldEnvironment.new(); we.environment = Environment.new()
		we.environment.background_mode = Environment.BG_COLOR; we.environment.background_color = Color(0.08, 0.10, 0.12)
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; we.environment.ambient_light_color = Color.WHITE; we.environment.ambient_light_energy = 0.45; root.add_child(we)
		var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, -30, 0); sun.light_energy = 1.2; root.add_child(sun)
		var cam := Camera3D.new(); root.add_child(cam); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 0.8
		cam.position = Vector3(0.0, 0.65, 0.9); cam.look_at(Vector3(0, 0.2, 0)); cam.make_current()
	var original := leaf(g)
	var original_id := original.get_instance_id()
	check(original != null and is_zero_approx(frost(g)), "healthy plant starts without frost")
	check(original.material_override != leaf(g, 1).material_override, "plants have private leaf materials")
	await photo("healthy")
	g.advance(1800, -5)
	check(is_equal_approx(frost(g), 0.25) and not bool(g.plots[0].dead), "30 minutes freezing: quarter frost while alive")
	g.advance(1800, -5)
	check(is_equal_approx(frost(g), 0.5) and leaf(g) == original and float(g.plots[0].growth) == 0.65, "one hour: half frost without growth or mesh replacement")
	await photo("half-frost")
	g.plots[1].frost_s = 0.0; g._update_plant_frost(1)
	check(is_zero_approx(frost(g, 1)) and is_equal_approx(frost(g), 0.5), "one plant's frost update does not alter its neighbour")
	g.advance(2880, -5)
	check(is_equal_approx(frost(g), 0.9) and leaf(g) == original and not bool(g.plots[0].dead), "90 percent frost is visible before the lethal threshold")
	await photo("heavy-frost")
	g.light = 0.0; g.advance(1, 20)
	check(is_zero_approx(frost(g)) and leaf(g) == original and float(g.plots[0].growth) == 0.65, "warming clears frost even in darkness without a visual rebuild")
	await photo("recovered")
	g.advance(7200, -5); await process_frame
	check(bool(g.plots[0].dead) and leaf(g).get_instance_id() != original_id, "the existing death threshold still selects the dead crop model")
	check(is_equal_approx(float((leaf(g).material_override as ShaderMaterial).get_shader_parameter("withered")), 1.0), "dead model keeps its withered material")
	await photo("dead")
	g.queue_free(); await process_frame
	print("CROP_FROST_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
