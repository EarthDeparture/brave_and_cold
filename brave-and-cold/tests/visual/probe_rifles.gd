extends SceneTree
## Lists every node of each rifle GLB (name, type, local AABB for meshes) for the weapon pass.
func _initialize() -> void:
	for id in WeaponPresentation.IDS:
		var m: Node3D = (load("res://assets/weapons/north_ridge/%s.glb" % id) as PackedScene).instantiate()
		root.add_child(m)
		var lines := []
		for n in m.find_children("*", "", true, false):
			var s := String(n.name).replace(id + "__", "")
			if n is MeshInstance3D:
				var a: AABB = (n as MeshInstance3D).get_aabb()
				var g := (n as MeshInstance3D).global_transform * a
				lines.append("M %s tris=%d y=[%.3f,%.3f] z=[%.3f,%.3f]" % [s, (n as MeshInstance3D).mesh.get_faces().size() / 3, g.position.y, g.end.y, g.position.z, g.end.z])
			elif n is Node3D:
				var p := (n as Node3D).global_position
				lines.append("N %s (%.3f,%.3f,%.3f)" % [s, p.x, p.y, p.z])
		print("RIFLE ", id, "\n  ", "\n  ".join(lines))
		m.queue_free()
	quit()
