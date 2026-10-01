class_name ForestScatter
extends Node3D
## Scatters conifers from the real lidar canopy-height mask (canopy.png: 8-bit, metres/40).
## Chunked MultiMeshes (CHUNK m) with visibility ranges so distant chunks are culled.

const CHUNK := 128
const SPACING := 5.0
const MIN_CANOPY_M := 6.0
const VIS_END := 700.0
var near_end := 140.0
const VARIANTS := ["spruce_a", "spruce_b", "spruce_c"]
const TREE_UNIT_M := 1.0  # source models are 1.0 high; scale = real canopy height

var terrain: Terrain3D
var map_dir := "res://data/maps/valley_b"
var tree_count := 0
var excluded := 0
var exclude: Callable  # (x, z) -> bool: skip trees here (roads, buildings)
const TRUNK_CELL := 8.0
var _trunks: Dictionary = {}  # Vector2i cell -> Array of Vector3(x, z, radius)
var _mms: Dictionary = {}  # Vector3i(chunk x, chunk z, variant) -> [MultiMesh lod0, lod1]
var _meshes: Array[Mesh] = []
var _mat: StandardMaterial3D
var _half := 0
var felled: Dictionary = {}  # "ix,iz" -> true (trees cut down by the player)
var chop_hp: Dictionary = {}  # tree key -> remaining hits


static func tree_key(x: float, z: float) -> String:
	return "%d,%d" % [roundi(x * 2.0), roundi(z * 2.0)]


static func tree_height_from_r(r: float) -> float:
	return (r - 0.12) / 0.012


static func hits_total(h: float) -> float:
	return clampf(roundf(h * 1.2), 10.0, 32.0)


func tree_mesh(vi: int) -> Mesh:
	return _meshes[vi]


func tree_mat() -> StandardMaterial3D:
	return _mat


## Nearest standing tree trunk surface within reach (xz). With need_facing the tree must be in front of fwd.
func nearest_tree(pos: Vector3, fwd: Vector3, reach: float, need_facing: bool = true) -> Dictionary:
	var best := {}
	var bd := 1e9
	var f2 := Vector2(fwd.x, fwd.z)
	f2 = f2.normalized() if f2.length() > 0.001 else Vector2(0, -1)
	var cx := int(floor(pos.x / TRUNK_CELL))
	var cz := int(floor(pos.z / TRUNK_CELL))
	var rc := int(ceil((reach + 1.0) / TRUNK_CELL))
	for oz in range(-rc, rc + 1):
		for ox in range(-rc, rc + 1):
			var arr = _trunks.get(Vector2i(cx + ox, cz + oz))
			if arr == null:
				continue
			for tv: Vector3 in (arr as Array):
				var to := Vector2(tv.x - pos.x, tv.y - pos.z)
				var d := to.length() - tv.z
				if d > reach or d >= bd:
					continue
				if need_facing and to.length() > 0.001 and to.normalized().dot(f2) < 0.55:
					continue
				bd = d
				best = {"x": tv.x, "z": tv.y, "r": tv.z, "h": tree_height_from_r(tv.z), "d": d}
	return best


## Remove a tree (collision + all instances). Returns {x,z,r,h,vi,origin,basis} or {} if not found.
func fell(x: float, z: float) -> Dictionary:
	var ck := Vector2i(int(floor(x / TRUNK_CELL)), int(floor(z / TRUNK_CELL)))
	var arr = _trunks.get(ck)
	if arr == null:
		return {}
	var r := -1.0
	for i in range((arr as Array).size()):
		var tv: Vector3 = arr[i]
		if absf(tv.x - x) < 0.02 and absf(tv.y - z) < 0.02:
			r = tv.z
			(arr as Array).remove_at(i)
			break
	if r < 0.0:
		return {}
	var kx := int(floor((x + _half) / CHUNK))
	var kz := int(floor((z + _half) / CHUNK))
	for vi in range(VARIANTS.size()):
		var pair = _mms.get(Vector3i(kx, kz, vi))
		if pair == null:
			continue
		var mm0: MultiMesh = pair[0]
		for i in range(mm0.instance_count):
			var xf := mm0.get_instance_transform(i)
			if absf(xf.origin.x - x) < 0.05 and absf(xf.origin.z - z) < 0.05 and xf.basis.get_scale().y > 0.01:
				for mm: MultiMesh in pair:
					mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), xf.origin))
				felled[tree_key(x, z)] = true
				return {"x": x, "z": z, "r": r, "h": tree_height_from_r(r), "vi": vi, "origin": xf.origin, "basis": xf.basis}
	felled[tree_key(x, z)] = true
	return {"x": x, "z": z, "r": r, "h": tree_height_from_r(r), "vi": 0, "origin": Vector3(x, 0, z), "basis": Basis()}


