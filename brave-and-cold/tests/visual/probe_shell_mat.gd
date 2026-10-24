extends SceneTree
func _initialize() -> void:
	var s: Node = (load("res://assets/models/buildings/cabin_burned.glb") as PackedScene).instantiate()
	root.add_child(s)
	var mis := s.find_children("*", "MeshInstance3D", true, false)
	print("SHELL meshinstances=", mis.size())
	for m in mis:
		var mi := m as MeshInstance3D
		var mesh := mi.mesh
		print("SHELL ", mi.name, " surfaces=", mesh.get_surface_count(), " mat0=", mesh.surface_get_material(0))
		var arr := mesh.surface_get_arrays(0)
		var cols = arr[Mesh.ARRAY_COLOR]
		if cols != null and cols.size() > 0:
			var acc := Color(0, 0, 0, 0)
			for c in cols: acc += c
			print("SHELL avg vertex colour ", acc / float(cols.size()), " n=", cols.size())
		else:
			print("SHELL no vertex colours")
	var c2: Node = (load("res://assets/models/buildings/cabin.glb") as PackedScene).instantiate()
	for m in c2.find_children("*", "MeshInstance3D", true, false):
		var arr2 := (m as MeshInstance3D).mesh.surface_get_arrays(0)
		var cc = arr2[Mesh.ARRAY_COLOR]
		if cc != null and cc.size() > 0:
			var a2 := Color(0, 0, 0, 0)
			for c in cc: a2 += c
			print("CABIN ", m.name, " avg ", a2 / float(cc.size()))
	quit(0)
