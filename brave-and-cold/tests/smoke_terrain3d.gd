extends SceneTree
## Smoke test: Terrain3D GDExtension is loaded and instantiable.
func _init() -> void:
	var ok := ClassDB.class_exists("Terrain3D")
	print("TERRAIN3D_CLASS_EXISTS=", ok)
	if ok:
		var t = ClassDB.instantiate("Terrain3D")
		print("TERRAIN3D_VERSION=", t.get("version") if t.has_method("get") else "n/a")
		t.free()
	quit(0 if ok else 1)
