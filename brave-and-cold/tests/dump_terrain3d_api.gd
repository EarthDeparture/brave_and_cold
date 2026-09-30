extends SceneTree
## Prints Terrain3D API surface so scripts match the installed addon version.
func _initialize() -> void:
	for c in ["Terrain3D", "Terrain3DData", "Terrain3DUtil", "Terrain3DRegion"]:
		print("== ", c)
		for m in ClassDB.class_get_method_list(c, true):
			print("M ", m.name)
		for p in ClassDB.class_get_property_list(c, true):
			print("P ", p.name)
		for k in ClassDB.class_get_integer_constant_list(c, true):
			print("C ", k)
	quit(0)
