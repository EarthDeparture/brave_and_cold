class_name AmbientLife
extends Node3D
## Alive L1: signs of life that carry information (the TLD way - signs, not crowds).
##  * Ravens circle over every carcass / body within 300 m - visible from far, they mark a kill. With nobody near
##    for a while they land and peck; the player closing in, or a shot / loud noise near them, scatters them with
##    calls and wingbeats. They roost at night. Daytime flyovers of 1-3 birds.
##  * Aurora: about one clear night in four (deterministic per night), late evening to pre-dawn. Drawn in the sky
##    shader (AtmosphereRig.aurora) and tints the moonlight / ambient a little green.
##  * Distant voices: wolf howls at night come FROM where real packs are (a lead and 1-2 answers), owls at dusk and
##    in the night, a raven's call by day. None while a wolf is hunting you close by.
## One MultiMesh per flock (1 draw call); wings flap / fold in the vertex shader.

const AMB := "res://assets/audio/ambient/"
const FLOCK_R := 300.0
const LEAVE_R := 360.0
const MAX_FLOCKS := 3
const SCARE_R := 25.0          # player this close to a landed flock -> up they go
const LAND_CLEAR_R := 45.0     # nobody within this for QUIET_S -> they come down
const QUIET_S := 40.0
const MIN_AGE_S := 240.0       # game seconds before the first birds find a kill
const ROOST_NIGHT := 0.7
const PERCH_Y := 0.16          # body centre over the snow when standing

const BIRD_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 albedo : source_color = vec3(0.022, 0.022, 0.028);
void vertex() {
	vec4 c = INSTANCE_CUSTOM;            // x phase, y flap amount, z wing fold, w peck
	float side = COLOR.g * 2.0 - 1.0;
	if (COLOR.b > 0.5) {
		float span = COLOR.r;
		float a = sin(TIME * 20.0 + c.x) * 0.95 * c.y + 0.10 * (1.0 - c.z);   // ~3.2 Hz wingbeat, glide dihedral
		a *= 1.0 + 0.7 * smoothstep(0.45, 1.0, span);                      // the hand bends more than the arm
		float ad = abs(VERTEX.x - side * 0.05) * mix(1.0, 0.075, c.z);
		VERTEX.z += c.z * span * 0.16;
		VERTEX.x = side * 0.05 + side * ad * cos(a);
		VERTEX.y += ad * sin(a) + c.z * 0.045;
		NORMAL = normalize(vec3(-side * sin(a), cos(a), 0.0));
	}
	if (COLOR.b > 0.25 && COLOR.b < 0.75) { VERTEX.y = mix(-0.05, VERTEX.y, c.z); }   // legs: tucked in flight
	if (COLOR.a > 0.5) { VERTEX.y -= c.w * 0.10; VERTEX.z -= c.w * 0.03; }
}
void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 0.45;
	SPECULAR = 0.35;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
