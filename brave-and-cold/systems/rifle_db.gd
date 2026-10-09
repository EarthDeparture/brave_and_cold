class_name RifleDB
extends RefCounted
## Per-rifle handling data (data/rifles.json). The eight ids match WeaponPresentation.IDS / the GLB art.

const PATH := "res://data/rifles.json"
const DEFAULT := "timber_bolt_carbine"
static var _data: Dictionary = {}


static func _load() -> void:
	if not _data.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(parsed is Dictionary, "rifles.json failed to parse")
	for k: String in parsed:
		if not k.begins_with("_"):
			_data[k] = parsed[k]


static func ids() -> Array:
	_load()
	return _data.keys()


static func spec(id: String) -> Dictionary:
	_load()
	return _data.get(id, _data.get(DEFAULT, {}))


static func mag(id: String) -> int:
	return int(spec(id).get("mag", 5))


static func value(id: String, key: String, fallback: float) -> float:
	return float(spec(id).get(key, fallback))


## Hip view the magnifications are measured against (Player.HIP_FOV, vertical degrees).
const HIP_FOV := 70.0
static var _zoom_cache: Dictionary = {}


static func optic(id: String) -> Dictionary:
	return spec(id).get("optic", {"type": "iron", "mag": [1.4], "reticle": "none", "label": "iron sights"})


## True magnification m -> vertical FOV: the image is m times larger than the hip view.
static func fov_for(m: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(HIP_FOV) * 0.5) / maxf(m, 1.0)))


## Fixed optics have one power; variable scopes step min -> geometric middle -> max.
static func magnifications(id: String) -> Array:
	var m: Array = optic(id).get("mag", [1.4])
	if m.size() >= 2: return [float(m[0]), sqrt(float(m[0]) * float(m[1])), float(m[1])]
	return [float(m[0])]


## Black-tube optic picture (model hidden) vs looking past the model (iron, reflex).
static func is_scoped(id: String) -> bool:
	return String(optic(id).get("type", "iron")) in ["scope", "tube_dot"]


## Aim FOV steps (mouse wheel), cached: called every frame by the viewmodel sync.
static func zoom(id: String) -> Array:
	if not _zoom_cache.has(id): _zoom_cache[id] = magnifications(id).map(func(v) -> float: return fov_for(float(v)))
	return _zoom_cache[id]
