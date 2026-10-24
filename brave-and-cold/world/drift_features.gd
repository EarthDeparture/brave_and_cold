class_name DriftFeatures
extends Node3D
## Plan A2: what a windy TLD day adds on top of the ground streaks (GroundDrift).
##  * Ridge plumes: spindrift curling off crests 30-150 m away (4 emitters), the TLD windy-day signature.
##  * Roof plumes: snow streaming off cabin / hut / store ridgelines within 80 m (3 emitters).
##  * Gust snow-bombs: a gust 3 m/s over the base wind knocks a puff out of a crown 4-12 m away (3 bursts).
##  * Blowing-snow hiss: real storm recording, grain band (drift_hiss.wav); level = drift level x openness, muffled
##    indoors.
## Plumes need 10 m/s.

const PLUME_WIND := 10.0
const RIDGE_EVERY := 2.0
var world: Node
var drift: GroundDrift
var force_wind := -1.0
var ridges: Array = []            # current crest points (Vector3), strongest first (tests)
var bombs := 0
var hiss_db := -80.0
var _plumes: Array[GPUParticles3D] = []
var _roofs: Array[GPUParticles3D] = []
var _bombs: Array[GPUParticles3D] = []
var _bomb_i := 0
var _bomb_cd := 0.0
var _ridge_t := 0.0
var _hiss: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _mats: Array[StandardMaterial3D] = []


func setup(w: Node, d: GroundDrift) -> void:
	world = w
	drift = d
	_rng.seed = 5151
	top_level = true
	for i in 4: _plumes.append(_emitter(160, 4.2, 2.5, 8.0, 0.42, Vector3(8.0, 1.2, 8.0)))
	for i in 3: _roofs.append(_emitter(100, 2.6, 1.0, 3.6, 0.6, Vector3(3.4, 0.2, 0.5)))
	for i in 3:
		var b := _emitter(90, 2.8, 0.9, 2.8, 0.85, Vector3(1.4, 0.8, 1.4))
		b.one_shot = true
		b.explosiveness = 0.95
		(b.process_material as ParticleProcessMaterial).gravity = Vector3(0, -4.5, 0)
		(b.process_material as ParticleProcessMaterial).spread = 70.0
		_bombs.append(b)
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = StoreLights._loop("res://assets/audio/ambient/drift_hiss.wav")
	_hiss.bus = "Ambient" if AudioServer.get_bus_index("Ambient") >= 0 else "Master"
	_hiss.volume_db = -80.0
	add_child(_hiss)


