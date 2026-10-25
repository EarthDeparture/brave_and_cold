extends SceneTree
func _initialize() -> void:
	var src: String = load("res://entities/animals/wolf.gd").new().model_path
	print("WOLF model ", src)
	var c: Node3D = (load(src) as PackedScene).instantiate()
	root.add_child(c)
	for n: Node in c.find_children("*", "", true, false):
		if n is Node3D: print("WOLF ", n.name, " ", n.get_class(), " pos ", (n as Node3D).position, (" aabb " + str((n as MeshInstance3D).get_aabb())) if n is MeshInstance3D else "")
	quit()
