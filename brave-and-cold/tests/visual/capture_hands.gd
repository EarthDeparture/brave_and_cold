extends SceneTree
## Hand-contact review: the viewmodel hands on v3 rifles from the player's eye (hip, aimed) and from
## debug cameras beside the support hand and the grip hand. -> res://shots/hands/  (-- only=id,id)
var w: Node3D
var only: Array = ["ranger_box_rifle", "compact_patrol_rifle"]
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(id: String) -> void:
	await frames(30)
	root.get_texture().get_image().save_png("res://shots/hands/" + id + ".png"); print("HAND_CAPTURE ", id)
func close_cam(target: Vector3, from: Vector3) -> Camera3D:
	var c := Camera3D.new(); c.fov = 38.0; c.near = 0.01; root.add_child(c)
	c.global_position = from; c.look_at(target, Vector3.UP); c.make_current(); return c
func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="): only = Array(a.substr(5).split(","))
	root.size = Vector2i(1600, 900); SaveGame.pending = {}; seed(20261004)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/hands"))
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and bool(w.get("built")): break
	w.out_path = ""; w.player.god = true
	w.story_skip_to(1, 11.0)
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	w.player.yaw = w.fire_lookout.rotation.y + PI; w.player.pitch = -0.06
	for rid: String in only:
		if w.inv.count(rid) < 1: w.inv.add(rid)
		w.inv.use(rid); w.rifle_up = true; w.player.zoom_i = 0
		w.aim_override = false; await shot(rid + "_hip")
		var vm = w.viewmodel
		var cam: Camera3D = w.player.cam
		for hn in ["_left", "_right"]:
			var h: SurvivorHandRig = vm.get(hn)
			var sk := h.skeleton
			var inv_cam := cam.global_transform.affine_inverse()
			var pts := []
			for bn in ["hand", "middle_01", "middle_03", "thumb_03", "index_03"]:
				pts.append("%s%s" % [bn, str((inv_cam * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bn))).origin).snapped(Vector3.ONE * .001))])
			print("HAND ", rid, " ", hn, " basis(cam)=", (inv_cam.basis * h.global_basis), " ", " ".join(pts))
		print("HANDL socket(cam) ", (cam.global_transform.affine_inverse() * vm._rifle.sockets["HandL"].global_position).snapped(Vector3.ONE * .001))
		var lp: Vector3 = vm._left.global_position; var rp: Vector3 = vm._right.global_position
		var cb := cam.global_basis
		var c1 := close_cam(lp, lp - cb.x * 0.22 + cb.y * 0.05 + cb.z * 0.10); await shot(rid + "_left_side")
		c1.global_position = lp - cb.y * 0.20 + cb.z * 0.05 - cb.x * 0.05; c1.look_at(lp, Vector3.UP); await shot(rid + "_left_below")
		c1.global_position = rp + cb.x * 0.22 + cb.y * 0.06 + cb.z * 0.06; c1.look_at(rp, Vector3.UP); await shot(rid + "_right_side")
		c1.queue_free(); cam.make_current()
		w.aim_override = true; await shot(rid + "_ads")
	quit(0)
