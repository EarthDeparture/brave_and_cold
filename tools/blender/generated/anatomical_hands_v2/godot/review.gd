extends SceneTree
var world: Node3D
var cam: Camera3D
var player: AnimationPlayer
var model: Node3D
var results: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func pose(clip: String, time: float = 0.0) -> void:
	player.play(clip)
	player.seek(time, true)
	player.advance(0)
	player.pause()
func capture(id: String) -> void:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../previews/" + id + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
func camera_view(palm: bool = false) -> void:
	var center := Vector3(0,0,-.045)
	cam.position = center + Vector3(.08,-.60 if palm else .60,.07)
	cam.look_at(center, Vector3.FORWARD)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1000,1000)
	world = Node3D.new(); root.add_child(world)
	var env := WorldEnvironment.new(); world.add_child(env); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.055,.065,.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.90,.93,1)
	env.environment.ambient_light_energy = .35
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var key := DirectionalLight3D.new(); world.add_child(key); key.rotation_degrees = Vector3(-72,-25,0); key.light_energy = .9
	var fill := DirectionalLight3D.new(); world.add_child(fill); fill.rotation_degrees = Vector3(52,145,0); fill.light_energy = .35
	cam = Camera3D.new(); world.add_child(cam); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = .32; cam.current = true
	model = load("res://anatomical_hands.glb").instantiate(); world.add_child(model)
	player = model.find_child("AnimationPlayer",true,false)
	assert(player != null)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../manifest.json"))
	var rest: Dictionary = {}
	for name: String in ["HandRig","LeftHandRig"]:
		var rig: Node3D = model.find_child(name,true,false)
		var skeleton: Skeleton3D = rig.find_child("Skeleton3D",true,false)
		assert(skeleton != null and skeleton.get_bone_count() == 17)
		for bone: String in metadata.bones: assert(skeleton.find_bone(bone) >= 0)
		for skin_name: String in ["BareHand","BareHandLeft","NailsRight","NailsLeft"]:
			var skin: MeshInstance3D = rig.find_child(skin_name,true,false)
			if skin == null: continue
			assert(skin.skin.get_bind_count() == 17)
			assert(skin.get_node(skin.skeleton) == skeleton)
			assert(skin.mesh.get_blend_shape_count() == (8 if skin_name.begins_with("BareHand") else 0))
	pose("Open")
	for node in model.find_children("*","Skeleton3D",true,false):
		var skeleton: Skeleton3D = node
		rest[skeleton] = []
		for i in 17: rest[skeleton].append(skeleton.get_bone_pose_rotation(i))
	for clip: String in metadata.clips:
		assert(player.has_animation(clip), "Missing clip: " + clip)
		var animation := player.get_animation(clip)
		assert(absf(animation.length - (2.6 if clip == "FlexCycle" else 1.0)) < .001)
		pose(clip, 1.4 if clip == "FlexCycle" else .5)
		var changed := 0
		for skeleton: Skeleton3D in rest:
			for i in 17:
				if skeleton.get_bone_pose_rotation(i).angle_to(rest[skeleton][i]) > .001: changed += 1
		assert(changed > 0 or clip == "Open", "No bone deformation: " + clip)
		var shapes: Dictionary = {}
		for skin_name: String in ["BareHand","BareHandLeft"]:
			var skin: MeshInstance3D = model.find_child(skin_name,true,false)
			var maximum := 0.0
			for i in 8: maximum = maxf(maximum, skin.get_blend_shape_value(i))
			assert(maximum > .99 or clip == "Open", "Corrective not playing: " + clip)
			shapes[skin_name] = maximum
		results[clip] = {"duration_s":animation.length,"tracks":animation.get_track_count(),"changed_bones":changed,"corrective_max":shapes}
	var right: Node3D = model.find_child("HandRig",true,false)
	var left: Node3D = model.find_child("LeftHandRig",true,false)
	left.visible = false; camera_view()
	for clip: String in metadata.poses:
		pose(clip,.5); await capture("godot_" + clip)
	pose("Open"); camera_view(true); await capture("godot_palm")
	camera_view(); right.visible = false; left.visible = true; await capture("godot_left")
	left.visible = false; right.visible = true
	var flex_times := [0.0, .6, 1.6, 2.1, 2.6]
	for index in 5:
		pose("FlexCycle", flex_times[index])
		for skin_name: String in ["BareHand","BareHandLeft"]:
			var skin: MeshInstance3D = model.find_child(skin_name,true,false)
			var maximum := 0.0
			for i in 8: maximum = maxf(maximum, skin.get_blend_shape_value(i))
			if index in [0,4]: assert(maximum < .0001, "Flex endpoint morph not released")
			if index == 2: assert(maximum > .999, "Flex hold morph not applied")
		await capture("godot_flex_" + str(index))
	var file := FileAccess.open("res://engine_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"clips":results,"skeletons":2,"bones_per_skeleton":17,"scope":"Isolated GPU import, bone and corrective playback; no live gameplay integration."},"  ")+"\n")
	file.close(); print("ANATOMICAL_GODOT_PASS clips=",results.size()); quit()
