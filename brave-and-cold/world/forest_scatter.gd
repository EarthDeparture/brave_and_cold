class_name ForestScatter
extends Node3D
## Scatters conifers from the real lidar canopy-height mask (canopy.png: 8-bit, metres/40).
## Chunked MultiMeshes with visibility ranges so distant crowns are culled.

const CHUNK := 128
var _chunk_m := CHUNK
const SPACING := 5.0
const MIN_CANOPY_M := 6.0
const VIS_END := 700.0
var near_end := 140.0
const BASE_VARIANT_COUNT := 3
const VARIANTS := ["spruce_a", "spruce_b", "spruce_c", "snow_pine_open", "snow_fir_full", "snow_spruce_wind", "snow_snag", "winter_birch"]
const TREE_UNIT_M := 1.0  # source models are 1.0 high; scale = real canopy height

var detail_enabled := false
var diversity_enabled := true  # Presentation only; legacy profile retains its original three trees.
var crown_quality_enabled := true # Visual resources only; scatter/save identities are unchanged.
var weather: Weather
var terrain: Terrain3D
var map_dir := "res://data/maps/valley_b"
var tree_count := 0
var excluded := 0
var exclude: Callable  # (x, z) -> bool: skip trees here (roads, buildings)
const TRUNK_CELL := 8.0
var _trunks: Dictionary = {}  # Vector2i cell -> Array of Vector3(x, z, radius)
var _near_insts: Array[GeometryInstance3D] = []  # lod0 per chunk/variant
var _far_insts: Array[GeometryInstance3D] = []   # lod1 card crowns
var _shadow_proxies: Array[GeometryInstance3D] = []
var view_scale := 1.0
var _mms: Dictionary = {}  # Vector3i(chunk x, chunk z, variant) -> [MultiMesh lod0, lod1]
var _meshes: Array[Mesh] = []
var _mat: Material
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


func tree_mat() -> Material:
	return _mat


## Nearest standing tree trunk surface within reach (xz). With need_facing the tree must be in front of fwd.
## `accept` (optional) gets Vector3(x, z, r) of a candidate trunk and may veto it (the game uses it for "is the crosshair on it").
func nearest_tree(pos: Vector3, fwd: Vector3, reach: float, need_facing: bool = true, accept: Callable = Callable()) -> Dictionary:
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
				if accept.is_valid() and not accept.call(tv):
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
	var kx := int(floor((x + _half) / _chunk_m))
	var kz := int(floor((z + _half) / _chunk_m))
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


## How many trunks stand on the xz segment a->b (capped at 6). Used for sight occlusion (each trunk ~ -25 % range).
func trunks_on_segment(ax: float, az: float, bx: float, bz: float) -> int:
	var dx := bx - ax
	var dz := bz - az
	var len := sqrt(dx * dx + dz * dz)
	if len < 0.01:
		return 0
	var steps := int(ceil(len / 4.0))
	var seen: Array[Vector2i] = []
	var n := 0
	var l2 := len * len
	for i in range(steps + 1):
		var t := float(i) / float(maxi(steps, 1))
		var px := ax + dx * t
		var pz := az + dz * t
		var fx := px / TRUNK_CELL
		var fz := pz / TRUNK_CELL
		var cx := int(floor(fx))
		var cz := int(floor(fz))
		var cells: Array[Vector2i] = [Vector2i(cx, cz)]
		var ex := fx - float(cx)
		var ez := fz - float(cz)
		if ex < 0.15:
			cells.append(Vector2i(cx - 1, cz))
		elif ex > 0.85:
			cells.append(Vector2i(cx + 1, cz))
		if ez < 0.15:
			cells.append(Vector2i(cx, cz - 1))
		elif ez > 0.85:
			cells.append(Vector2i(cx, cz + 1))
		for c in cells:
			if seen.has(c):
				continue
			seen.append(c)
			var arr = _trunks.get(c)
			if arr == null:
				continue
			for tv: Vector3 in (arr as Array):
				var u := clampf(((tv.x - ax) * dx + (tv.y - az) * dz) / l2, 0.0, 1.0)
				var qx := ax + dx * u - tv.x
				var qz := az + dz * u - tv.y
				var rr: float = tv.z + 0.25
				if qx * qx + qz * qz < rr * rr:
					n += 1
					if n >= 6:
						return 6
	return n


