class_name PlantField
extends Node3D
## Sparse harvestable plants from the lidar masks (dry grass, cattails, stick piles, lichen). Chunked MultiMeshes,
## deterministic placement; picked plants are zero-scaled and regrow after a game-time delay.

const CHUNK := 128
const VIS_END := 170.0
const CELL := 8.0
## step = sampling grid (m), prob = chance per sample, hold = hand time (s), regrow_h = game hours
const KINDS := {
	"grass": {"mesh": "grass_tuft", "label": "dry grass", "item": "thatch", "n": 2, "hold": 3.0, "regrow_h": 72.0, "step": 8, "prob": 0.22},
	"reed": {"mesh": "cattail", "label": "cattails", "item": "reed", "n": 2, "hold": 4.0, "knife_hold": 2.0, "regrow_h": 72.0, "step": 5, "prob": 0.55},
	"sticks": {"mesh": "stick_pile", "label": "stick pile", "item": "stick", "n": 4, "hold": 2.5, "regrow_h": 48.0, "step": 10, "prob": 0.07},
	"lichen": {"mesh": "lichen", "label": "lichen", "item": "tinder", "n": 1, "hold": 2.0, "regrow_h": 120.0, "step": 10, "prob": 0.05},
}

var terrain: Terrain3D
var picked: Dictionary = {}   # key -> game-seconds when it regrows
var counts: Dictionary = {}
var _plants: Dictionary = {}  # key -> {kind, x, z, mm, i, xf}
var _grid: Dictionary = {}    # Vector2i cell -> Array of keys
var _suppressed: Dictionary = {}
var _half := 0


static func _mesh(path: String) -> Mesh:
	var n := (load(path) as PackedScene).instantiate()
	var found: Mesh = null
	for c in n.find_children("*", "MeshInstance3D", true, false):
		found = (c as MeshInstance3D).mesh
		break
	n.queue_free()
	return found


static func _water(w: Image, px: int, py: int) -> bool:
	return w.get_pixel(clampi(px, 0, w.get_width() - 1), clampi(py, 0, w.get_height() - 1)).r > 0.5


static func _near_water(w: Image, px: int, py: int, d: int) -> bool:
	for o in [Vector2i(d, 0), Vector2i(-d, 0), Vector2i(0, d), Vector2i(0, -d), Vector2i(d, d), Vector2i(-d, -d), Vector2i(d, -d), Vector2i(-d, d)]:
		if _water(w, px + o.x, py + o.y):
			return true
	return false


func build(t: Terrain3D, exclude: Callable, map_dir := "res://data/maps/valley_b") -> void:
	terrain = t
	var meta = JSON.parse_string(FileAccess.get_file_as_string(map_dir + "/meta.json"))
	var size_m: int = int(meta["size_m"])
	_half = size_m / 2
	var canopy := MapIO.load_png(map_dir + "/canopy.png")
	var slope := MapIO.load_png(map_dir + "/slope.png")
	var water := MapIO.load_png(map_dir + "/water_mask.png")
	canopy.convert(Image.FORMAT_L8)
	slope.convert(Image.FORMAT_L8)
	water.convert(Image.FORMAT_L8)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	var buckets := {}
	var kinds: Array = KINDS.keys()
	for ki in range(kinds.size()):
		var kind: String = kinds[ki]
		var kd: Dictionary = KINDS[kind]
		rng.seed = 4242 + ki * 101
		counts[kind] = 0
		var step: int = int(kd["step"])
		for iy in range(0, size_m - step, step):
			for ix in range(0, size_m - step, step):
				var px := ix + rng.randi_range(0, step - 1)
				var py := iy + rng.randi_range(0, step - 1)
				var roll := rng.randf()
				var yaw := rng.randf() * TAU
				var sc := rng.randf_range(0.85, 1.3)
				if roll > float(kd["prob"]):
					continue
				var c_m: float = canopy.get_pixel(px, py).r * 40.0
				var sl: float = slope.get_pixel(px, py).r * 90.0
				var on_water := _water(water, px, py)
				var ok := false
				match kind:
					"grass":
						ok = c_m < 4.0 and sl < 14.0 and not on_water and not _near_water(water, px, py, 3)
					"reed":
						ok = not on_water and sl < 18.0 and _near_water(water, px, py, 3)
					"sticks":
						ok = c_m >= 8.0 and sl < 30.0 and not on_water
					"lichen":
						ok = c_m >= 5.0 and c_m <= 10.0 and sl < 30.0 and not on_water
				if not ok:
					continue
				var wx := float(px - _half) + 0.5
				var wz := float(py - _half) + 0.5
				if exclude.is_valid() and exclude.call(wx, wz):
					continue
				var h: float = terrain.data.get_height(Vector3(wx, 0, wz))
				if is_nan(h):
					continue
				var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, rng.randf_range(0.9, 1.2), sc)), Vector3(wx, h - 0.02, wz))
				var bk := Vector3i(int(floor((wx + _half) / CHUNK)), int(floor((wz + _half) / CHUNK)), ki)
				if not buckets.has(bk):
					buckets[bk] = []
				buckets[bk].append([wx, wz, xf])
				counts[kind] = int(counts[kind]) + 1
	var meshes: Array = []
	for k in kinds:
		meshes.append(_mesh("res://assets/models/props/%s.glb" % KINDS[k]["mesh"]))
	for bk in buckets:
		var arr: Array = buckets[bk]
		var kind: String = kinds[bk.z]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[bk.z]
		mm.instance_count = arr.size()
		for i in range(arr.size()):
			var e: Array = arr[i]
			mm.set_instance_transform(i, e[2])
			var key := "%s:%d:%d" % [kind, roundi(float(e[0]) * 2.0), roundi(float(e[1]) * 2.0)]
			_plants[key] = {"kind": kind, "x": float(e[0]), "z": float(e[1]), "mm": mm, "i": i, "xf": e[2]}
			var cell := Vector2i(int(floor(float(e[0]) / CELL)), int(floor(float(e[1]) / CELL)))
			if not _grid.has(cell):
				_grid[cell] = []
			(_grid[cell] as Array).append(key)
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = mat
		inst.visibility_range_end = VIS_END
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
	print("PLANTS ", counts)


