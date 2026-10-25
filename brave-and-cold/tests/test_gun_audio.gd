extends SceneTree
## Weapons W7: rifle reports. Report class per rifle, the mix order (moderated .22 < moderated centrefire <
## open .22 < open rifle), a moderated supersonic shot adds the crack and a crack echo while a subsonic .22
## does not, first-round pop, hearing dulled by an open shot only, crack noises along a moderated bullet's path,
## no muzzle flash with a moderator, action foley from the bolt cycle, and the generated files load.
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
	# ---- data
	check(RifleDB.report_class("compact_patrol_rifle") == "rimfire" and not RifleDB.supersonic("compact_patrol_rifle"), "the .22 is a subsonic rimfire report")
	check(RifleDB.report_class("expedition_rifle") == "magnum_brake" and RifleDB.report_class("frontier_vented_rifle") == "intermediate" and RifleDB.supersonic("ridge_scout_rifle"), "magnum + brake, intermediate SKS, supersonic varmint")
	var R: Dictionary = GameAudio.REPORT_DB
	check(R["sup_rimfire"] < R["sup_centre"] and R["sup_centre"] < R["rimfire"] and R["rimfire"] < R["medium"], "mix order: moderated .22 < moderated centrefire < open .22 < open rifle")
	var names := ["blast_rimfire_0", "blast_medium_2", "blast_magnum_brake_1", "blast_sup_rimfire_0", "blast_sup_centre_2", "crack_1", "tail_out_0", "tail_out_1", "tail_crack_out", "tail_in",
		"bolt_up", "bolt_back", "bolt_fwd", "bolt_down", "lever_open", "lever_close", "semi_clack"]
	var ga := GameAudio.new(); root.add_child(ga)
	var all_ok := true; var long := 0.0
	for n in names:
		var s := ga.weapon_stream(n)
		if s == null: all_ok = false; print("  missing ", n)
		else: long = maxf(long, s.get_length())
	check(all_ok and long < 3.1, "report kit files load (longest %.2f s)" % long)
	ga.queue_free()
	# ---- live world
	SaveGame.pending = {}; seed(20261021)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	w.player.position = w.fire_lookout.to_global(Vector3(-2.0, FireLookout.DECK_Y + w.player.eye_h, 2.8))
	await frames(10)
	var a: GameAudio = w.audio
	# open hunting rifle
	w.inv.add("ranger_box_rifle"); w.inv.use("ranger_box_rifle"); w.rifle_up = true; await frames(3)
	a.hearing_dose = 0.0
	a.gunshot("ranger_box_rifle")
	var lr: Dictionary = a.last_report
	check(lr.get("blast") == "medium" and not lr.get("moderated") and not (lr["layers"] as Array).any(func(x) -> bool: return String(x).begins_with("crack")), "open rifle: full blast, crack already inside it, no extra crack layer")
	check(a.hearing_dose > 0.4, "an open shot dulls your hearing (dose %.2f)" % a.hearing_dose)
	await frames(30)
	check(a._hear_lp != null and a._hear_lp.cutoff_hz < 8000.0, "hearing low-pass dipped (%.0f Hz)" % (a._hear_lp.cutoff_hz if a._hear_lp != null else -1.0))
	a.hearing_dose = 0.0
	# moderated .22 (subsonic)
	w.inv.add("compact_patrol_rifle"); w.inv.add("muzzle_moderator")
	w.inv.fit_attachment("compact_patrol_rifle", "muzzle", "muzzle_moderator", true)
	check(RifleDB.moderated("compact_patrol_rifle"), "moderator fitted on the .22")
	a.gunshot("compact_patrol_rifle"); lr = a.last_report
	check(lr.get("blast") == "sup_rimfire" and not (lr["layers"] as Array).any(func(x) -> bool: return String(x).begins_with("crack") or String(x) == "tail_crack_out"), "moderated subsonic .22: pfft, no crack")
	check(bool(lr.get("pop")), "first shot from a cold can: first-round pop")
	var pop_db: float = lr["db"]
	a.gunshot("compact_patrol_rifle"); lr = a.last_report
	check(not bool(lr.get("pop")) and float(lr["db"]) < pop_db - 3.0, "second shot: no pop, %.1f dB quieter" % (pop_db - float(lr["db"])))
	check(a.hearing_dose < 0.01, "moderated shots leave your hearing alone")
	check(w._flash_mult("compact_patrol_rifle") == 0.0 and w._flash_mult("expedition_rifle") > 1.0 and w._flash_mult("ranger_box_rifle") == 1.0, "no muzzle flash with a moderator; the brake's is bigger")
	check((lr["layers"] as Array).has("semi_clack"), "the self-loader's action clacks (what you hear with a can on)")
	# moderated supersonic varmint rifle
	w.inv.add("ridge_scout_rifle"); w.inv.add("muzzle_moderator")
	w.inv.fit_attachment("ridge_scout_rifle", "muzzle", "muzzle_moderator", true)
	a.gunshot("ridge_scout_rifle"); lr = a.last_report
	check(lr.get("blast") == "sup_centre" and (lr["layers"] as Array).any(func(x) -> bool: return String(x).begins_with("crack")) and (lr["layers"] as Array).has("tail_crack_out"), "moderated supersonic rifle: thup + the bullet's crack + its echo")
	# crack noise along the path
	w.instant_bullets = true
	w._bullet_crack = true
	var eye: Vector3 = w.player.cam.global_position
	w._spawn_bullet(eye, Vector3(0, 0.08, -1).normalized())
	check(w.crack_log.size() >= 3 and (w.crack_log[0] as Vector3).distance_to(eye) > 20.0, "a moderated supersonic bullet cracks along its path (%d points)" % w.crack_log.size())
	w._spawn_bullet(eye, Vector3(0, 0.08, -1).normalized())
	check(w.crack_log.is_empty(), "an ordinary shot logs no path cracks")
	# action foley from the bolt cycle
	var evs: Array = []
	w.viewmodel.mech.connect(func(e: String) -> void: evs.append(e))
	w.inv.use("ranger_box_rifle"); w.rifle_up = true; w.aim_override = false; await frames(20)
	w.viewmodel.fire()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500 and evs.size() < 4: await process_frame
	check(evs == ["bolt_up", "bolt_back", "bolt_fwd", "bolt_down"], "bolt cycle foley in order (%s)" % str(evs))
	# W8: reload foley (bolt rifle empty reload, then a self-loader), dry click
	await frames(30); evs.clear()
	w.viewmodel.play_weapon_clip("reload_empty")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3600 and w.viewmodel._weapon_clip != "": await process_frame
	check(evs == ["mag_release", "mag_out", "mag_in", "mag_seat", "bolt_up", "bolt_back", "bolt_fwd", "bolt_down"], "bolt rifle empty reload foley in order (%s)" % str(evs))
	evs.clear()
	w.inv.use("compact_patrol_rifle"); w.rifle_up = true; await frames(40)
	w.viewmodel.play_weapon_clip("reload_empty")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3600 and w.viewmodel._weapon_clip != "": await process_frame
	check(evs.has("charge_back") and evs.has("bolt_release") and not evs.has("bolt_up"), "self-loader works its charging handle, not a bolt handle (%s)" % str(evs))
	evs.clear(); w.viewmodel.dry()
	check(evs == ["dry_click"] and a.weapon_stream("dry_click") != null, "dry fire clicks")
	# W8: buses - the hearing dip lives on World; menu sounds stay on Master
	check(AudioServer.get_bus_index("World") > 0 and a._hear_lp != null, "World bus carries the hearing low-pass")
	var master_lp := false
	for i in AudioServer.get_bus_effect_count(0): master_lp = master_lp or AudioServer.get_bus_effect(0, i) is AudioEffectLowPassFilter
	check(not master_lp, "Master has no hearing filter (menu clicks never muffled)")
	var wp := AudioStreamPlayer3D.new(); w.add_child(wp)
	var up := AudioStreamPlayer.new(); up.name = "UiSound_test"; root.add_child(up)
	check(wp.bus == "World" and up.bus == "Master", "in-world players go to World, UI sounds stay on Master")
	wp.queue_free(); up.queue_free()
	w.queue_free(); await process_frame; await process_frame
	print("GUN_AUDIO_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
