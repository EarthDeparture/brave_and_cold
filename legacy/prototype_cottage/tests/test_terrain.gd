extends SceneTree
## godot --headless --path brave-and-cold --script res://tests/test_terrain.gd

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain_scene := load("res://scripts/terrain.gd")
	var terrain := StaticBody3D.new()
	terrain.set_script(terrain_scene)
	terrain.resolution = 8
	terrain.terrain_size = Vector2(40.0, 20.0)
	terrain.height_scale = 3.0
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	terrain.add_child(mesh_instance)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	terrain.add_child(collision_shape)
	root.add_child(terrain)
	await process_frame

	_check(terrain._mesh_instance.mesh != null, "terrain generates a mesh")
	_check(terrain._collision_shape.shape is HeightMapShape3D, "terrain builds a HeightMapShape3D")

	var shape: HeightMapShape3D = terrain._collision_shape.shape
	_check(shape.map_width == terrain.resolution and shape.map_depth == terrain.resolution,
		"collision heightmap dimensions match resolution")
	_check(shape.map_data.size() == terrain.resolution * terrain.resolution,
		"collision heightmap data matches resolution^2")
	_check(shape.map_data == terrain.heights, "collision data matches the mesh heightmap")

	var expected_scale := Vector3(
		terrain.terrain_size.x / float(terrain.resolution - 1), 1.0,
		terrain.terrain_size.y / float(terrain.resolution - 1))
	_check(terrain._collision_shape.scale.is_equal_approx(expected_scale),
		"collision shape is scaled to match mesh world size")

	var aabb: AABB = terrain._mesh_instance.mesh.get_aabb()
	_check(is_equal_approx(aabb.size.x, terrain.terrain_size.x) and
		is_equal_approx(aabb.size.z, terrain.terrain_size.y),
		"generated mesh spans the exported terrain size")

	terrain.free()
	print("Terrain tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
