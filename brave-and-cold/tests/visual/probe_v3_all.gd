extends SceneTree
## Debug: every v3 rifle with its factory fit: sockets, aim height, clips, attachments.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var inv := Inventory.new(); RifleDB.inv = inv
	for rid: String in WeaponPresentation.IDS:
		var wp := WeaponPresentation.new(); root.add_child(wp)
		wp.set_weapon(rid)
		await process_frame
		var clips := Array(wp.animation_player.get_animation_list())
		print("== %s v3=%s action=%s aim_h=%.4f iron=%.4f eye=%.4f dots=%d lamp=%s optic=%s clips=%s" % [rid, RifleDB.is_v3(rid), RifleDB.action(rid), wp.aim_height(), wp._iron_y, wp._eye_y, wp.dot_mats.size(), wp.lamp != null, wp.optic_node != null, ",".join(clips)])
		print("   sockets ", ",".join(wp.sockets.keys()), "  fit ", RifleDB.fitted(rid))
		wp.queue_free(); await process_frame
	# fit rules
	inv.add("north_service_rifle"); inv.add("scout_mount_clamp"); inv.add("scope_scout_2x"); inv.add("reflex_micro"); inv.add("scope_4_12x"); inv.add("muzzle_moderator")
	print("service + 2x before mount: ", RifleDB.fits("north_service_rifle", "scope_scout_2x"), " reason: ", RifleDB.fit_reason("north_service_rifle", "scope_scout_2x"))
	print("fit mount: '", inv.fit_attachment("north_service_rifle", "mount", "scout_mount_clamp"), "'")
	print("fit 2x: '", inv.fit_attachment("north_service_rifle", "optic", "scope_scout_2x"), "' zero ", inv.zero_of("north_service_rifle"))
	var wp2 := WeaponPresentation.new(); root.add_child(wp2); wp2.set_weapon("north_service_rifle"); await process_frame
	print("service scout aim_h %.4f mount_node %s optic %s" % [wp2.aim_height(), wp2.mount_node != null, wp2.optic_node != null])
	print("remove mount: '", inv.fit_attachment("north_service_rifle", "mount", ""), "' optic now '", RifleDB.fitted("north_service_rifle").get("optic"), "' pack 2x ", inv.count("scope_scout_2x"))
	print("4-12x on compact rail: ", RifleDB.fits("compact_patrol_rifle", "scope_4_12x"), " / ", RifleDB.fit_reason("compact_patrol_rifle", "scope_4_12x"))
	print("moderator on ranger: ", RifleDB.fits("ranger_box_rifle", "muzzle_moderator"), " / ", RifleDB.fit_reason("ranger_box_rifle", "muzzle_moderator"))
	inv.add("compact_patrol_rifle")
	print("moderator on compact: '", inv.fit_attachment("compact_patrol_rifle", "muzzle", "muzzle_moderator"), "' noise ", RifleDB.muzzle("compact_patrol_rifle"))
	var wp3 := WeaponPresentation.new(); root.add_child(wp3); wp3.set_weapon("compact_patrol_rifle"); await process_frame
	print("compact muzzle socket at ", wp3.sockets["Muzzle"].global_position)
	quit()
