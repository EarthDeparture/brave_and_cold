class_name ShiftWork
extends Node3D
## The lookout technician's daily work on the quiet days: a rail-mounted deck
## weather station, a rail-mounted fire finder that swings to a sighted bearing,
## one seeded smoke column (Mara's slash burn), the desk work order and the
## end-of-shift report. Rules and text: data/shift_tasks.json via ShiftTasks.
const STATION := "res://assets/shift_work/weather_station.glb"
const FINDER := "res://assets/shift_work/fire_finder.glb"
const FINDER_CENTER := Vector3(-1.85, 1.24, 3.33) # deck-relative, tower local (front rail post)
const READ_POINT := Vector3(-3.45, 1.25, -1.0)     # deck side of the west-rail instrument screen
const BINDER := Vector3(.92, .91, -1.14)           # service binder on the desk
var op: LookoutOpening
var world: Node3D
var tasks := ShiftTasks.new()
var station: Node3D
var cups: Node3D
var finder_pivot: Node3D
var alidade: Node3D
var smoke: GPUParticles3D
var smoke_point := Vector3.INF
var alidade_deg := 0.0
var _checks: Dictionary = {}
var _wind_t := 0.0

func build(opening: LookoutOpening, saved: Dictionary) -> void:
	op = opening; world = op.world; name = "ShiftWork"
	var tower: FireLookout = world.fire_lookout
	tower.add_child(self)
	tasks.restore(saved)
	station = (load(STATION) as PackedScene).instantiate() as Node3D
	add_child(station); station.position.y = FireLookout.DECK_Y
	cups = station.find_child("AnemometerCups", true, false) as Node3D
	finder_pivot = Node3D.new(); finder_pivot.name = "FireFinderPivot"; add_child(finder_pivot)
	finder_pivot.position = FINDER_CENTER + Vector3.UP * FireLookout.DECK_Y
	var finder := (load(FINDER) as PackedScene).instantiate() as Node3D
	finder_pivot.add_child(finder); finder.position = -FINDER_CENTER
	# Printed 0 deg must face true north (world -Z), not the tower's yawed -Z.
	finder_pivot.global_rotation = Vector3.ZERO
	alidade = finder.find_child("Alidade", true, false) as Node3D
	alidade_deg = float(saved.get("alidade_deg", 0.0))
	if alidade != null: alidade.rotation.y = -deg_to_rad(alidade_deg)
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false): mesh.visibility_range_end = 140.0
	_checks = {
		"relay_inspect": func(_t: Dictionary) -> bool: return op.state.repair_stage >= 1,
		"relay_collect": func(_t: Dictionary) -> bool: return op.state.parts_claimed,
		"relay_install": func(_t: Dictionary) -> bool: return op.state.repair_stage >= 2,
		"relay_verify": func(_t: Dictionary) -> bool: return op.state.repair_stage >= 3,
		"feeder": func(_t: Dictionary) -> bool: return world.first_week != null and world.first_week.feeder_isolated,
		"woodbox": func(t: Dictionary) -> bool: return op.wood_left >= int(t.get("target", 8)),
	}
	# Older saves had no work order: latch what is already true silently, no message burst.
	if not saved.has("done"): tasks.poll(_checks, world.clock.day, world.clock.total_game_s)
	_build_smoke()

func stamp() -> String: return world.clock.time_string()

## Called from LookoutOpening.advance every frame (cheap: <= ten tasks).
func update() -> void:
	if not op.state.enabled: return
	var day: int = world.clock.day; var hour: float = world.clock.hour; var now: float = world.clock.total_game_s
	# Reports first: a slept-through evening (or a jump past the suspension) still files them.
	var report_hour := float(tasks.data.get("report_hour", 19.5))
	for d in range(1, mini(day, tasks.last_day()) + 1):
		if (d < day or hour >= report_hour) and not tasks.reports.has(str(d)):
			var r := tasks.report(d)
			var line := "Shift report radioed • %s • %d of %d complete. %s" % [tasks.day_name(d), r.done, r.total, r.reply]
			tasks.add_log(now, stamp(), line); world._say(line)
	if now >= tasks.suspended_at(op.state):
		if not tasks.suspend_noted:
			tasks.suspend_noted = true
			tasks.add_log(now, stamp(), "Dispatch: work order SUSPENDED. Stay at your post.")
			world._say("Work order suspended by dispatch • stay at your post")
		return
	if day <= tasks.last_day() and day > tasks.announced_day and hour >= 5.5:
		tasks.announced_day = day
		world._say("%s work order on the desk • %d tasks" % [tasks.day_name(day), tasks.order_for(day).size()])
	for t: Dictionary in tasks.poll(_checks, day, now): _completed(t)

