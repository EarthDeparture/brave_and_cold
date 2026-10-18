extends SceneTree
## Weapon kit v3 (W1-W5): every rifle's art contract (sockets, clips, sight line), the attachment
## fit rules, field fits losing zero and the bench zeroing, moderators, weapon / hand lights and
## their battery, light visibility, the gunsmith screen, and save/load of all of it.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func run() -> void:
	create_timer(170).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	var inv := Inventory.new(); RifleDB.inv = inv
	# ---- art contract per rifle
	var art_ok := true; var notes: Array = []
	for rid: String in WeaponPresentation.IDS:
		check(RifleDB.is_v3(rid), "%s is weapon kit v3" % rid)
		var wp := WeaponPresentation.new(); root.add_child(wp); wp.set_weapon(rid); await process_frame
		var need := ["HandR", "HandL", "BoltHand", "Muzzle", "Aim", "IronAim"]
		need.append("LoadingGate" if RifleDB.action(rid) == "lever" else "MagazineHand")
		for s in need:
			if not wp.sockets.has(s): art_ok = false; notes.append(rid + ":" + s)
		var clips := Array(wp.animation_player.get_animation_list())
		for c in ["idle", "fire", "cycle", "equip", "unequip", "inspect"] + (["reload_start", "reload_insert", "reload_end"] if RifleDB.action(rid) == "lever" else ["reload_tactical", "reload_empty"]):
			if not clips.has(c): art_ok = false; notes.append(rid + ":" + c)
		# the eye line clears everything between the eye and the muzzle (no part of the gun above it in the sight picture)
		var f := RifleDB.fitted(rid)
		if String(f.get("optic", "")) != "" and wp.optic_node == null: art_ok = false; notes.append(rid + ": factory optic missing")
		wp.queue_free(); await process_frame
	check(art_ok, "every v3 rifle has its sockets, clips and factory optic %s" % str(notes))
	check(RifleDB.action("ranger_box_rifle") == "bolt" and RifleDB.action("north_service_rifle") == "bolt" and RifleDB.action("brush_lever_rifle") == "lever" and RifleDB.action("frontier_vented_rifle") == "semi",
		"actions match the art: bolt rifles cycle a bolt, the lever gun a lever")
	# bolt cycle really lifts the handle and draws the bolt back
	var wb := WeaponPresentation.new(); root.add_child(wb); wb.set_weapon("ranger_box_rifle"); await process_frame
	var k0: Vector3 = (wb.sockets["BoltHand"] as Node3D).global_position
	wb.sample("cycle", 0.45); var k1: Vector3 = (wb.sockets["BoltHand"] as Node3D).global_position
	check(k1.y - k0.y > .03 and k1.z - k0.z > .07, "bolt cycle: knob lifts %.0f mm and comes back %.0f mm" % [(k1.y - k0.y) * 1000, (k1.z - k0.z) * 1000])
	wb.queue_free(); await process_frame
	# ---- fit rules (realism)
	check(not RifleDB.fits("brush_lever_rifle", "scope_4x") and RifleDB.fit_reason("brush_lever_rifle", "scope_4x") == "No scope mount on this rifle", "lever gun takes no scope")
	check(not RifleDB.fits("compact_patrol_rifle", "scope_4_12x") and RifleDB.fits("ranger_box_rifle", "scope_4_12x"), "4-12x needs drilled bases, not a .22 rail")
	check(not RifleDB.fits("ranger_box_rifle", "muzzle_moderator") and RifleDB.fits("compact_patrol_rifle", "muzzle_moderator") and RifleDB.fits("ridge_scout_rifle", "muzzle_moderator"), "moderators only on threaded barrels")
	check(RifleDB.fits("brush_lever_rifle", "light_taped") and not RifleDB.fits("brush_lever_rifle", "light_clamp"), "tube-magazine lever gun: taped light only, no clamp")
	check(not RifleDB.fits("north_service_rifle", "scope_scout_2x"), "service rifle: no scope until a scout mount is clamped on")
	inv.add("north_service_rifle"); inv.add("scout_mount_clamp"); inv.add("scope_scout_2x"); inv.add("screwdriver")
	check(inv.fit_attachment("north_service_rifle", "optic", "scope_scout_2x") != "", "refused while there is no mount")
	check(inv.fit_attachment("north_service_rifle", "mount", "scout_mount_clamp") == "" and inv.fit_attachment("north_service_rifle", "optic", "scope_scout_2x") == "", "clamp-on scout mount, then the 2x on it")
	check(inv.zero_of("north_service_rifle").length() >= 1.4, "a sight fitted in the field is off zero (%.1f mrad)" % inv.zero_of("north_service_rifle").length())
	inv.fit_attachment("north_service_rifle", "mount", "")
	check(String(RifleDB.fitted("north_service_rifle").get("optic")) == "" and inv.count("scope_scout_2x") == 1 and inv.count("scout_mount_clamp") == 1, "removing the mount brings the scope off with it, both back in the pack")
	inv.add("ranger_box_rifle")
	inv.fit_attachment("ranger_box_rifle", "optic", "", true); inv.fit_attachment("ranger_box_rifle", "optic", "scope_4x", true)
	check(inv.zero_of("ranger_box_rifle").length() < .01, "bench work keeps the zero")
	# moderator: rimfire gains far more than centrefire
	inv.add("compact_patrol_rifle"); inv.add("muzzle_moderator"); inv.add("ridge_scout_rifle"); inv.add("muzzle_moderator")
	inv.fit_attachment("compact_patrol_rifle", "muzzle", "muzzle_moderator"); inv.fit_attachment("ridge_scout_rifle", "muzzle", "muzzle_moderator")
	var mr := float(RifleDB.muzzle("compact_patrol_rifle").get("noise_mult", 1)); var mc := float(RifleDB.muzzle("ridge_scout_rifle").get("noise_mult", 1))
	check(mr < .4 and mc > .5 and mc < .8, "moderated .22 at %d %% noise, a centrefire still %d %%" % [roundi(mr * 100), roundi(mc * 100)])
	# light battery is kept when a light comes off and goes back on (no free recharge)
	inv.add("light_clamp")
	inv.fit_attachment("ranger_box_rifle", "light", "light_clamp")
	var f2: Dictionary = inv.fitted["ranger_box_rifle"]; f2["light_h"] = 1.25; inv.fitted["ranger_box_rifle"] = f2
	inv.fit_attachment("ranger_box_rifle", "light", ""); inv.fit_attachment("ranger_box_rifle", "light", "light_clamp")
	check(absf(float(RifleDB.fitted("ranger_box_rifle").get("light_h")) - 1.25) < .001, "a light keeps its battery charge off the rifle")
	check(RecipeDB.all().any(func(r) -> bool: return String(r.get("id", "")) == "tape_light" and r.get("out", {}).has("light_taped")), "flashlight + duct tape crafts a taped light")
	# ---- live world: zero moves the shot, light visibility, hand torch, gunsmith, save/load
	SaveGame.pending = {}; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	w.inv.add("ranger_box_rifle"); w.inv.use("ranger_box_rifle"); w.rifle_up = true; w.aim_override = true
	await frames(40)
	w.inv.zero["ranger_box_rifle"] = [0.0, 3.0]
	var up := 0.0
	for i in 20: up += w._shot_dir().dot(w.player.cam.global_basis.y)
	check(up / 20.0 > .0022, "a 3 mrad zero error lifts the shots (%.2f mrad mean)" % (up / 20.0 * 1000))
	w.inv.zero["ranger_box_rifle"] = [0.0, 0.0]
	# hand flashlight
	w.rifle_up = false; w.aim_override = false; w.inv.add("flashlight"); w.inv.torch_h = 6.0; w.inv.torch_on = false
	w._toggle_weapon_light(); await frames(5)
	check(w.torch_shining() and w._torch != null and w._torch.visible and Zombie.player_lit, "L with the rifle lowered: handheld flashlight on, you are lit")
	var h0: float = w.inv.torch_h
	w.clock.time_scale = 3600.0; await frames(30); w.clock.time_scale = 30.0
	check(w.inv.torch_h < h0, "flashlight battery drains (%.2f h -> %.2f h)" % [h0, w.inv.torch_h])
	w.inv.torch_h = 0.0; await frames(3)
	check(not w.torch_shining() and not Zombie.player_lit, "dead flashlight: dark, not lit")
	w.inv.add("cell_batteries"); w._toggle_weapon_light()
	check(w.inv.torch_on and w.inv.torch_h > 5.9 and w.inv.count("cell_batteries") == 0, "fresh batteries go in on L")
	# gunsmith screen: opens, fits, refuses without tools away from a bench
	w.inv.add("scope_3_9x"); w.inv.remove("screwdriver")
	w.open_gunsmith("ranger_box_rifle", false); await frames(5)
	check(w.gunsmith != null and w.gunsmith.is_open and w.gunsmith._gun != null, "gunsmith screen opens with the rifle in its 3D view")
	var why: String = w.gunsmith_fit("ranger_box_rifle", "optic", "scope_3_9x", false)
	check(why.contains("screwdriver"), "field scope swap needs a screwdriver (%s)" % why)
	w.inv.add("screwdriver")
	check(w.gunsmith_fit("ranger_box_rifle", "optic", "scope_3_9x", false) == "" and not w.gunsmith.is_open, "with tools: the swap starts as a timed action")
	for i in 600:
		await process_frame
		if String(RifleDB.fitted("ranger_box_rifle").get("optic")) == "scope_3_9x" and w.gunsmith.is_open: break
	check(String(RifleDB.fitted("ranger_box_rifle").get("optic")) == "scope_3_9x" and w.inv.count("scope_4x") >= 1, "3-9x fitted, the 4x back in the pack")
	check(w.inv.zero_of("ranger_box_rifle").length() > 1.0, "and the rifle needs zeroing")
	check(w.gunsmith_zero("ranger_box_rifle") == "Zero it at a workbench" or w.at_workbench(), "zeroing needs the workbench")
	w.gunsmith.close()
	# save / load of fits, zero, torch
	var d: Dictionary = w._save_data().duplicate(true)
	check(d["inv"].has("zero") and d["inv"].has("torch_h") and (d["inv"]["fitted"] as Dictionary).has("ranger_box_rifle"), "save carries fits, zero and the flashlight")
	w.queue_free(); await process_frame; await process_frame
	print("WEAPON_KIT_V3_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
