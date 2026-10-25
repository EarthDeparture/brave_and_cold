extends SceneTree
## Quiet-day work orders: data rules, real interactions in the built world,
## smoke bearing, end-of-shift report, carry-over, suspension, save/load,
## dev story jump and the pacing log.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for c: Node in n.get_children(): freeze(c)
func build(saved: Dictionary = {}) -> Node3D:
	SaveGame.pending = saved; seed(20261004)
	var w: Node3D = load("res://world/game_world.gd").new(); root.add_child(w)
	for f in 600:
		await process_frame
		if w.opening != null and w.opening.shift != null and w.collapse != null: break
	freeze(w); w.out_path = "test-no-autosave"; return w
func logged(sw: ShiftWork, needle: String) -> bool:
	for e: Array in sw.tasks.field_log:
		if String(e[2]).contains(needle): return true
	return false
func run() -> void:
	create_timer(170).timeout.connect(func() -> void: print("FAIL timeout"); quit(2))
	# ---- pure rules
	var t := ShiftTasks.new()
	check(t.order_for(1).size() == 5 and t.order_for(2).size() == 5 + 3, "day 1 lists five tasks; day 2 adds three unfinished day-1 check tasks")
	check(t.observe("weather", 1, 12.0, 100).is_empty() and not t.is_done("weather_d1"), "a reading outside its window does not count")
	check(t.observe("weather", 1, 8.0, 200).size() == 1 and t.is_done("weather_d1"), "a reading inside its window completes the task")
	check(t.observe("weather", 2, 8.0, 300).size() == 1 and t.is_done("weather_d2") and t.order_for(2).size() == 8, "windowed tasks never carry over; each day has its own")
	var latched := t.poll({"relay_inspect": func(_x: Dictionary) -> bool: return true}, 1, 400)
	check(latched.size() == 1 and t.poll({"relay_inspect": func(_x: Dictionary) -> bool: return false}, 1, 500).is_empty() and t.is_done("relay_inspect"), "check tasks latch once and stay done")
	var r := t.report(1)
	check(int(r.done) == 2 and int(r.total) == 5 and String(r.reply).contains("slow"), "two of five is reported as a slow day")
	check(t.report(1).is_empty(), "a day is reported once")
	var copy := ShiftTasks.new(); copy.restore(JSON.parse_string(JSON.stringify(t.to_dict())))
	check(copy.is_done("weather_d1") and copy.is_done("relay_inspect") and copy.reports.has("1"), "work order state survives JSON")
	# ---- real world
	var w: Node3D = await build(); var op: LookoutOpening = w.opening; var sw: ShiftWork = op.shift
	check(sw.station != null and sw.cups != null and sw.alidade != null, "deck weather station and fire finder are built from their assets")
	check(absf(sw.finder_pivot.global_rotation.y) < .001 and absf(w.fire_lookout.global_rotation.y) > .01, "fire-finder ring points true north even though the tower is yawed")
	op.advance(0)
	check(sw.tasks.announced_day == 1, "the day-one work order is announced at start")
	check(not w.story_skip_to(1, 5.0), "story jump never runs backwards")
	check(w.story_skip_to(1, 8.0) and w.clock.day == 1 and absf(w.clock.hour - 8.0) < .01, "story jump lands on the calendar beat")
	sw.take_readings()
	check(sw.tasks.is_done("weather_d1") and logged(sw,"°C"), "taking readings logs real weather and completes the morning task")
	if w.inv.count("service_kit") < 1: w.inv.add("service_kit")
	op.inspect_relay(); op.advance(0)
	check(sw.tasks.is_done("relay_inspect"), "the existing cabinet inspection completes its work-order line")
	sw.sight()
	check(not sw.tasks.is_done("smoke_d1") and String(sw.tasks.field_log[-1][2]).contains("clear"), "a morning sighting is logged but outside the smoke-check window")
	w.story_skip_to(1, 15.0); sw._process(.1)
	check(sw.smoke != null and sw.smoke.emitting, "Mara's slash-burn smoke rises during the afternoon")
	var tower := Vector2(w.fire_lookout.global_position.x, w.fire_lookout.global_position.z)
	var dist := Vector2(sw.smoke_point.x, sw.smoke_point.z).distance_to(tower)
	check(dist > 450 and dist < 1400, "smoke column is a believable distance from the tower (%.0f m)" % dist)
	sw.sight()
	var d := sw.smoke_point - sw.finder_pivot.global_position
	var expected := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360)
	check(sw.tasks.is_done("smoke_d1") and absf(sw.alidade_deg - expected) < .01 and logged(sw,"bearing %03d°" % roundi(expected)), "fire finder reports the true bearing and swings the alidade to it")
	for i in 120: sw._process(.05)
	check(absf(angle_difference(sw.alidade.rotation.y, -deg_to_rad(expected))) < .02, "alidade visibly settles on the sighted bearing")
	w.story_skip_to(1, 19.6)
	var rep: Dictionary = sw.tasks.reports.get("1", {})
	check(int(rep.get("done", -1)) == 3 and int(rep.get("total", -1)) == 5 and String(rep.get("reply", "")).contains("Most"), "evening report counts the real day: 3 of 5")
	check(sw.next_task_title() == "Collect the reserved relay at North Ridge Supply", "next task is the first open line")
	check(op.field_plan_text().contains("Work order: 3 of 5 done"), "field plan on the desk shows work-order progress")
	w.story_skip_to(2, 7.0)
	check(sw.progress() == Vector2i(0, 7) and sw.order_text().contains("carried over"), "day two carries the unfinished check tasks")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free(); await process_frame; await process_frame
	w = await build(saved); op = w.opening; sw = op.shift
	check(sw.tasks.is_done("smoke_d1") and sw.tasks.reports.has("1") and absf(sw.alidade_deg - expected) < .01 and sw.tasks.announced_day == 2, "work order, field log and alidade survive a full reload")
	w.story_skip_to(3, 8.5)
	check(sw.order_text().begins_with("*** SUSPENDED") and sw.next_task_title().begins_with("Suspended") and sw.tasks.suspend_noted, "day three 08:00 suspends the work order")
	check(sw.tasks.reports.has("2"), "a slept-through evening still files its report")
	# ---- pacing log
	var pl := PacingLog.new(); w.add_child(pl); pl.start(w,"res://shots/town-life/pacing-test")
	w.interaction_count += 2; pl._process(.5); pl._write()
	var lines := FileAccess.get_file_as_string(pl.path).strip_edges().split("\n")
	check(lines.size() == 2 and lines[1].split(",").size() == 12 and lines[1].split(",")[8] == "2", "pacing log writes one CSV row with the interaction count")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pl.path))
	w.queue_free(); await process_frame; await process_frame; SaveGame.pending = {}
	print("SHIFT_WORK_TEST checks=", checks, " failures=", failures); quit(1 if failures else 0)