## Push a circle (x,z,r) out of any trunk it overlaps. Returns corrected xz.
func resolve_trunks(x: float, z: float, r: float) -> Vector2:
	var p := Vector2(x, z)
	var cx := int(floor(x / TRUNK_CELL))
	var cz := int(floor(z / TRUNK_CELL))
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var arr = _trunks.get(Vector2i(cx + ox, cz + oz))
			if arr == null:
				continue
			for t: Vector3 in (arr as Array):
				var d := p - Vector2(t.x, t.y)
				var minr: float = t.z + r
				var l := d.length()
				if l < minr:
					p = Vector2(t.x, t.y) + (d / maxf(l, 0.0001)) * minr if l > 0.0001 else p + Vector2(minr, 0)
	return p


func build(t: Terrain3D, seed_value: int = 1337) -> void:
	terrain = t
	Settings.load_all()
	# Smaller visual groups keep the denser near crowns local to the camera.
	# Roots and species use the same RNG; trunk collision has its own grid.
	_chunk_m = 64 if detail_enabled and crown_quality_enabled else CHUNK
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
	var variant_count := VARIANTS.size() if detail_enabled and diversity_enabled else BASE_VARIANT_COUNT
	for vi in range(variant_count):
		var v: String = VARIANTS[vi]
		var bank := "res://assets/environment_detail/tree_diversity" if vi >= BASE_VARIANT_COUNT else ("res://assets/environment_detail/trees" if detail_enabled else "res://assets/models/trees")
		if detail_enabled and crown_quality_enabled and vi < 6:
			bank = "res://assets/environment_detail/forest_quality"
		meshes.append(_load_mesh(bank + "/%s.glb" % v))
		far_meshes.append(_load_mesh(bank + "/%s_far.glb" % v))
	var mat: Material
	if detail_enabled:
		# The denser authored crowns are needed at walking distance. Use their
		# matching, snow-loaded far silhouettes sooner than the legacy bank.
		near_end = 100.0 if crown_quality_enabled else 140.0
		var surface := ShaderMaterial.new()
		surface.shader = preload("res://world/shaders/boreal_detail.gdshader")
		surface.set_shader_parameter("bough_albedo", preload("res://assets/environment_detail/textures/bough_albedo.png"))
		surface.set_shader_parameter("crown_spray_atlas",crown_quality_enabled)
		if crown_quality_enabled:
			surface.set_shader_parameter("bough_albedo", preload("res://assets/environment_detail/forest_quality/crown_sprays.png"))
		surface.set_shader_parameter("diversity_albedo", preload("res://assets/environment_detail/tree_diversity/winter_twigs.png"))
		surface.set_shader_parameter("diversity_far_albedo", preload("res://assets/environment_detail/tree_diversity/winter_boughs_far.png"))
		surface.set_shader_parameter("diversity_bark", preload("res://assets/environment_detail/tree_diversity/winter_bark.png"))
		surface.set_shader_parameter("diversity_bark_normal", preload("res://assets/environment_detail/tree_diversity/winter_bark_normal.png"))
		if crown_quality_enabled:
			surface.set_shader_parameter("diversity_bark", preload("res://assets/environment_detail/forest_quality/winter_bark.png"))
			surface.set_shader_parameter("diversity_bark_normal", preload("res://assets/environment_detail/forest_quality/winter_bark_normal.png"))
		mat = surface
	else:
		var surface := StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		surface.roughness = 1.0
		surface.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat = surface

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var habitat := FastNoiseLite.new()
	habitat.seed = seed_value + 701
	habitat.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	habitat.frequency = 0.0035
	habitat.fractal_octaves = 2
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
			var key := Vector2i(int(floor((wx + half) / _chunk_m)), int(floor((wz + half) / _chunk_m)))
			# Consume precisely the old random roll. Adding a new RNG call here
			# shifts every later root and breaks saved felled-tree coordinates.
			var roll := rng.randi()
			var vi := roll % BASE_VARIANT_COUNT
			if variant_count > BASE_VARIANT_COUNT:
				vi = _winter_variant(roll, habitat.get_noise_2d(wx, wz), h, slope.get_pixel(px, py).r * 90.0, height_m)
			if not buckets.has(key):
				var arrays: Array = []
				for unused in range(variant_count): arrays.append([])
				buckets[key] = arrays
			buckets[key][vi].append(Transform3D(b, Vector3(wx, h - 0.15, wz)))
			tree_count += 1
			var ck := Vector2i(int(floor(wx / TRUNK_CELL)), int(floor(wz / TRUNK_CELL)))
			if not _trunks.has(ck):
				_trunks[ck] = []
			(_trunks[ck] as Array).append(Vector3(wx, wz, 0.12 + 0.012 * height_m))

	_meshes = meshes
	_near_insts.clear(); _far_insts.clear(); _shadow_proxies.clear()
	for key in buckets:
		var per_variant: Array = buckets[key]
		for vi in range(variant_count):
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
					_near_insts.append(inst)
					inst.visibility_range_end = near_end
					inst.visibility_range_end_margin = 20.0
					inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				else:
					_far_insts.append(inst)
					inst.visibility_range_begin = near_end - 10.0
					inst.visibility_range_end = VIS_END
				inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(inst)
				pair.append(mm)
			if Settings.forest_shadow_proxies():
				# Performance preset: near crowns stop casting; the few-card far crown casts in their place.
				(get_child(get_child_count() - 2) as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var proxy := MultiMeshInstance3D.new()
				proxy.multimesh = pair[1]
				proxy.material_override = mat
				proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				proxy.visibility_range_end = near_end + 20.0
				_shadow_proxies.append(proxy)
				add_child(proxy)
			_mms[Vector3i(key.x, key.y, vi)] = pair
	print("FOREST_EXCL ", excluded)
	print("FOREST_TREES ", tree_count, " chunks ", buckets.size())
	if variant_count > BASE_VARIANT_COUNT:
		var counts := {}
		for key: Vector3i in _mms: counts[VARIANTS[key.z]] = int(counts.get(VARIANTS[key.z], 0)) + (_mms[key][0] as MultiMesh).instance_count
		print("FOREST_DIVERSITY ", counts)


func _winter_variant(roll: int, habitat: float, elevation: float, slope: float, height: float) -> int:
	var choice := float((roll >> 8) & 65535) / 65535.0
	if choice < 0.032 and absf(habitat) > 0.18: return 6  # Deadwood pockets; avoid a rare species draw in every chunk.
	if elevation < 115.0 and slope < 16.0 and height < 23.0 and habitat < -0.32:
		if choice < 0.32: return 7  # Sheltered leafless birch pockets.
		if choice < 0.65: return 4
	elif elevation > 175.0 and habitat < 0.15:
		if choice < 0.48: return 5  # Exposed upper-slope weathered crowns.
	elif habitat > 0.18:
		if choice < 0.65: return 3  # Open-crowned pine stands.
	elif habitat < -0.18:
		if choice < 0.62: return 4
	# Closely related legacy spruces form local cohorts instead of paying for all
	# three nearly identical meshes in every chunk of every new species stand.
	# This affects presentation only; the disabled profile keeps the original roll.
	return 0 if habitat < -0.10 else (2 if habitat > 0.10 else 1)


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

func update_detail_appearance() -> void:
	if detail_enabled and _mat is ShaderMaterial and weather != null:
		var surface := _mat as ShaderMaterial
		surface.set_shader_parameter("wind_direction",weather.wind_dir)
		surface.set_shader_parameter("wind_speed",weather.wind)
		surface.set_shader_parameter("wind_phase",weather._t)

func _process(_delta: float) -> void:
	update_detail_appearance()

## Scope LOD: visibility ranges are camera distance, blind to FOV. Through glass the
## far card crowns are magnified to near-view size, so push the full-crown tier out
## by s (1 = normal view). Only the narrow scope frustum renders the extra crowns.
func set_view_scale(s: float) -> void:
	if absf(s - view_scale) < 0.01: return
	view_scale = s
	for inst in _near_insts: inst.visibility_range_end = near_end * s
	for inst in _far_insts: inst.visibility_range_begin = near_end * s - 10.0
	for inst in _shadow_proxies: inst.visibility_range_end = near_end * s + 20.0
