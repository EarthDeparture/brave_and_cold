extends SceneTree
## Debug render: right and left (mirrored) hand rigs side by side in one grip. -> res://shots/hands/grip_<name>.png
var grips := ["Open", "ForeGrip", "Support", "StockGrip"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("grips="): grips = Array(a.substr(6).split(","))
	root.size = Vector2i(1200, 600)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/hands"))
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(.3, .32, .35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(.6, .6, .6)
	root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-0.8, 0.6, 0); root.add_child(sun)
	var r := SurvivorHandRig.new(); root.add_child(r); r.position = Vector3(0.12, 0, 0)
	var l := SurvivorHandRig.new(); l.mirrored = true; root.add_child(l); l.position = Vector3(-0.12, 0, 0)
	var cam := Camera3D.new(); cam.fov = 40; root.add_child(cam)
	cam.position = Vector3(0, 0.30, 0.25); cam.look_at(Vector3(0, 0, -0.06), Vector3.UP)
	await process_frame; await process_frame
	for g in grips:
		r.pose(g); l.pose(g)
		for i in 6: await process_frame
		root.get_texture().get_image().save_png("res://shots/hands/grip_%s.png" % g); print("GRIP_CAPTURE ", g)
		cam.position = Vector3(0.45, -0.02, -0.06); cam.look_at(Vector3(0, -0.02, -0.06), Vector3.UP)
		for i in 4: await process_frame
		root.get_texture().get_image().save_png("res://shots/hands/grip_%s_side.png" % g)
		cam.position = Vector3(0, 0.30, 0.25); cam.look_at(Vector3(0, 0, -0.06), Vector3.UP)
	quit()
