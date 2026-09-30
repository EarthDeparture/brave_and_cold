class_name SaveGame
extends RefCounted
## Single-slot JSON save in user://. `pending` carries loaded data into the next GameWorld.

const PATH := "user://save.json"
const VERSION := 1
static var pending: Dictionary = {}


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func write(data: Dictionary) -> bool:
	data["v"] = VERSION
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_dst := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(abs_dst)
	return DirAccess.rename_absolute(abs_tmp, abs_dst) == OK


static func read() -> Dictionary:
	if not exists():
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(v) != TYPE_DICTIONARY or int(v.get("v", 0)) != VERSION:
		return {}
	return v


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))