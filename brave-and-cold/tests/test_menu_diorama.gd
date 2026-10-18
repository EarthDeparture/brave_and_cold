extends SceneTree
## M6 live menu: the bake exists, is complete, and is current. It FAILS when the forest,
## the maps or the lookout changed since the bake (e.g. after the canopy pass) — re-bake:
##   godot --path brave-and-cold --script res://tests/visual/bake_menu_diorama.gd   (not headless)
var fails := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print(("PASS " if ok else "FAIL ") + label)

func run() -> void:
	check(MenuDiorama.available(), "diorama bake present (data/menu/diorama.bin)")
	var fa := FileAccess.open(MenuDiorama.BAKE, FileAccess.READ)
	var d: Dictionary = fa.get_var(false) if fa != null else {}
	check(int(d.get("tree_count", 0)) > 10000, "bake holds the game's trees around the lookout (%d)" % int(d.get("tree_count", 0)))
	check(d.get("lookout_xform") is Transform3D and d.get("eye") is Vector3 and d.get("target") is Vector3, "lookout placement and camera shot baked")
	var baked_inputs: Dictionary = d.get("inputs", {})
	var stale: Array = []
	var script := load("res://tests/visual/bake_menu_diorama.gd")
	var now: Dictionary = script.input_hashes()
	for k in now:
		if String(baked_inputs.get(k, "")) != String(now[k]): stale.append(k)
	check(stale.is_empty(), "bake is current (changed since bake: %s)" % str(stale))
	# the game's default forest profile is what was baked
	check(bool(d.get("detail", false)) and bool(d.get("crowns", false)) and bool(d.get("diversity", false)), "baked with the game's default forest profile")
	# headless never builds the live scene (no GPU); the menu must fall back to stills
	var m: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i in 5: await process_frame
	check(not m._live_allowed(), "headless menu keeps the painted stills")
	print("MENU_DIORAMA_TEST checks=%d failures=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)
