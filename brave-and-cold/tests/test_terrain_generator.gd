extends SceneTree

const TerrainGenerator = preload("res://scripts/terrain_generator.gd")

var failures := 0


func _init() -> void:
	var generator = TerrainGenerator.new(16, 100.0, 40.0, 7)
	var heights: PackedFloat32Array = generator.generate_heightmap()
	_check(heights.size() == 16 * 16, "heightmap has resolution^2 samples")

	var min_height := heights[0]
	var max_height := heights[0]
	for h in heights:
		min_height = min(min_height, h)
		max_height = max(max_height, h)
	_check(max_height > min_height, "heightmap has elevation variation")
	_check(min_height > -generator.height_scale - 1.0 and max_height < generator.height_scale + 1.0, "heights stay within scale bounds")

	var mesh: ArrayMesh = generator.generate_mesh(heights)
	_check(mesh.get_surface_count() == 1, "mesh has one surface")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(vertices.size() == 16 * 16, "mesh vertex count matches heightmap")
	_check(normals.size() == vertices.size(), "mesh has a normal per vertex")
	_check(indices.size() == 15 * 15 * 6, "mesh has expected triangle count")

	var all_normalized := true
	for n in normals:
		if not is_equal_approx(n.length(), 1.0):
			all_normalized = false
			break
	_check(all_normalized, "all normals are unit length")

	var repeat = TerrainGenerator.new(16, 100.0, 40.0, 7)
	var repeat_heights: PackedFloat32Array = repeat.generate_heightmap()
	_check(repeat_heights == heights, "same seed produces deterministic heightmap")

	print("Terrain generator tests: %d failures." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