func _completed(t: Dictionary) -> void:
	tasks.add_log(world.clock.total_game_s, stamp(), "Done: " + String(t.title))
	world._say("Work order • done: " + String(t.title))

func progress() -> Vector2i:
	var order := tasks.order_for(world.clock.day)
	var n := 0
	for t: Dictionary in order:
		if tasks.is_done(String(t.id)): n += 1
	return Vector2i(n, order.size())

func next_task_title() -> String:
	if world.clock.total_game_s >= tasks.suspended_at(op.state): return "Suspended by dispatch — stay at your post."
	for t: Dictionary in tasks.order_for(world.clock.day):
		if not tasks.is_done(String(t.id)): return String(t.title)
	return "All listed work complete."

func actions() -> Array:
	var tower: FireLookout = world.fire_lookout
	var out: Array = []
	var p := progress()
	var suspended: bool = world.clock.total_game_s >= tasks.suspended_at(op.state)
	out.append(op._action(tower.to_global(BINDER + Vector3.UP * FireLookout.DECK_Y), "Read work order • " + ("suspended" if suspended else "%d/%d done" % [p.x, p.y]), read_order, 0, .02))
	out.append(op._action(tower.to_global(READ_POINT + Vector3.UP * FireLookout.DECK_Y), "Take weather readings", take_readings, 4))
	out.append(op._action(finder_pivot.global_position + Vector3.UP * .06, "Sight the horizon • fire finder", sight, 3))
	return out

static func compass(deg: float) -> String:
	return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][int(round(fposmod(deg, 360) / 45.0)) % 8]

func take_readings() -> void:
	var w = world.weather
	var from: Vector2 = -w.wind_dir
	var from_deg := fposmod(rad_to_deg(atan2(from.x, -from.y)), 360)
	var sky: String = w.state_name().to_lower()
	var text := "Weather %s: air %.0f °C, wind %s %d km/h, %s%s." % [stamp(), world.clock.ambient_c(), compass(from_deg), roundi(w.wind * 3.6), sky, ", fresh snow in the gauge" if w.precip > .15 else ""]
	_observe("weather", text)

func sight() -> void:
	var s := tasks.smoke_today(world.clock.day, world.clock.hour)
	var text := "Fire finder %s: horizon clear on all bearings." % stamp()
	if not s.is_empty() and smoke_point.is_finite():
		var d := smoke_point - finder_pivot.global_position
		var bearing := fposmod(rad_to_deg(atan2(d.x, -d.z)), 360)
		alidade_deg = bearing
		text = "Fire finder %s: smoke column on bearing %03d°, about %.1f km. Reported. %s" % [stamp(), roundi(bearing), Vector2(d.x, d.z).length() / 1000.0, String(s.get("reply", ""))]
	_observe("smoke", text)

func _observe(kind: String, text: String) -> void:
	var now: float = world.clock.total_game_s
	tasks.add_log(now, stamp(), text)
	world._say(text)
	for t: Dictionary in tasks.observe(kind, world.clock.day, world.clock.hour, now): _completed(t)

func read_order() -> void:
	world.reading.open("Kestrel 07 • work order", order_text(), world.player, world.hud)

