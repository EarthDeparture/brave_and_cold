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


static func zoom(id: String) -> Array:
	var z: Array = spec(id).get("zoom", [36.0, 22.0, 13.0])
	return z.map(func(v) -> float: return float(v))
