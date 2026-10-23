extends SceneTree
## Plan A0: the dev sound board lists and loads every ambient / weapon clip, plays near and far the way the game
## does (direction + distance level), runs the layered scenes, and saves verdicts.
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
	create_timer(200).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	SaveGame.pending = {}; seed(3)
	w = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.hud != null and w.pop != null: break
	w.out_path = ""
	var n := 0
	for d in SoundBoard.DIRS:
		for f in DirAccess.open(d).get_files():
			if f.ends_with(".wav.import"): n += 1
	var clips := SoundBoard.list_clips()
	check(clips.size() == n and n > 40, "every clip is listed (%d of %d)" % [clips.size(), n])
	var bad := 0
	for c in clips:
		if not (load(c) is AudioStream): bad += 1
	check(bad == 0, "every clip loads")
	var sb := SoundBoard.new(); root.add_child(sb); sb.setup(w)
	await frames(2)
	check(sb._list.get_child_count() == clips.size(), "one row per clip")
	var amb := "res://assets/audio/ambient/howl_far_0.wav"
	var cam: Node3D = w.player.cam
	var fwd: Vector3 = -cam.global_basis.z; fwd.y = 0; fwd = fwd.normalized()
	sb._set_dir("front")
	var p: AudioStreamPlayer3D = sb.play_far(amb, 800.0)
	var to: Vector3 = p.global_position - cam.global_position; to.y = 0
	check(absf(to.length() - 100.0) < 1.0 and to.normalized().dot(fwd) > 0.99, "far play sits 100 m out in front")
	check(absf(p.volume_db - (-3.0 - 18.06)) < 0.2, "level follows the real distance (800 m: %.1f dB)" % p.volume_db)
	sb._set_dir("left")
	p = sb.play_far(amb, 300.0)
	to = p.global_position - cam.global_position; to.y = 0
	check(to.normalized().dot(fwd) < 0.05 and to.normalized().dot(fwd.rotated(Vector3.UP, PI / 2)) > 0.99, "direction buttons move the source (left)")
	var gp: AudioStreamPlayer3D = sb.play_far("res://assets/audio/weapons/" + _first_weapon(clips), 800.0)
	check(gp.attenuation_filter_cutoff_hz < 2000.0, "a dry weapon clip played far is low-passed (%.0f Hz)" % gp.attenuation_filter_cutoff_hz)
	var np := sb.play_near(amb)
	check(np.playing, "near play")
	var al = w.ambient_life
	al.heard.clear(); sb.scene("howl")
	check(al.heard.size() >= 1 and al.heard[0].kind == "howl", "scene: howl chorus")
	al.heard.clear(); sb.scene("owl")
	check(al.heard.size() >= 1 and al.heard[0].kind == "owl", "scene: owl")
	sb.scene("static")
	check(al.force_aurora == 1.0 and w.opening.state.receiver_on, "scene: aurora static on")
	sb.scene("static")
	check(al.force_aurora < 0.0, "and off")
	sb.set_verdict("howl_far_0", "replace"); sb.set_note("howl_far_0", "too clean")
	var sb2 := SoundBoard.new(); root.add_child(sb2); sb2.setup(w)
	check(String(sb2.review.get("howl_far_0", {}).get("verdict", "")) == "replace" and String(sb2.review["howl_far_0"].note) == "too clean", "verdicts and notes are saved and reload")
	sb2.set_verdict("howl_far_0", "replace")   # toggles back off so the test leaves the review clean
	sb2.set_note("howl_far_0", "")
	var dm = w.get("dev")
	if dm != null:
		check(dm.get("sound_board") != null, "the dev menu carries the sound board")
	w.queue_free(); await process_frame; await process_frame
	print("SOUND_BOARD_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)

func _first_weapon(clips: Array[String]) -> String:
	for c in clips:
		if c.contains("/weapons/"): return c.get_file()
	return ""