func order_text() -> String:
	var day: int = world.clock.day
	var out := ""
	if world.clock.total_game_s >= tasks.suspended_at(op.state):
		out += "*** SUSPENDED BY DISPATCH — STAY AT YOUR POST. — J.M. ***\n\n"
	out += "WORK ORDER — %s (day %d)\n\n" % [tasks.day_name(day), day]
	var order := tasks.order_for(day)
	if order.is_empty(): out += "No scheduled work.\n"
	for t: Dictionary in order:
		var mark := "[x]" if tasks.is_done(String(t.id)) else "[  ]"
		var when := ""
		if t.has("window"): when = " (%s–%s)" % [_hm(float(t.window[0])), _hm(float(t.window[1]))]
		out += "%s %s%s%s\n      %s\n" % [mark, String(t.title), when, "  • carried over" if t.get("carried", false) else "", String(t.detail)]
	if not tasks.reports.is_empty():
		out += "\nSHIFT REPORTS\n"
		for k: String in tasks.reports.keys():
			var r: Dictionary = tasks.reports[k]
			out += "%s: %d of %d complete. %s\n" % [tasks.day_name(int(k)), int(r.done), int(r.total), String(r.reply)]
	if not tasks.field_log.is_empty():
		out += "\nFIELD LOG\n"
		for entry: Array in tasks.field_log.slice(maxi(0, tasks.field_log.size() - 12)):
			out += "%s  %s\n" % [String(entry[1]), String(entry[2])]
	out += "\nReadings: deck station on the west rail. Smoke checks: fire finder on the front rail; its zero mark points true north."
	return out

static func _hm(h: float) -> String:
	return "%02d:%02d" % [int(h), int(round(fposmod(h, 1.0) * 60))]

func _build_smoke() -> void:
	if world.road == null or world.road.points.is_empty(): return
	var t := Vector2(world.fire_lookout.global_position.x, world.fire_lookout.global_position.z)
	var store := Vector2.INF
	if not world.stores.is_empty(): store = Vector2(world.stores[0].global_position.x, world.stores[0].global_position.z)
	var best := Vector2.INF; var score := INF
	for p: Vector2 in world.road.points:
		var d := p.distance_to(t)
		if d < 500 or d > 1300 or (store.is_finite() and p.distance_to(store) < 300): continue
		if absf(d - 900) < score: score = absf(d - 900); best = p
	if not best.is_finite(): return
	var away := (best - t).normalized() * 28.0 # slash pile just off the road edge
	smoke_point = world._ground(best.x + away.x, best.y + away.y)
	smoke = GPUParticles3D.new(); smoke.name = "SlashBurnSmoke"; world.add_child(smoke); smoke.global_position = smoke_point
	smoke.amount = 72; smoke.lifetime = 40.0; smoke.preprocess = 40.0; smoke.emitting = false
	smoke.visibility_aabb = AABB(Vector3(-120, -5, -120), Vector3(240, 220, 240))
	var pm := ParticleProcessMaterial.new(); pm.direction = Vector3.UP; pm.spread = 7.0
	pm.initial_velocity_min = 2.4; pm.initial_velocity_max = 3.2; pm.scale_min = 20.0; pm.scale_max = 32.0
	pm.gravity = Vector3(0, .15, 0) # default is -9.8: smoke must never fall
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 2.5
	var grow := Curve.new(); grow.max_value = 3.0; grow.add_point(Vector2(0, .4)); grow.add_point(Vector2(1, 3.0)) # spreads as it rises
	var grow_tex := CurveTexture.new(); grow_tex.curve = grow; pm.scale_curve = grow_tex
	smoke.process_material = pm
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	var mat := ShaderMaterial.new(); mat.shader = preload("res://world/shaders/winter_vapour.gdshader")
	mat.set_shader_parameter("tint", Vector3(.30, .30, .29)); mat.set_shader_parameter("opacity", .8); quad.material = mat
	smoke.draw_pass_1 = quad

func _process(delta: float) -> void:
	if world == null: return
	var w = world.weather
	if cups != null: cups.rotate_y(-delta * clampf(float(w.wind) * 1.6, .4, 30.0))
	if alidade != null: alidade.rotation.y = lerp_angle(alidade.rotation.y, -deg_to_rad(alidade_deg), minf(1.0, delta * 2.5))
	if smoke != null:
		var burning := not tasks.smoke_today(world.clock.day, world.clock.hour).is_empty()
		if burning and not smoke.emitting:
			smoke.emitting = true; smoke.restart() # preprocess: an established column, not a puff
		elif not burning: smoke.emitting = false
		_wind_t -= delta
		if _wind_t <= 0.0:
			_wind_t = 2.0
			# Gravity is an acceleration: a gentle lean, not a 1 km smear over a 30 s particle life.
			var drift: Vector2 = w.wind_dir * clampf(float(w.wind) * .025, 0.0, .3)
			(smoke.process_material as ParticleProcessMaterial).gravity = Vector3(drift.x, .15, drift.y)

func to_dict() -> Dictionary:
	var d := tasks.to_dict(); d["alidade_deg"] = alidade_deg; return d