## Re-apply saved felled trees. Returns the fell infos (for stumps).
func apply_felled(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var p := String(k).split(",")
		if p.size() != 2:
			continue
		var info := fell(float(p[0]) / 2.0, float(p[1]) / 2.0)
		if not info.is_empty():
			out.append(info)
	return out


## Push a circle (x,z,r) out of any trunk it overlaps. Returns corrected xz.
func resolve_trunks(x: float, z: float, r: float) -> Vector2:
	var px := x
	var pz := z
	var cx := int(floor(x / TRUNK_CELL))
	var cz := int(floor(z / TRUNK_CELL))
	var reach := r + 0.7                      # max trunk radius is ~0.6 m
	var lx := x - float(cx) * TRUNK_CELL
	var lz := z - float(cz) * TRUNK_CELL
	var ox0 := -1 if lx < reach else 0
	var ox1 := 1 if lx > TRUNK_CELL - reach else 0
	var oz0 := -1 if lz < reach else 0
	var oz1 := 1 if lz > TRUNK_CELL - reach else 0
	for oz in range(oz0, oz1 + 1):
		for ox in range(ox0, ox1 + 1):
			var arr = _trunks.get(Vector2i(cx + ox, cz + oz))
			if arr == null:
				continue
			for t: Vector3 in (arr as Array):
				var dx := px - t.x
				var dz := pz - t.y
				var minr: float = t.z + r
				var d2 := dx * dx + dz * dz
				if d2 < minr * minr:
					var l := sqrt(d2)
					if l > 0.0001:
						px = t.x + dx / l * minr
						pz = t.y + dz / l * minr
					else:
						px += minr
	return Vector2(px, pz)


func build(t: Terrain3D, seed_value: int = 1337) -> void:
	terrain = t
	var meta = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/meta.json"))
	var size_m: int = int(meta["size_m"])
	var half := size_m / 2
	var canopy := MapIO.load_png(map_dir + "/canopy.png")
	var slope := MapIO.load_png(map_dir + "/slope.png")
	canopy.convert(Image.FORMAT_L8)
	slope.convert(Image.FORMAT_L8)
	var water := MapIO.load_png(map_dir + "/water_mask.png")
	water.convert(Image.FORMAT_L8)

	var meshes: Array[Mesh] = []
	_half = half
	var far_meshes: Array[Mesh] = []
	for v in VARIANTS:
		meshes.append(_load_mesh("res://assets/models/trees/%s.glb" % v))
		far_meshes.append(_load_mesh("res://assets/models/trees/%s_far.glb" % v))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_mat = mat
	# chunk key -> per-variant transform arrays
	var buckets := {}
	var gx := int(size_m / SPACING)
	for iy in range(gx):
		for ix in range(gx):
			var px := int((ix + rng.randf()) * SPACING)
			var py := int((iy + rng.randf()) * SPACING)
			if px >= size_m or py >= size_m:
				continue
			var c_m: float = canopy.get_pixel(px, py).r * 255.0 / 255.0 * 40.0
			if c_m < MIN_CANOPY_M:
				continue
			if slope.get_pixel(px, py).r * 90.0 > 34.0:
				continue
			if _near_water(water, px, py):
				continue
			# density falls off in sparse canopy so edges break up naturally
			if rng.randf() > clampf((c_m - MIN_CANOPY_M) / 10.0 + 0.25, 0.0, 1.0):
				continue
			var wx := float(px - half) + 0.5
			var wz := float(py - half) + 0.5
			if exclude.is_valid() and exclude.call(wx, wz):
				excluded += 1
				continue
			var h: float = terrain.data.get_height(Vector3(wx, 0, wz))
			if is_nan(h):
				continue
			var height_m := clampf(c_m * rng.randf_range(0.9, 1.1), 5.0, 26.0)
			var girth := height_m * rng.randf_range(0.9, 1.3)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(girth, height_m, girth))
			var key := Vector2i(int(floor((wx + half) / CHUNK)), int(floor((wz + half) / CHUNK)))
			var vi := rng.randi() % VARIANTS.size()
			if not buckets.has(key):
				buckets[key] = [[], [], []]
			buckets[key][vi].append(Transform3D(b, Vector3(wx, h - 0.15, wz)))
			tree_count += 1
			var ck := Vector2i(int(floor(wx / TRUNK_CELL)), int(floor(wz / TRUNK_CELL)))
			if not _trunks.has(ck):
				_trunks[ck] = []
			(_trunks[ck] as Array).append(Vector3(wx, wz, 0.12 + 0.012 * height_m))

	_meshes = meshes
	for key in buckets:
		var per_variant: Array = buckets[key]
		for vi in range(VARIANTS.size()):
			var xf: Array = per_variant[vi]
			if xf.is_empty():
				continue
			var pair: Array = []
			for lod in range(2):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = meshes[vi] if lod == 0 else far_meshes[vi]
				mm.instance_count = xf.size()
				for i in range(xf.size()):
					mm.set_instance_transform(i, xf[i])
				var inst := MultiMeshInstance3D.new()
				inst.multimesh = mm
				inst.material_override = mat
				if lod == 0:
					inst.visibility_range_end = near_end
					inst.visibility_range_end_margin = 20.0
					inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				else:
					inst.visibility_range_begin = near_end - 10.0
					inst.visibility_range_end = VIS_END
				inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(inst)
				pair.append(mm)
			_mms[Vector3i(key.x, key.y, vi)] = pair
	print("FOREST_EXCL ", excluded)
	print("FOREST_TREES ", tree_count, " chunks ", buckets.size())


func _load_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	var n := scene.instantiate()
	var found: Mesh = null
	for c in n.find_children("*", "MeshInstance3D", true, false):
		found = (c as MeshInstance3D).mesh
		break
	n.queue_free()
	return found


func _near_water(w: Image, px: int, py: int) -> bool:
	for d in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		var x := clampi(px + d.x, 0, w.get_width() - 1)
		var y := clampi(py + d.y, 0, w.get_height() - 1)
		if w.get_pixel(x, y).r > 0.5:
			return true
	return false
