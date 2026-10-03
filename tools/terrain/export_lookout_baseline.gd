extends SceneTree
## Read-only map survey for plan_lookout_site.py. Run with the game project as
## --path and this file as --script. Use -- lookout=0 for the baseline;
## -- report=after includes the new lookout in map_after.json.

func _init() -> void:
	call_deferred("_export")


func _export() -> void:
	var scene := load("res://world/game_world.tscn") as PackedScene
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	for frame in range(120):
		await process_frame
		if world.get("hud") != null:
			break
	if world.get("hud") == null:
		push_error("Lookout survey: world did not finish loading")
		quit(1)
		return
	var report := {"road": [], "trunks": [], "trails": [], "buildings": []}
	for point: Vector2 in world.get("road").points:
		report.road.append([point.x, point.y])
	var forest := world.get("forest") as ForestScatter
	if forest != null:
		for cell: Array in forest._trunks.values():
			for trunk: Vector3 in cell:
				report.trunks.append([trunk.x, trunk.y, trunk.z])
	for trail: Array in world.get("trailnet").trails:
		var points: Array = []
		for point: Vector2 in trail:
			points.append([point.x, point.y])
		report.trails.append(points)
	for building: Node3D in world.call("_building_list"):
		report.buildings.append({"type": building.get_script().resource_path, "pos": [building.global_position.x, building.global_position.y, building.global_position.z], "yaw": building.rotation_degrees.y})
	var report_name := "map_after" if "report=after" in OS.get_cmdline_user_args() else "map_baseline"
	DirAccess.make_dir_recursive_absolute("res://shots/lookout")
	var file := FileAccess.open("res://shots/lookout/" + report_name + ".json", FileAccess.WRITE)
	if file == null:
		push_error("Lookout survey: could not write report")
		quit(1)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	print("LOOKOUT_BASELINE road=", report.road.size(), " trunks=", report.trunks.size(), " trails=", report.trails.size(), " buildings=", report.buildings.size())
	quit()
