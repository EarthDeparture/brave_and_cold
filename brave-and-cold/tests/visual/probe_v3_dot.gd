extends SceneTree
## Debug: for each dotted optic, where is the DotLens, which way do its faces point, and
## what angle does the shader see for a camera sitting at Socket_Eye looking down the axis.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var inv := Inventory.new(); RifleDB.inv = inv
	for oid in ["reflex_micro", "reddot_tube"]:
		inv.fitted["compact_patrol_rifle"] = {"optic": oid, "light": "", "light_h": 0.0}
		var wp := WeaponPresentation.new(); root.add_child(wp)
		wp.set_weapon("compact_patrol_rifle")
		await process_frame
		print("== ", oid, " dots=", wp.dot_mats.size(), " aim_h=", wp.aim_height(), " optic=", RifleDB.optic("compact_patrol_rifle"))
		for mi: MeshInstance3D in wp.optic_node.find_children("*", "MeshInstance3D", true, false):
			var aabb := mi.global_transform * mi.get_aabb()
			print("  ", mi.name, " aabb_c=", aabb.get_center().snapped(Vector3.ONE * .0005), " size=", aabb.size.snapped(Vector3.ONE * .0005),
				" mat=", mi.material_override, " vis=", mi.is_visible_in_tree())
		var eye := wp.optic_node.find_child("*Socket_Eye", true, false) as Node3D
		print("  eye ", eye.global_position.snapped(Vector3.ONE * .0005))
		for m in wp.dot_mats: print("  dot_on=", m.get_shader_parameter("dot_on"), " mrad=", m.get_shader_parameter("dot_mrad"))
		wp.queue_free(); await process_frame
	quit()
