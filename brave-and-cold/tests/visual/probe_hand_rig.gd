extends SceneTree
## Debug: hand rig bones, grips, and fingertip positions per grip.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for m in [false, true]:
		var h := SurvivorHandRig.new(); h.mirrored = m; root.add_child(h); await process_frame
		var sk := h.skeleton
		print("== mirrored=", m, " grips=", h.grips.keys())
		for b in sk.get_bone_count():
			var g := sk.get_bone_global_rest(b)
			print("  %d %s parent=%d rest_pos=%s" % [b, sk.get_bone_name(b), sk.get_bone_parent(b), str(g.origin.snapped(Vector3.ONE * .001))])
		for grip in h.grips.keys():
			h.pose(grip)
			var tips := []
			for b in sk.get_bone_count():
				if sk.get_bone_name(b).ends_with("3") or sk.get_bone_name(b).contains("tip") or sk.get_bone_name(b).contains("distal"):
					tips.append("%s%s" % [sk.get_bone_name(b), str(sk.get_bone_global_pose(b).origin.snapped(Vector3.ONE * .001))])
			print("  grip ", grip, " ", " ".join(tips))
		h.queue_free(); await process_frame
	quit()
