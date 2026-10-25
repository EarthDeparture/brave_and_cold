extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var wp := WeaponPresentation.new(); root.add_child(wp)
	wp.set_weapon("compact_patrol_rifle")
	await process_frame
	print("ROOT fwd ", -wp.global_transform.basis.z)
	for n in wp.model.find_children("*", "Node3D", true, false):
		var s := String(n.name)
		if s.contains("Socket") or s.contains("Attach") or s.contains("Lamp") or s.begins_with("compact") or s.begins_with("reflex") or s.begins_with("light"):
			var g := (n as Node3D).global_transform
			print("%s pos=%s fwd=%s parent=%s" % [s, str(g.origin.snapped(Vector3.ONE * .001)), str((-g.basis.z).snapped(Vector3.ONE * .01)), n.get_parent().name])
	print("aim_height ", wp.aim_height(), " lamp ", wp.lamp != null, " dots ", wp.dot_mats.size())
	quit()
