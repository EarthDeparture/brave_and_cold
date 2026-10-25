extends SceneTree
## Debug: does a posed grip survive a few frames (AnimationPlayer / RESET overriding the skeleton)?
func _initialize() -> void: call_deferred("run")
func tip(h: SurvivorHandRig, n: String) -> Vector3:
	return h.skeleton.get_bone_global_pose(h.skeleton.find_bone(n)).origin.snapped(Vector3.ONE * .001)
func run() -> void:
	for m in [false, true]:
		var h := SurvivorHandRig.new(); h.mirrored = m; root.add_child(h); await process_frame; await process_frame
		h.pose("ForeGrip")
		print("== mirrored=", m, " now middle_03=", tip(h, "middle_03"))
		for i in 5: await process_frame
		print("   after 5 frames middle_03=", tip(h, "middle_03"))
		var ap := h.find_child("AnimationPlayer", true, false) as AnimationPlayer
		print("   anim playing=", ap.is_playing(), " current=", ap.current_animation, " autoplay=", ap.autoplay, " active=", ap.active)
		# mesh-space check: a skinned vertex near the middle fingertip
		var mi := h.bare
		print("   bare skin bind count=", mi.skin.get_bind_count() if mi.skin else -1)
		h.queue_free(); await process_frame
	quit()