"""

var world: Node
var flocks: Array = []
var aurora := 0.0
var force_aurora := -1.0       # tests / captures: >= 0 overrides the schedule
var voices_enabled := true
var heard: Array = []          # [{kind, pos, dist, real}] last voices played (tests / debug)
var rng := RandomNumberGenerator.new()
var _mesh: ArrayMesh
var _mat: ShaderMaterial
var _streams: Dictionary = {}
var _pending: Array = []       # [time_s, name, pos, db, dist]
var _t := 0.0
var _scan_t := 0.0
var _howl_t := 90.0
var _owl_t := 45.0
var _call_t := 80.0
var _fly_t := 120.0


func setup(w: Node) -> void:
	world = w
	rng.seed = 90210
	_mesh = bird_mesh()
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BIRD_SHADER
	_mat.shader = sh
	var nb = w.get("noise_bus")
	if nb != null:
		(nb as NoiseBus).noise.connect(_on_noise)


# ------------------------------------------------------------------ aurora schedule
static func aurora_night(d: int) -> bool:
	return posmod(hash(d * 7919 + 31), 4) == 0


func aurora_target() -> float:
	if force_aurora >= 0.0:
		return force_aurora
	var clock: GameClock = world.get("clock")
	var weather: Weather = world.get("weather")
	if clock == null:
		return 0.0
	var h := clock.hour
	var nd := clock.day if h >= 12.0 else clock.day - 1
	if not aurora_night(nd):
		return 0.0
	var win := smoothstep(20.0, 22.5, h) if h >= 12.0 else 1.0 - smoothstep(3.0, 5.5, h)
	var clear := 1.0
	if weather != null:
		clear = (1.0 - smoothstep(0.12, 0.4, weather.overcast)) * (1.0 - smoothstep(0.05, 0.3, weather.precip))
	return win * clear


## Darkness from the sun's elevation (same sun path as AtmosphereRig): 0 day .. 1 full night. The legacy
## gameplay_night_factor peaks at dusk (~0.8) and sits ~0.64 at midnight, so it can't gate roosting / voices.
func _night() -> float:
	var clock: GameClock = world.get("clock")
	if clock == null:
		return 0.0
	var elev := sin(PI * (fposmod(clock.hour, 24.0) - 6.0) / 12.0) * 42.0
	return 1.0 - smoothstep(-6.0, 4.0, elev)


func _player_pos() -> Vector3:
	var p = world.get("player")
	return (p as Node3D).global_position if p != null else Vector3.ZERO


func _ground(x: float, z: float) -> float:
	return float(world.call("_ground_y", x, z)) if world.has_method("_ground_y") else 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	var target := aurora_target()
	aurora = move_toward(aurora, target, delta * (4.0 if force_aurora >= 0.0 else 1.0 / 60.0))
	var sr = world.get("sky_rig")
	if sr is AtmosphereRig:
		(sr as AtmosphereRig).aurora = aurora
		(sr as AtmosphereRig).material.set_shader_parameter("aurora_time", _t)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 2.0
		_scan()
	for f in flocks.duplicate():
		_update_flock(f, delta)
	if voices_enabled:
		_voices(delta)
	_flush_pending()


# ------------------------------------------------------------------ flocks
func _bodies() -> Array:
	var out: Array = []
	for g in ["carcasses", "bodies"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and not n.is_queued_for_deletion():
				out.append(n)
	return out


func _scan() -> void:
	var pp := _player_pos()
	for f in flocks.duplicate():   # out of range -> gone (out of sight)
		if f.kind == "kill" and Vector2(f.center.x - pp.x, f.center.z - pp.z).length() > LEAVE_R:
			_free_flock(f)
	if _night() > ROOST_NIGHT:
		return
	var tracked := {}
	for f in flocks:
		if f.kind == "kill" and is_instance_valid(f.target):
			tracked[f.target.get_instance_id()] = true
	var cands: Array = []
	for n: Node3D in _bodies():
		if tracked.has(n.get_instance_id()):
			continue
		if Carcass.age_s(n) < MIN_AGE_S and n.is_in_group("carcasses"):
			continue
		var d := Vector2(n.global_position.x - pp.x, n.global_position.z - pp.z).length()
		if d > FLOCK_R:
			continue
		if world.has_method("room_at") and world.call("room_at", n.global_position) != null:
			continue   # indoors: no birds
		cands.append([0 if n.is_in_group("carcasses") else 1, d, n])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var kills := 0
	for f in flocks:
		if f.kind == "kill": kills += 1
	for c in cands:
		if kills >= MAX_FLOCKS:
			break
		_new_kill_flock(c[2])
		kills += 1


func _make_mm(n: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi


func _new_kill_flock(n: Node3D) -> Dictionary:
	var h := absi(hash(n.get_instance_id()))
	var count := 3 + h % 5
	var c := n.global_position
	var f := {"kind": "kill", "target": n, "center": c, "state": "circle", "ts": 0.0, "quiet": 0.0,
		"base_h": 24.0 + float(h % 9), "dir": 1.0 if h % 2 == 0 else -1.0, "birds": [], "mi": _make_mm(count)}
	for i in count:
		var b := {"theta": rng.randf() * TAU, "r": rng.randf_range(9.0, 21.0), "dh": rng.randf_range(-5.0, 6.0),
			"spd": rng.randf_range(8.5, 11.0), "phase": rng.randf() * TAU, "amp": 0.15, "fold": 0.0, "peck": 0.0,
			"flap_t": rng.randf_range(0.0, 4.0), "pos": c + Vector3(0, 30, 0), "fwd": Vector3.FORWARD, "bank": 0.0,
			"land": Vector3.ZERO, "vel": Vector3.ZERO, "hop_t": rng.randf_range(1.0, 4.0), "yaw": rng.randf() * TAU}
		f.birds.append(b)
	flocks.append(f)
	return f


func _new_flyover() -> void:
	var pp := _player_pos()
	var a := rng.randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-dir.z, 0, dir.x) * rng.randf_range(-70.0, 70.0)
	var start := pp - dir * 260.0 + side
	start.y = _ground(pp.x, pp.z) + rng.randf_range(35.0, 60.0)
	var count := rng.randi_range(1, 3)
	var f := {"kind": "fly", "state": "fly", "ts": 0.0, "center": start, "dir3": dir, "called": false,
		"birds": [], "mi": _make_mm(count)}
	for i in count:
		var off := Vector3(rng.randf_range(-6, 6), rng.randf_range(-3, 3), rng.randf_range(-8, 8))
		f.birds.append({"pos": start + off, "fwd": dir, "phase": rng.randf() * TAU, "amp": 0.6, "fold": 0.0,
			"peck": 0.0, "flap_t": rng.randf_range(0, 3), "bank": 0.0, "spd": rng.randf_range(11.0, 13.0)})
	flocks.append(f)


func _free_flock(f: Dictionary) -> void:
	if is_instance_valid(f.mi):
		f.mi.queue_free()
	flocks.erase(f)


func scatter(f: Dictionary, from: Vector3) -> void:
	if f.kind != "kill" or f.state == "scatter":
		return
	var low: bool = f.state == "ground" or f.state == "land"
	f.state = "scatter"
	f.ts = 0.0
	f.quiet = 0.0
	for b in f.birds:
		var away: Vector3 = b.pos - from
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		b.vel = (away + Vector3(rng.randf_range(-0.4, 0.4), 0.9, rng.randf_range(-0.4, 0.4))).normalized() * rng.randf_range(7.0, 10.0)
		b.fold = 0.0
		b.peck = 0.0
		b.amp = 1.0
	var c: Vector3 = f.center + Vector3(0, 2 if low else f.base_h, 0)
	if low:
		_play("wings_%d" % rng.randi_range(0, 1), c, -4.0, 6.0, 90.0)
	_play("raven_%d" % rng.randi_range(0, 3), c, 2.0, 18.0, 420.0, rng.randf_range(0.94, 1.08))
	if rng.randf() < 0.6:
		_pending.append([_t + rng.randf_range(0.8, 2.0), "raven_%d" % rng.randi_range(0, 3), c + Vector3(rng.randf_range(-8, 8), 6, rng.randf_range(-8, 8)), 0.0, 0.0])


func _on_noise(pos: Vector3, radius: float, _source: Object) -> void:
	for f in flocks:
		if f.kind != "kill":
			continue
		var d: float = Vector2(f.center.x - pos.x, f.center.z - pos.z).length()
		if d < radius + 15.0:
			f.quiet = 0.0
			if f.state == "ground" or f.state == "land" or radius >= 60.0:
				scatter(f, pos)


func _update_flock(f: Dictionary, dt: float) -> void:
	f.ts += dt
	var pp := _player_pos()
	var night := _night()
	var mi: MultiMeshInstance3D = f.mi
	if not is_instance_valid(mi):
		flocks.erase(f)
		return
	if f.kind == "fly":
		for b in f.birds:
			b.pos += f.dir3 * b.spd * dt
			b.fwd = f.dir3
			_flap_cycle(b, dt, 0.35)
		if not f.called and f.ts > 18.0 and rng.randf() < 0.5:
			f.called = true
			_play("raven_%d" % rng.randi_range(0, 3), f.birds[0].pos, 0.0, 18.0, 420.0, rng.randf_range(0.95, 1.06))
		elif not f.called and f.ts > 18.0:
			f.called = true
		if f.ts > 48.0:
			_free_flock(f)
			return
		_write_mm(f)
		return
	# kill flock
	var tgt = f.target
	var gone: bool = not is_instance_valid(tgt) or (tgt as Node).is_queued_for_deletion() or not ((tgt as Node).is_in_group("carcasses") or (tgt as Node).is_in_group("bodies"))
	if gone and f.state != "leave":
		f.state = "leave"
		f.ts = 0.0
		for b in f.birds:
			b.vel = Vector3(rng.randf_range(-1, 1), 0.5, rng.randf_range(-1, 1)).normalized() * 10.0
			b.fold = 0.0
			b.amp = 0.8
	mi.visible = night < ROOST_NIGHT
	if not mi.visible:
		if f.state != "circle":
			f.state = "circle"
			for b in f.birds: b.fold = 0.0; b.peck = 0.0
		return
	var pd: float = Vector2(f.center.x - pp.x, f.center.z - pp.z).length()
	if pd < LAND_CLEAR_R:
		f.quiet = 0.0
	else:
		f.quiet += dt
	match f.state:
		"circle":
			if pd < SCARE_R:
				f.base_h = maxf(f.base_h, 42.0)   # you are at their kill: they wheel high and wait
			elif f.base_h > 30.0 and pd > LAND_CLEAR_R:
				f.base_h = move_toward(f.base_h, 28.0, dt * 0.5)
			for b in f.birds:
				_circle(f, b, dt)
			if f.ts > 25.0 and f.quiet > QUIET_S and night < 0.3:
				f.state = "land"
				f.ts = 0.0
				for b in f.birds:
					var a := rng.randf() * TAU
					var r := rng.randf_range(1.0, 3.2)
					var lx: float = f.center.x + cos(a) * r
					var lz: float = f.center.z + sin(a) * r
					b.land = Vector3(lx, _ground(lx, lz) + PERCH_Y, lz)
		"land":
			if pd < SCARE_R:
				scatter(f, pp)
			else:
				var all_down := true
				for b in f.birds:
					var to: Vector3 = b.land - b.pos
					var d := to.length()
					if d > 0.15:
						all_down = false
						var step := minf(d, (5.0 + minf(d, 30.0) * 0.25) * dt)
						b.pos += to / d * step
						var flat := Vector3(to.x, 0, to.z)
						if flat.length() > 0.3:
							b.fwd = flat.normalized()
						b.amp = move_toward(b.amp, 0.9 if d < 6.0 else 0.3, dt * 2.0)
						b.fold = 0.0
					else:
						b.pos = b.land
						b.amp = 0.0
						b.fold = move_toward(b.fold, 1.0, dt * 3.0)
					b.bank = 0.0
				if all_down:
					f.state = "ground"
					f.ts = 0.0
		"ground":
			if pd < SCARE_R:
				scatter(f, pp)
			else:
				for b in f.birds:
					b.fold = 1.0
					b.amp = 0.0
					b.hop_t -= dt
					b.peck = maxf(0.0, sin(f.ts * 6.0 + b.phase)) if fmod(f.ts + b.phase, 5.0) < 2.5 else 0.0
					if b.hop_t <= 0.0:   # a hop: a short shuffle round the carcass
						b.hop_t = rng.randf_range(2.0, 6.0)
						b.yaw = rng.randf() * TAU
						var a := rng.randf() * TAU
						var r := rng.randf_range(1.0, 3.2)
						var lx: float = f.center.x + cos(a) * r
						var lz: float = f.center.z + sin(a) * r
						b.land = Vector3(lx, _ground(lx, lz) + PERCH_Y, lz)
					var to: Vector3 = b.land - b.pos
					b.pos += to.limit_length(dt * 2.0)
					b.pos.y = b.land.y + absf(sin(clampf(to.length(), 0.0, 0.6) * PI / 0.6)) * 0.12
					b.fwd = Vector3(cos(b.yaw), 0, sin(b.yaw))
				if rng.randf() < dt * 0.02:
					_play("raven_%d" % rng.randi_range(0, 3), f.center + Vector3(0, 0.5, 0), -4.0, 12.0, 300.0)
		"scatter":
			for b in f.birds:
				b.pos += b.vel * dt
				b.vel.y = move_toward(b.vel.y, 0.0, dt * 1.2)
				b.fwd = b.vel.normalized()
				b.amp = 1.0
				b.fold = 0.0
				b.peck = 0.0
			if f.ts > 5.0:
				f.state = "circle"
				f.ts = 0.0
				f.base_h = 44.0
				for b in f.birds:   # rejoin the wheel from where each bird is
					var rel: Vector3 = b.pos - f.center
					b.theta = atan2(rel.z, rel.x)
		"leave":
			for b in f.birds:
				b.pos += b.vel * dt
				b.fwd = b.vel.normalized()
				_flap_cycle(b, dt, 0.4)
			if f.ts > 14.0:
				_free_flock(f)
				return
	_write_mm(f)


func _circle(f: Dictionary, b: Dictionary, dt: float) -> void:
	b.theta += f.dir * b.spd / b.r * dt
	var tgt: Vector3 = f.center + Vector3(cos(b.theta) * b.r, f.base_h + b.dh + sin(_t * 0.3 + b.phase) * 3.0, sin(b.theta) * b.r)
	var to: Vector3 = tgt - b.pos
	if to.length() > 2.0:   # (re)joining the wheel: fly there
		b.pos += to.limit_length((b.spd + 3.0) * dt)
		b.fwd = to.normalized()
		b.amp = 0.9
		b.bank = 0.0
		return
	b.pos = tgt
	b.fwd = Vector3(-sin(b.theta), 0, cos(b.theta)) * f.dir
	b.bank = -f.dir * atan(b.spd * b.spd / (b.r * 9.8)) * 0.8
	b.fold = 0.0
	b.peck = 0.0
	_flap_cycle(b, dt, 0.12)


func _flap_cycle(b: Dictionary, dt: float, glide: float) -> void:
	b.flap_t -= dt
	if b.flap_t < -1.6:
		b.flap_t = rng.randf_range(2.0, 6.0)   # ravens: a few beats, then a long glide
	b.amp = move_toward(b.amp, 1.0 if b.flap_t < 0.0 else glide, dt * 3.0)


func _write_mm(f: Dictionary) -> void:
	var mm: MultiMesh = (f.mi as MultiMeshInstance3D).multimesh
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in f.birds.size():
		var b: Dictionary = f.birds[i]
		var fw: Vector3 = b.fwd
		if fw.length() < 0.01:
			fw = Vector3.FORWARD
		var up := Vector3.UP if absf(fw.normalized().y) < 0.98 else Vector3.RIGHT
		var basis := Basis.looking_at(fw.normalized(), up) * Basis(Vector3(0, 0, 1), b.bank)
		if float(b.fold) > 0.01:   # perched: body tilts nose-up, less so while pecking
			basis = basis * Basis(Vector3(1, 0, 0), float(b.fold) * (0.42 - 0.3 * float(b.peck)))
		mm.set_instance_transform(i, Transform3D(basis, b.pos))
		mm.set_instance_custom_data(i, Color(b.phase, b.amp, b.fold, b.peck))
		lo = lo.min(b.pos)
		hi = hi.max(b.pos)
	mm.custom_aabb = AABB(lo - Vector3(1, 1, 1), hi - lo + Vector3(2, 2, 2))


# ------------------------------------------------------------------ voices
func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		_streams[name] = load(AMB + name + ".wav")
	return _streams[name]


func _play(name: String, pos: Vector3, db: float, unit: float, maxd: float, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(name)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = maxd
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pos
	p.play()
	_log(name, pos, pos.distance_to(_player_pos()), true)


## A voice far beyond the audio range: placed 100 m out in its true direction, level set by the real distance
## (the clip itself carries the air absorption and the forest's reverb).
func _play_far(name: String, dir: Vector3, dist: float, db: float, real := false) -> void:
	var pp := _player_pos()
	dir.y = 0.0
	dir = dir.normalized()
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(name)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.volume_db = db - 20.0 * log(maxf(dist, 100.0) / 100.0) / log(10.0)
	p.pitch_scale = rng.randf_range(0.95, 1.05)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pp + dir * 100.0 + Vector3(0, 6, 0)
	p.play()
	_log(name, pp + dir * dist, dist, real)


func _log(name: String, pos: Vector3, dist: float, real: bool) -> void:
	heard.append({"kind": name.get_slice("_", 0), "name": name, "pos": pos, "dist": dist, "real": real})
	if heard.size() > 40:
		heard.pop_front()


func _flush_pending() -> void:
	for e in _pending.duplicate():
		if _t < float(e[0]):
			continue
		_pending.erase(e)
		if float(e[4]) > 0.0:
			_play_far(e[1], e[2], e[4], e[3], bool(e[5]) if e.size() > 5 else false)
		else:
			_play(e[1], e[2], e[3], 18.0, 420.0, rng.randf_range(0.95, 1.06))


func _wolves() -> Array:
	var out: Array = []
	var ws = world.get("wolves")
	if ws == null:
		return out
	for w in ws:
		if is_instance_valid(w) and not w.dead:
			out.append(w)
	return out


func _hunted() -> bool:
	var pp := _player_pos()
	for w in _wolves():
		if w.state == Wolf.State.CHASE and w.global_position.distance_to(pp) < 150.0:
			return true
	return false


func _voices(dt: float) -> void:
	var night := _night()
	var weather: Weather = world.get("weather")
	var wind := weather.wind if weather != null else 3.0
	var precip := weather.precip if weather != null else 0.0
	_howl_t -= dt
	_owl_t -= dt
	_call_t -= dt
	_fly_t -= dt
	if _howl_t <= 0.0:
		_howl_t = rng.randf_range(180.0, 420.0)
		if night > 0.8 and wind < 16.0 and not _hunted():
			howl_chorus()
	if _owl_t <= 0.0:
		_owl_t = rng.randf_range(70.0, 200.0)
		if night > 0.4 and wind < 10.0 and precip < 0.5:
			owl_call()
	if _call_t <= 0.0:
		_call_t = rng.randf_range(100.0, 260.0)
		if night < 0.3 and precip < 0.7:
			var a := rng.randf() * TAU
			_play_far("raven_%d" % rng.randi_range(0, 3), Vector3(cos(a), 0, sin(a)), rng.randf_range(120.0, 280.0), -8.0)
	if _fly_t <= 0.0:
		_fly_t = rng.randf_range(160.0, 420.0)
		if night < 0.3 and precip < 0.5 and wind < 14.0:
			_new_flyover()


## A lead howl and 1-2 answers. The lead comes from a real wolf 150-1200 m away when there is one (so a howl tells
## you where a pack is), the answers from other wolves or from beyond the map.
func howl_chorus() -> void:
	var pp := _player_pos()
	var far: Array = []
	for w in _wolves():
		var d: float = w.global_position.distance_to(pp)
		if d > 150.0 and d < 1200.0:
			far.append(w)
	far.shuffle()
	var lead_dir: Vector3
	var lead_d: float
	var real := false
	if far.size() > 0:
		lead_dir = far[0].global_position - pp
		lead_d = lead_dir.length()
		real = true
	else:
		var a := rng.randf() * TAU
		lead_dir = Vector3(cos(a), 0, sin(a))
		lead_d = rng.randf_range(450.0, 1100.0)
	_play_far("howl_far_%d" % rng.randi_range(0, 3), lead_dir, lead_d, -3.0, real)
	var t := _t
	for i in rng.randi_range(1, 2):
		t += rng.randf_range(3.0, 9.0)
		var dir: Vector3
		var d: float
		var r2 := false
		if far.size() > i:
			dir = far[i].global_position - pp
			d = dir.length()
			r2 = true
		else:
			dir = lead_dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(60.0, 160.0)) * (1.0 if rng.randf() < 0.5 else -1.0))
			d = rng.randf_range(400.0, 1200.0)
		_pending.append([t, "howl_far_%d" % rng.randi_range(0, 3), dir, -3.0, d, r2])


func owl_call() -> void:
	var a := rng.randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	var d := rng.randf_range(70.0, 220.0)
	var first := rng.randi_range(0, 1)
	_play_far("owl_%d" % first, dir, d, -4.0)
	if rng.randf() < 0.35:   # the pair duets: the other answers from nearby
		_pending.append([_t + rng.randf_range(2.5, 5.0), "owl_%d" % (1 - first), dir.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)), -5.0, d * rng.randf_range(0.8, 1.3), false])


# ------------------------------------------------------------------ the bird
## Raven, ~0.6 m long, 1.2 m span, forward = -Z. COLOR: r span 0..1, g side (0 left / 1 right / .5 body),
## b wing flag, a head flag (the vertex shader flaps / folds wings and dips the head).
static func bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [[0.18, 0.035, 0.0, 0.0], [0.07, 0.085, 0.0, 0.0], [-0.06, 0.092, 0.008, 0.0], [-0.16, 0.062, 0.02, 0.0],
		[-0.20, 0.058, 0.032, 1.0], [-0.28, 0.044, 0.03, 1.0], [-0.33, 0.022, 0.018, 1.0], [-0.42, 0.004, 0.006, 1.0]]
	var sides := 7
	var pts: Array = []
	for r in rings:
		var ring: Array = []
		for k in sides:
			var a := TAU * k / sides
			ring.append(Vector3(cos(a) * r[1], sin(a) * r[1] * 0.95 + r[2], r[0]))
		pts.append(ring)
	for i in rings.size() - 1:
		var head: float = rings[i + 1][3]
		for k in sides:
			var a0: Vector3 = pts[i][k]
			var a1: Vector3 = pts[i][(k + 1) % sides]
			var b0: Vector3 = pts[i + 1][k]
			var b1: Vector3 = pts[i + 1][(k + 1) % sides]
			for v in [a0, b0, a1, a1, b0, b1]:
				var c := Vector3(0, rings[i][2], v.z)
				st.set_normal((v - c).normalized())
				st.set_color(Color(0, 0.5, 0, head if (v.z < -0.19) else 0.0))
				st.add_vertex(v)
	var tail := [Vector3(-0.03, 0, 0.14), Vector3(0.03, 0, 0.14), Vector3(0.075, -0.005, 0.37), Vector3(0.0, -0.004, 0.40), Vector3(-0.075, -0.005, 0.37)]
	for tri in [[0, 1, 2], [0, 2, 3], [0, 3, 4]]:
		for j in tri:
			st.set_normal(Vector3.UP)
			st.set_color(Color(0, 0.5, 0, 0))
			st.add_vertex(tail[j])
	# legs (COLOR.b 0.5): two thin dark strips under the body, only out when perched
	for lx in [-0.035, 0.035]:
		var leg := [Vector3(lx - 0.008, -0.06, 0.0), Vector3(lx + 0.008, -0.06, 0.0), Vector3(lx + 0.006, -0.17, -0.01), Vector3(lx - 0.006, -0.17, -0.01),
			Vector3(lx - 0.02, -0.17, -0.05), Vector3(lx + 0.02, -0.17, -0.05)]
		for tri in [[0, 1, 2], [0, 2, 3], [3, 2, 5], [3, 5, 4]]:
			for j in tri:
				st.set_normal(Vector3.FORWARD)
				st.set_color(Color(0, 0.5, 0.5, 0))
				st.add_vertex(leg[j])
	# wing: leading / trailing edge pairs at 4 span stations (x, z_lead, z_trail, y)
	var stn := [[0.05, -0.09, 0.12, 0.02], [0.25, -0.12, 0.15, 0.03], [0.45, -0.08, 0.12, 0.025], [0.62, 0.00, 0.07, 0.02]]
	for side in [-1.0, 1.0]:
		var g := 0.0 if side < 0.0 else 1.0
		for i in stn.size() - 1:
			var s0: Array = stn[i]
			var s1: Array = stn[i + 1]
			var l0 := Vector3(side * s0[0], s0[3] + 0.006, s0[1])
			var t0 := Vector3(side * s0[0], s0[3], s0[2])
			var l1 := Vector3(side * s1[0], s1[3] + 0.006, s1[1])
			var t1 := Vector3(side * s1[0], s1[3], s1[2])
			for v in [l0, t0, l1, l1, t0, t1]:
				st.set_normal(Vector3.UP)
				st.set_color(Color(absf(v.x) / 0.62, g, 1.0, 0.0))
				st.add_vertex(v)
		# primaries: three splayed "fingers" off the tip, the raven's signature in silhouette
		for k in 3:
			var z0 := 0.0 + k * 0.03
			var a := Vector3(side * 0.56, 0.02, z0)
			var b := Vector3(side * 0.56, 0.02, z0 + 0.025)
			var tip := Vector3(side * (0.70 - k * 0.025), 0.02, z0 + 0.03 + k * 0.02)
			for v in [a, b, tip]:
				st.set_normal(Vector3.UP)
				st.set_color(Color(1.0, g, 1.0, 0.0))
				st.add_vertex(v)
	return st.commit()