## `accept` (optional) gets the plant dict and may veto it (the game: is the crosshair near it).
func nearest(pos: Vector3, fwd: Vector3, reach: float, accept: Callable = Callable()) -> Dictionary:
	var f2 := Vector2(fwd.x, fwd.z)
	f2 = f2.normalized() if f2.length() > 0.001 else Vector2(0, -1)
	var cx := int(floor(pos.x / CELL))
	var cz := int(floor(pos.z / CELL))
	var best := {}
	var bd := 1e9
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var arr = _grid.get(Vector2i(cx + ox, cz + oz))
			if arr == null:
				continue
			for key: String in (arr as Array):
				if picked.has(key) or _suppressed.has(key):
					continue
				var p: Dictionary = _plants[key]
				var to := Vector2(float(p["x"]) - pos.x, float(p["z"]) - pos.z)
				var d := to.length()
				if d > reach or d >= bd:
					continue
				if d > 0.8 and to.normalized().dot(f2) < 0.3:
					continue
				if accept.is_valid() and not accept.call(p):
					continue
				bd = d
				best = {"key": key, "kind": p["kind"], "d": d}
	return best


func get_plant(key: String) -> Dictionary:
	return _plants.get(key, {})


func _hide(key: String) -> void:
	var p: Dictionary = _plants[key]
	(p["mm"] as MultiMesh).set_instance_transform(int(p["i"]), Transform3D(Basis().scaled(Vector3.ZERO), (p["xf"] as Transform3D).origin))


func _show(key: String) -> void:
	var p: Dictionary = _plants[key]
	(p["mm"] as MultiMesh).set_instance_transform(int(p["i"]), p["xf"])


func is_hidden(key: String) -> bool:
	var p: Dictionary = _plants[key]
	return (p["mm"] as MultiMesh).get_instance_transform(int(p["i"])).basis.get_scale().y < 0.01


func pick(key: String, now_s: float) -> bool:
	if not _plants.has(key) or picked.has(key):
		return false
	var kd: Dictionary = KINDS[_plants[key]["kind"]]
	picked[key] = now_s + float(kd["regrow_h"]) * 3600.0
	_hide(key)
	return true


func update_regrow(now_s: float) -> void:
	for key in picked.keys():
		if now_s >= float(picked[key]):
			picked.erase(key)
			if _plants.has(key) and not _suppressed.has(key):
				_show(key)


func apply_picked(d: Dictionary) -> void:
	for key in d.keys():
		if _plants.has(key):
			picked[key] = float(d[key])
			_hide(key)


## Remove plants permanently near a building (not saved: recomputed each load).
func suppress_near(x: float, z: float, r: float) -> void:
	var cr := int(ceil(r / CELL)) + 1
	var cx := int(floor(x / CELL))
	var cz := int(floor(z / CELL))
	for oz in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var arr = _grid.get(Vector2i(cx + ox, cz + oz))
			if arr == null:
				continue
			for key: String in (arr as Array):
				var p: Dictionary = _plants[key]
				if Vector2(float(p["x"]) - x, float(p["z"]) - z).length() < r:
					_suppressed[key] = true
					_hide(key)


## Test helper: first plant key of a kind (not picked), or "".
func first_of(kind: String) -> String:
	for key in _plants.keys():
		if _plants[key]["kind"] == kind and not picked.has(key) and not _suppressed.has(key):
			return key
	return ""


func pos_of(key: String) -> Vector3:
	var p: Dictionary = _plants[key]
	return Vector3(float(p["x"]), 0.0, float(p["z"]))
