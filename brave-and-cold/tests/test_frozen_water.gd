extends SceneTree
## Validate the actual rendered mesh against authored water heights and orientation.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ice := IceField.new()
	ice.load_map("res://data/maps/valley_b")
	ice.activate_shoreline()
	var water := WaterSurfaces.new()
	root.add_child(water)
	water.build()
	var arrays := water.surface.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var finite := true
	var winding := true
	var levels := true
	var max_height_error := 0.0
	var top_faces := 0
	var bottom_faces := 0
	var area_xz := 0.0
	var tops: Dictionary[Vector3i, bool] = {}
	var bottoms: Dictionary[Vector3i, bool] = {}
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		var normal := normals[indices[i]]
		finite = finite and a.is_finite() and b.is_finite() and c.is_finite()
		winding = winding and (b-a).cross(c-a).dot(normal) < 0.0
		if absf(normal.y) > 0.9:
			var middle := (a+b+c)/3.0
			var x := floorf((middle.x+1024.0)/2.0)*2.0-1023.0
			var z := floorf((middle.z+1024.0)/2.0)*2.0-1023.0
			# Shore cells can overlap the mask. Read their authored level directly.
			var px := int(x) + ice.half
			var pz := int(z) + ice.half
			var expected := ice.surface_height(middle.x, middle.z)
			if normal.y < 0.0:
				expected -= WaterSurfaces.THICKNESS
				bottom_faces += 1
			else:
				top_faces += 1
				area_xz += absf((b-a).cross(c-a).y) * 0.5
			for v in [a, b, c]:
				var point: Vector3 = v + (Vector3.UP * WaterSurfaces.THICKNESS if normal.y < 0.0 else Vector3.ZERO)
				var key := Vector3i(roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0))
				if normal.y > 0.0: tops[key] = true
				else: bottoms[key] = true
			max_height_error = maxf(max_height_error, absf(middle.y - expected))
			levels = levels and absf(middle.y - expected) < 0.0001
	var thickness_ok := tops.size() == bottoms.size()
	for key in tops: thickness_ok = thickness_ok and bottoms.has(key)
	var footprint_ok := is_equal_approx(area_xz, water.quad_count * WaterSurfaces.STRIDE * WaterSurfaces.STRIDE)
	var passed := finite and winding and levels and thickness_ok and footprint_ok and top_faces == bottom_faces and top_faces > 0 and water.edge_count > 0
	print("ICE_MESH_TEST finite=", finite, " clockwise=", winding, " authored_heights=", levels,
		" max_height_error=", max_height_error, " thickness=", thickness_ok, " footprint=", footprint_ok,
		" top_faces=", top_faces, " bottom_faces=", bottom_faces, " edge_quads=", water.edge_count)
	water.queue_free()
	await process_frame
	quit(0 if passed else 1)
