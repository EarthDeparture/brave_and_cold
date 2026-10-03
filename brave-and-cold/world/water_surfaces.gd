class_name WaterSurfaces
extends Node3D
## Frozen river/lake surfaces from the repaired IceField (repair_ice_surface.py).
## Opaque ice with a continuous top, underside and closed shore edges.
## Repaired basin coverage extends under the bank. Rendering and walking read
## one IceField and use identical triangle interpolation.

const ICE_SHADER := preload("res://world/shaders/frozen_water.gdshader")
const STRIDE := 2
const THICKNESS := 0.32
var surface: MeshInstance3D
var quad_count := 0
var edge_count := 0
var patch_count := 0


func build(map_dir: String = "res://data/maps/valley_b", field: IceField = null) -> void:
	if field == null:
		field = IceField.new()
		field.load_map(map_dir)
		field.activate_shoreline()
	var n := field.n
	var half := field.half
	var mask := field.render_mask

	var levels: Dictionary[Vector2i, float] = {}
	for y in range(0, n - 1, STRIDE):
		for x in range(0, n - 1, STRIDE):
			var nx := mini(x + STRIDE, n - 1)
			var ny := mini(y + STRIDE, n - 1)
			if mask.get_pixel(x, y).r < 0.5 and mask.get_pixel(nx, ny).r < 0.5 \
					and mask.get_pixel(nx, y).r < 0.5 and mask.get_pixel(x, ny).r < 0.5:
				continue
			levels[Vector2i(x, y)] = field.surface_height(x + 1 - half, y + 1 - half)
	var steps := [Vector2i(0, -STRIDE), Vector2i(STRIDE, 0), Vector2i(0, STRIDE), Vector2i(-STRIDE, 0)]
	var regions: Dictionary[Vector2i, int] = {}
	for cell: Vector2i in levels:
		regions[cell] = 0
	var corners: Dictionary[Vector3i, float] = {}
	var flat: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in levels:
		var coplanar := true
		for offset in [Vector2i.ZERO, Vector2i(STRIDE, 0), Vector2i(STRIDE, STRIDE), Vector2i(0, STRIDE)]:
			var point: Vector2i = cell + offset
			var corner := Vector3i(point.x, point.y, regions[cell])
			if not corners.has(corner):
				corners[corner] = field.level_at_pixel(point.x, point.y)
			coplanar = coplanar and absf(corners[corner] - levels[cell]) < 0.000001
		if coplanar:
			flat[cell] = levels[cell]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals := [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	quad_count = levels.size()
	edge_count = 0
	patch_count = 0
	var covered: Dictionary[Vector2i, bool] = {}
	# Merge flat neighbouring cells without changing their coverage or height.
	for cell: Vector2i in levels:
		if covered.has(cell):
			continue
		var yy: float = levels[cell]
		var width := 1
		while flat.has(cell) and _same_level(flat, covered, cell + Vector2i(width * STRIDE, 0), yy):
			width += 1
		var height := 1
		while true:
			if not flat.has(cell):
				break
			var extend := true
			for dx in width:
				if not _same_level(flat, covered, cell + Vector2i(dx * STRIDE, height * STRIDE), yy):
					extend = false
					break
			if not extend:
				break
			height += 1
		for dz in height:
			for dx in width:
				covered[cell + Vector2i(dx * STRIDE, dz * STRIDE)] = true
		var top := _top(cell, regions[cell], corners, half, width, height)
		var bottom := PackedVector3Array()
		for v in top:
			bottom.append(v - Vector3.UP * THICKNESS)
		_quad(st, top, Vector3.UP)
		_quad(st, bottom, Vector3.DOWN)
		patch_count += 1
	for cell: Vector2i in levels:
		var top := _top(cell, regions[cell], corners, half, 1, 1)
		var bottom := PackedVector3Array()
		for v in top:
			bottom.append(v - Vector3.UP * THICKNESS)
		for i in 4:
			var other: Vector2i = cell + steps[i]
			var j := (i + 1) % 4
			if not levels.has(other) or regions[other] != regions[cell]:
				_quad(st, PackedVector3Array([top[i], top[j], bottom[j], bottom[i]]), normals[i])
				edge_count += 1
	st.index()
	var mat := ShaderMaterial.new()
	mat.shader = ICE_SHADER
	if is_instance_valid(surface):
		surface.free()
	surface = MeshInstance3D.new()
	surface.name = "FrozenWater"
	surface.mesh = st.commit()
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	print("WATER_BUILT cells ", quad_count, " patches ", patch_count, " thickness ", THICKNESS, " edge quads ", edge_count)


func _same_level(levels: Dictionary[Vector2i, float], covered: Dictionary[Vector2i, bool], cell: Vector2i, height: float) -> bool:
	return levels.has(cell) and not covered.has(cell) and levels[cell] == height


func _top(cell: Vector2i, region_id: int, corners: Dictionary[Vector3i, float], half: int, width: int, height: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for offset in [Vector2i.ZERO, Vector2i(width * STRIDE, 0),
			Vector2i(width * STRIDE, height * STRIDE), Vector2i(0, height * STRIDE)]:
		var corner: Vector2i = cell + offset
		points.append(Vector3(float(corner.x - half), corners[Vector3i(corner.x, corner.y, region_id)], float(corner.y - half)))
	return points


func _quad(st: SurfaceTool, points: PackedVector3Array, normal: Vector3) -> void:
	# Godot's front faces are clockwise; normal attributes do not determine culling.
	var reverse := (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0
	var order := [0, 2, 1, 0, 3, 2] if reverse else [0, 1, 2, 0, 2, 3]
	st.set_normal(normal)
	for i in order:
		st.add_vertex(points[i])


func _lvl(buf: PackedByteArray, x: int, y: int, n: int, zmin: float, zmax: float) -> float:
	var raw := buf.decode_u16((y * n + x) * 2)
	return zmin + float(raw) / 65535.0 * (zmax - zmin)
