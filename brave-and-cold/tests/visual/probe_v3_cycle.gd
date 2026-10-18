extends SceneTree
## Debug: bolt / lever cycle and reload poses of the v3 rifles (knob position, bolt travel).
func _initialize() -> void: call_deferred("run")
func run() -> void:
	RifleDB.inv = Inventory.new()
	for rid in ["ranger_box_rifle", "north_service_rifle", "brush_lever_rifle", "frontier_vented_rifle"]:
		var wp := WeaponPresentation.new(); root.add_child(wp); wp.set_weapon(rid); await process_frame
		var bh: Node3D = wp.sockets["BoltHand"]
		for t in [0.0, 0.16, 0.45, 0.78]:
			wp.sample("cycle", t)
			var bolt := wp.model.find_child("*Pivot_Bolt", true, false) as Node3D
			print("%s cycle t=%.2f knob=%s bolt=%s" % [rid, t, str(bh.global_position.snapped(Vector3.ONE * .001)), str(bolt.position.snapped(Vector3.ONE * .001)) if bolt else "-"])
		wp.queue_free(); await process_frame
	quit()
