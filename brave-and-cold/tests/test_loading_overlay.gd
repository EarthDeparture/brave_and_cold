extends SceneTree
## M5: New Game from the menu hands the loading look to a root overlay, the world reports
## ordered build stages to it, and it fades out and frees itself once the world is ready.
var fails := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print(("PASS " if ok else "FAIL ") + label)

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	root.size = Vector2i(1152, 648)
	var m: Control = (load("res://ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(m); current_scene = m
	for i in 5: await process_frame
	m._new_game_now()
	var ov: LoadingOverlay = null
	for i in 20:
		await process_frame
		if LoadingOverlay.current != null: ov = LoadingOverlay.current; break
	check(ov != null and ov.get_parent() == root, "overlay lives on the root, outside the menu scene")
	check(ov != null and ov.find_children("*", "CPUParticles2D", true, false).size() == 2, "menu snow carried over")
	var w: Node = null
	for i in 3000:
		await process_frame
		if w == null and current_scene != null and current_scene != m and is_instance_valid(current_scene): w = current_scene
		if w != null and bool(w.get("built")): break
	check(w != null and bool(w.get("built")), "world finished building under the overlay")
	var st: Array = LoadingOverlay.log_stages
	var ordered := st.size() >= 8
	for i in range(1, st.size()):
		if float(st[i][1]) < float(st[i - 1][1]): ordered = false
	check(ordered, "stages reported in order (%d): %s" % [st.size(), str(st.map(func(e: Array) -> String: return "%s@%.2f" % [e[0], e[1]]))])
	check(st.size() > 0 and is_equal_approx(float(st[-1][1]), 1.0), "last stage is 100%")
	var max_jump := 0.0
	var max_gap_ms := 0
	var gap_at := ""
	for i in range(1, st.size()):
		max_jump = maxf(max_jump, float(st[i][1]) - float(st[i - 1][1]))
		var g := int(st[i][2]) - int(st[i - 1][2])
		if g > max_gap_ms: max_gap_ms = g; gap_at = "%s@%.2f -> %s@%.2f" % [st[i - 1][0], st[i - 1][1], st[i][0], st[i][1]]
	check(max_jump <= 0.15, "no bar jump over 15%% (max %.2f)" % max_jump)
	# Headless is faster than a real GPU run, but the forest must not be one silent block again.
	check(max_gap_ms <= 1800, "no silent build block over 1.8 s (max %d ms: %s)" % [max_gap_ms, gap_at])
	for i in 240:
		await process_frame
		if not is_instance_valid(ov): break
	check(not is_instance_valid(ov) and LoadingOverlay.current == null, "overlay fades out and frees itself after ready")
	check(w != null and (w.get("terrain") as Node).is_physics_processing(), "terrain physics resumed after the staged build")
	print("LOADING_OVERLAY_TEST checks=%d failures=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)