func _emitter(n: int, life: float, s0: float, s1: float, alpha: float, box: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-60, -20, -60), Vector3(120, 60, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.spread = 18.0
	pm.gravity = Vector3(0, -0.2, 0)   # spray settles back; it streams with the wind, it doesn't rise like smoke
	pm.damping_min = 0.4; pm.damping_max = 0.9
	pm.scale_min = s0; pm.scale_max = s0 * 1.4
	pm.scale_curve = CabinFire._curve([[0.0, 0.25], [0.35, 0.7], [1.0, 1.0]])
	pm.angle_min = -180.0; pm.angle_max = 180.0
	pm.color_ramp = CabinFire._ramp([[0.0, Color(1, 1, 1, 0.0)], [0.08, Color(0.97, 0.98, 1.0, alpha)], [0.4, Color(0.95, 0.97, 1.0, alpha * 0.5)], [1.0, Color(0.95, 0.97, 1.0, 0.0)]])
	p.process_material = pm
	p.set_meta("s1", s1)
	# snow spray is bright and translucent: unshaded (a shaded billboard lit from behind went dark grey), with its
	# brightness following the daylight each frame, and soft where it meets the ground
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = CabinFire._puff_tex()
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.2
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats.append(m)
	var q := QuadMesh.new(); q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


func _h(x: float, z: float) -> float:
	return float(world.call("_ground_y", x, z)) if world.has_method("_ground_y") else 0.0


## Convexity of the ground along the wind at p: how far it stands above the line between 30 m upwind and 30 m
## downwind (the map's ridges are broad: an 8 m baseline never found one). A crest is >= 1.0 m, rising from upwind
## (or flat) and falling away downwind. Static over a height Callable so tests can feed a synthetic ridge.
const CREST_BASE := 30.0
const CREST_MIN := 1.0
static func crest_k(h: Callable, p: Vector2, wd: Vector2) -> float:
	var hc: float = h.call(p.x, p.y)
	var hu: float = h.call(p.x - wd.x * CREST_BASE, p.y - wd.y * CREST_BASE)
	var hd: float = h.call(p.x + wd.x * CREST_BASE, p.y + wd.y * CREST_BASE)
	var convex := hc - 0.5 * (hu + hd)
	return convex if convex >= CREST_MIN and hc >= hu - 0.5 and hd < hc - 0.5 else 0.0


func _wind() -> float:
	var weather: Weather = world.get("weather")
	if force_wind >= 0.0: return force_wind
	return weather.wind if weather != null else 0.0


func _process(delta: float) -> void:
	if world == null or drift == null: return
	var weather: Weather = world.get("weather")
	var p = world.get("player")
	if weather == null or p == null: return
	var pp: Vector3 = (p as Node3D).global_position
	var wind := _wind()
	var wd: Vector2 = weather.wind_dir.normalized() if weather.wind_dir.length() > 0.01 else Vector2(1, 0)
	var indoor := float(world.get("_indoor_k")) if world.get("_indoor_k") != null else 0.0
	var strong := wind >= PLUME_WIND
	var night: float = world.sky_rig.gameplay_night_factor if world.get("sky_rig") != null else 0.0
	var lum := clampf(1.0 - 0.85 * night, 0.12, 1.0) * (0.92 if weather.overcast > 0.5 else 1.0)
	for m in _mats: m.albedo_color = Color(lum, lum, lum * 1.03)
	# ---- ridge plumes
	_ridge_t -= delta
	if _ridge_t <= 0.0:
		_ridge_t = RIDGE_EVERY
		var hf := Callable(self, "_h")
		if not strong:
			ridges.clear()
		else:
			# crests are sticky: a plume stays on its crest while it is in range and still a crest (re-picking every
			# scan made emitters jump and never build a plume); free slots are filled from a fixed world-space lattice
			# of sample rings, so the same crest is found again from nearby
			var keep: Array = []
			for r0 in ridges:
				var rv: Vector3 = r0
				if Vector2(rv.x - pp.x, rv.z - pp.z).length() < 170.0 and crest_k(hf, Vector2(rv.x, rv.z), wd) > 0.0:
					keep.append(rv)
			ridges = keep
			var found: Array = []
			for i in 36:   # 3 rings x 12 bearings
				var a := TAU * float(i % 12) / 12.0 + float(i / 12) * 0.26
				var r: float = [40.0, 85.0, 135.0][i / 12]
				var q := Vector2(pp.x, pp.z) + Vector2(cos(a), sin(a)) * r
				q = (q / 12.0).round() * 12.0   # snap to a 12 m lattice: stable from frame to frame
				var k := crest_k(hf, q, wd)
				if k > 0.0 and drift.openness_at(q.x, q.y) > 0.6:
					found.append([k, Vector3(q.x, _h(q.x, q.y), q.y)])
			found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
			for f in found:
				if ridges.size() >= _plumes.size(): break
				var near := false
				for rv in ridges: if (rv as Vector3).distance_to(f[1]) < 25.0: near = true
				if not near: ridges.append(f[1])
		for i in _plumes.size():
			var e := _plumes[i]
			if i < ridges.size():
				var at: Vector3 = (ridges[i] as Vector3) + Vector3(0, 1.0, 0)
				if e.global_position.distance_to(at) > 1.0: e.global_position = at
				_aim(e, wd, wind, 0.6, 0.9)
				e.emitting = true
			else:
				e.emitting = false
	# ---- roof plumes
	var roofs: Array = []
	if strong and world.has_method("_building_list"):
		for b in world.call("_building_list"):
			if b is Node3D and (b as Node3D).global_position.distance_to(pp) < 80.0 and b.get("burned") != true:
				roofs.append(b)
		roofs.sort_custom(func(x: Node3D, y: Node3D) -> bool: return x.global_position.distance_to(pp) < y.global_position.distance_to(pp))
	for i in _roofs.size():
		var e := _roofs[i]
		if i < roofs.size():
			var b: Node3D = roofs[i]
			e.global_transform = Transform3D(Basis(Vector3.UP, b.global_rotation.y), b.global_position + Vector3(0, _ridge_y(b), 0))
			_aim(e, wd, wind, 0.7, 0.6)
			e.emitting = true
		else:
			e.emitting = false
	# ---- gust snow-bombs
	_bomb_cd -= delta
	if _bomb_cd <= 0.0 and weather.wind - weather.wind_base > 3.0 and indoor < 0.5:
		_bomb_cd = 1.6
		drop_bomb(pp, wd, wind)
	# ---- hiss
	var lvl := drift.level * drift.open_here * (1.0 - 0.85 * indoor)
	var want := -80.0 if lvl < 0.02 else lerpf(-30.0, -7.0, sqrt(lvl))
	hiss_db = lerpf(hiss_db, want, clampf(delta * 1.5, 0.0, 1.0))
	_hiss.volume_db = hiss_db
	if hiss_db > -60.0 and not _hiss.playing: _hiss.play(_rng.randf() * 10.0)
	elif hiss_db <= -70.0 and _hiss.playing: _hiss.stop()


## A puff of snow knocked out of a crown 4-12 m away, 6-10 m up, falling and drifting downwind.
func drop_bomb(pp: Vector3, wd: Vector2, wind: float) -> bool:
	var forest = world.get("forest")
	if forest == null: return false
	var a := _rng.randf() * TAU
	var probe := pp + Vector3(cos(a), 0, sin(a)) * 7.0
	var t: Dictionary = forest.nearest_tree(probe, Vector3(cos(a), 0, sin(a)), 6.0, false)
	if t.is_empty(): return false
	var tp := Vector3(float(t.x), 0, float(t.z))
	var d := Vector2(tp.x - pp.x, tp.z - pp.z).length()
	if d < 4.0 or d > 12.0: return false
	tp.y = _h(tp.x, tp.z) + _rng.randf_range(6.0, minf(10.0, float(t.get("h", 12.0)) * 0.8))
	var e := _bombs[_bomb_i]
	_bomb_i = (_bomb_i + 1) % _bombs.size()
	e.global_position = tp
	_aim(e, wd, wind, 0.25, -0.5)
	e.restart()
	e.emitting = true
	bombs += 1
	return true


func _aim(e: GPUParticles3D, wd: Vector2, wind: float, k: float, up: float) -> void:
	var pm: ParticleProcessMaterial = e.process_material
	var v := Vector3(wd.x * wind * k, up, wd.y * wind * k)
	pm.direction = (e.global_basis.inverse() * v).normalized()
	pm.initial_velocity_min = v.length() * 0.8
	pm.initial_velocity_max = v.length() * 1.15
	pm.scale_max = float(e.get_meta("s1"))


func _ridge_y(b: Node3D) -> float:
	if b.has_meta("ridge_y"): return float(b.get_meta("ridge_y"))
	var top := 0.0
	for vi in b.find_children("*", "MeshInstance3D", true, false):
		var mi := vi as MeshInstance3D
		if not mi.visible: continue
		var ab := mi.get_aabb()
		top = maxf(top, (b.global_transform.affine_inverse() * mi.global_transform * (ab.position + ab.size)).y)
	top = clampf(top, 2.5, 7.0)
	b.set_meta("ridge_y", top)
	return top
