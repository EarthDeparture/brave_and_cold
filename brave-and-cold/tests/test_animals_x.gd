extends SceneTree
## X pass: lofted animal models v2 (wolf / deer / bear) keep their part names, legs come in two pieces that bend
## in the gait and straighten at rest, the fur material is on every part, bear claws ride the paw.
var checks := 0
var failures := 0
var w: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await process_frame

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(20261028)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 900:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null and w.world_events != null: break
	w.out_path = ""; w.player.god = true
	var pp: Vector3 = w.player.global_position + Vector3(60, 0, 60)
	pp.y = w._ground(pp.x, pp.z).y
	var animals := {"wolf": w._add_wolf(pp, 981, false), "bear": w._add_wolf(pp + Vector3(6, 0, 0), 982, true), "deer": w._add_deer(pp + Vector3(-6, 0, 0), 983)}
	for k: String in animals:
		var a: Node3D = animals[k]
		a.set_process(false)
		var lows: Dictionary = a._lows
		var ok := lows.size() == 4
		for n in lows: ok = ok and lows[n] != null and (lows[n] as Node).get_parent() == a._legs[n]
		check(ok, "%s: four legs, each with a lower leg hung off it" % k)
		var fur := true
		for mi: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
			var sm := mi.material_override as ShaderMaterial
			fur = fur and sm != null and sm.shader.resource_path.ends_with("animal_fur.gdshader")
		check(fur, "%s: every part wears the fur material" % k)
		a.speed_now = 6.0
		var bent := 0.0
		for i in 40:
			a._animate(1.0 / 60.0)
			for n in lows: bent = maxf(bent, absf((lows[n] as Node3D).rotation.x))
		check(bent > 0.3, "%s: running folds the knees (max %.2f rad)" % [k, bent])
		a.speed_now = 0.0
		a._animate(1.0 / 60.0)
		var rest := 0.0
		for n in ["fl", "fr"]: rest = maxf(rest, absf((lows[n] as Node3D).rotation.x))
		check(rest < 0.05, "%s: standing, the forelegs are straight (%.2f)" % [k, rest])
	var claws: Node = animals["bear"].find_child("bear_claws_fl", true, false)
	check(claws != null and claws.get_parent() == animals["bear"]._lows["fl"], "bear claws ride on the paw")
	print("ANIMALS_X_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
