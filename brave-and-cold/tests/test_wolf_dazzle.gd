extends SceneTree
## Weapons W7: a chasing wolf caught in your torch beam under 15 m slows and weaves instead of running you
## down (live wolf AI, real chase, not just the flag). Same wolf, same start, beam off vs beam in its eyes.
var checks := 0
var failures := 0
var w: Node3D
var yaw0 := 0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame

func aim_at(p: Vector3) -> void:
	var d: Vector3 = p + Vector3.UP * 0.5 - w.player.cam.global_position
	w.player.yaw = atan2(-d.x, -d.z); w.player.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func chase(lit: bool) -> Dictionary:
	var fwd := Vector3(-sin(yaw0), 0, -cos(yaw0))
	var p: Vector3 = w.player.global_position + fwd * 12.0
	p.y = w._ground_y(p.x, p.z)
	var wolf: Wolf = w._add_wolf(p, 77)
	await frames(2)
	wolf._set_state(Wolf.State.CHASE)
	w.inv.torch_on = lit; w.inv.torch_h = 6.0
	var d0: float = Vector2(wolf.global_position.x - w.player.global_position.x, wolf.global_position.z - w.player.global_position.z).length()
	var lateral := 0.0; var prev: Vector3 = wolf.global_position
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		aim_at(wolf.global_position)
		await process_frame
		var to_p: Vector3 = w.player.global_position - wolf.global_position; to_p.y = 0
		var mv: Vector3 = wolf.global_position - prev; mv.y = 0; prev = wolf.global_position
		if to_p.length() > 0.1: lateral += absf(mv.normalized().cross(to_p.normalized()).y) * mv.length()
	var d1: float = Vector2(wolf.global_position.x - w.player.global_position.x, wolf.global_position.z - w.player.global_position.z).length()
	var r := {"closed": d0 - d1, "lateral": lateral, "dazzle": wolf._dazzle_t, "lit_flag": Wolf.player_lit}
	w.wolves.erase(wolf); wolf.queue_free(); w.inv.torch_on = false
	await frames(3)
	return r

func run() -> void:
	create_timer(170).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261022)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""; w.player.god = true
	w.clock.hour = 22.5
	var pt: Vector3 = w.fire_lookout.approach_point(14.0); w.player.place(pt.x, pt.z)
	yaw0 = w.player.yaw
	w.inv.add("flashlight"); w.rifle_up = false
	await frames(10)
	var dark := await chase(false)
	var lit := await chase(true)
	print("  unlit ", dark, "  lit ", lit)
	check(bool(lit["lit_flag"]) and float(lit["dazzle"]) > 0.3, "the beam is on the wolf and it registers (dazzle %.2f s)" % float(lit["dazzle"]))
	check(float(dark["closed"]) > 4.0, "unlit: the wolf runs you down (closed %.1f m in 1.4 s)" % float(dark["closed"]))
	check(float(lit["closed"]) < 0.7 * float(dark["closed"]), "beam in its eyes: it closes far slower (%.1f m vs %.1f m)" % [float(lit["closed"]), float(dark["closed"])])
	check(float(lit["lateral"]) > float(dark["lateral"]) + 0.3, "and it weaves sideways (%.1f m vs %.1f m lateral)" % [float(lit["lateral"]), float(dark["lateral"])])
	w.queue_free(); await process_frame; await process_frame
	print("WOLF_DAZZLE_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
