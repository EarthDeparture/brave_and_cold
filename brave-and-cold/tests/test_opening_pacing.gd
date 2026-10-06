extends SceneTree
## New-run pace, migrated saves, stage-specific guidance and silent time skips.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func build(saved: Dictionary = {}) -> Node3D:
	SaveGame.pending = saved
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening != null and w.reading != null and w.gear != null: break
	freeze(w); w.out_path = "test-no-autosave"
	return w
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(2))
	var clock := GameClock.new(); clock.set_pace(GameClock.OPENING_TIME_SCALE)
	clock.hour = 5.5; clock.advance(600)
	check(is_equal_approx(clock.hour, 10.5), "ten awake minutes consume five game hours")
	clock.time_scale = 4320
	var restored := GameClock.new(); restored.restore(clock.to_dict())
	check(restored.time_scale == 30 and restored.base_time_scale == 30, "saved awake rate never inherits accelerated sleep rate")
	restored.restore({"hour": 12.25, "day": 3, "total": 200000})
	check(restored.time_scale == 48 and restored.hour == 12.25 and restored.total_game_s == 200000, "legacy clock keeps its pace and calendar")
	var w: Node3D = await build(); var op: LookoutOpening = w.opening
	check(w.clock.base_time_scale == 30 and op.state.audio_clock_rate == 30, "new lookout run and radio share the 48-minute-day pace")
	check(op.fuel_s > 7.9*3600 and op.wood_left == 6 and w.inv.count("wood") == 2, "new shift has eight hours of heat without extra loose logs")
	var fuel: float = op.fuel_s; var gs: float = w.clock.advance(600); op.advance(gs)
	check(is_equal_approx(fuel-op.fuel_s, 5*3600) and op.fuel_s > 0, "initial stove survives ten real minutes of unattended burn")
	var expected_tasks: Array[String] = ["Inspect the ground transfer cabinet", "Collect the reserved transfer relay", "Verify the cabinet transfer", "Relay signed off"]
	for stage in 4:
		op.state.repair_stage = stage; op.state.parts_claimed = false; op.read_log()
		var text: String = w.reading._body.text
		check(text.contains(expected_tasks[stage]) and text.contains("bearing") and text.contains("water above 45%,") and not text.contains("%s"), "service log stage %d has real directions, task and percentages" % stage)
		w.reading.close()
	op.state.repair_stage = 1; op.state.parts_claimed = true; op.read_log()
	check(w.reading._body.text.contains("Return to the ground cabinet and install"), "collected relay changes current guidance")
	w.reading.close()
	for entry: Dictionary in op.state.broadcasts:
		var duration: float = float(op.state.audio_clips[String(entry.audio).get_file()].seconds)
		check(duration*op.state.audio_clock_rate <= float(entry.window_game_s), "speech fits reserved window " + String(entry.id))
	var entry: Dictionary = op.state.broadcasts.filter(func(e: Dictionary) -> bool: return e.id == "public_d1_12")[0]
	var start: float = op.state.entry_start(entry)
	op.state.walkie_carried = true; op.state.walkie_wh = 12; op.state.receiver_on = false
	op.state.last_s = start+60; w.player.position += Vector3(250,0,0); op._radio_update()
	check(op.walkie.playing and absf(op.walkie.get_playback_position()-2)<.2, "late tuning at slower pace still seeks two spoken seconds")
	op.state.last_s = start+float(op.state.audio_clips[String(entry.audio).get_file()].seconds)*30+1; op._radio_update()
	check(not op.walkie.playing and op.next_dispatch_wake(start+1800, start+1801) == INF, "ended speech stays ended after a calendar skip")
	op.state.last_s = w.clock.total_game_s; op.state.walkie_carried = false
	op.fuel_s = 3600; w.clock.time_scale = w.clock.base_time_scale
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	var deadlines: Array = [op.state.grid_fail_s, op.state.source_end_s]
	w.queue_free(); await process_frame; await process_frame; w = await build(snapshot)
	check(w.clock.time_scale == 30 and w.opening.state.audio_clock_rate == 30, "fresh restoration resumes candidate pace and radio mapping")
	var loaded_burn: float = w.clock.total_game_s-float(snapshot.clock.total)
	check(absf(w.opening.fuel_s-maxf(0,3600-loaded_burn))<.01 and is_equal_approx(w.opening.state.grid_fail_s,deadlines[0]) and is_equal_approx(w.opening.state.source_end_s,deadlines[1]), "restoration burns only elapsed time and never refills stove or rerolls deadlines")
	# Evening fixture: return with finite pack/rack stock, prepare, then use the
	# real accelerated sleep/world loop. This is not an uninterrupted day-one run.
	w._frames=100;op=w.opening
	w.clock.day=1;w.clock.hour=21;w.clock.total_game_s=15.5*3600
	op.state.last_s=w.clock.total_game_s;op.state.walkie_carried=false
	w.player.position=w.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+w.player.eye_h,.3))
	w.player.activity=0;w.body.core=37;w.needs.calories=1112;w.needs.water=57;w.needs.fatigue=50
	op.fuel_s=3*3600
	var rack_before:int=op.wood_left
	w.inv.use("beans");w.inv.use("clean_water")
	op.stoke();op.stoke();op.take_wood();op.stoke();op.take_wood();op.stoke()
	check(op.wood_left==rack_before-2 and w.inv.count("wood")==0 and w.inv.count("beans")==0 and w.inv.count("clean_water")==1, "overnight preparation consumes real food, water and four finite logs")
	var rest_start:float=w.clock.total_game_s
	w._sleep_begin(w.fire_lookout,8);w._sleep_update(w.SLEEP_FADE)
	for step in 260:
		w._process(.1)
		if int(w._sl.phase)==2:break
	check(w.sleep_last=="You wake rested" and absf(w.clock.total_game_s-rest_start-8*3600)<5 and w.clock.time_scale==30, "prepared eight-hour night completes and restores candidate awake pace")
	check(not w.player.dead and w.body.core>36.5 and w.needs.calories>900 and w.needs.water>45 and w.needs.fatigue<5 and op.fuel_s>2.9*3600, "warm fed hydrated rest succeeds with finite starting reserves")
	w._sl_on=false;w.player.sleeping=false
	w.queue_free(); await process_frame; await process_frame
	snapshot.clock.erase("base_time_scale"); snapshot.clock.erase("pace_schema")
	w = await build(snapshot)
	check(w.clock.time_scale==48 and w.opening.state.audio_clock_rate==48, "pre-upgrade save preserves 30-minute days and original radio pace")
	loaded_burn = w.clock.total_game_s-float(snapshot.clock.total)
	check(absf(w.opening.fuel_s-maxf(0,3600-loaded_burn))<.01 and w.opening.wood_left==6, "legacy migration preserves remaining heat and finite stock")
	w.queue_free(); await process_frame; await process_frame; SaveGame.pending={}
	print("OPENING_PACING_TEST checks=",checks," failures=",failures); quit(1 if failures else 0)
