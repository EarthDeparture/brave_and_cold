class_name GroundDrift
extends Node3D
## Alive L1.4: wind-blown snow streaming along the ground ("snow snakes") in wind >= MIN_WIND, the TLD
## windy-day look even under a clear sky. A pool of streaks round the player, each a cross of a flat sheet on
## the snow and a low curtain, laid on the terrain height and tilted to the slope, drifting downwind and
## respawning upwind. One MultiMesh (one draw call); a flow-noise shader scrolls along each streak.

const N := 180
const R := 34.0
const MIN_WIND := 7.5
const FULL_WIND := 16.0

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.93, 0.95, 1.0);
varying float life;
varying float ph;
varying float kk;
varying float curtain;
void vertex() {
	life = INSTANCE_CUSTOM.x;
	ph = INSTANCE_CUSTOM.y;
	kk = INSTANCE_CUSTOM.z;
	curtain = COLOR.r;
}
void fragment() {
	// uv.y runs along the streak (0 = downwind end); features flow downwind
	float flow = texture(noise_tex, vec2(UV.x * 0.55 + ph, UV.y * 1.4 + TIME * 1.3 + ph)).r;
	float fine = texture(noise_tex, vec2(UV.x * 2.2 + ph * 3.0, UV.y * 4.5 + TIME * 2.4)).r;
	float across = curtain > 0.5 ? (1.0 - smoothstep(0.15, 1.0, UV.x)) * smoothstep(0.0, 0.08, UV.x)   // curtain: dense at the snow, thin on top
		: smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	float along = smoothstep(0.0, 0.22, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float fade = smoothstep(0.0, 0.15, life) * smoothstep(1.0, 0.7, life);
	float a = smoothstep(0.28, 0.72, flow * 0.75 + fine * 0.4) * across * along * fade * kk;
	ALBEDO = tint;
	ALPHA = a * (curtain > 0.5 ? 0.75 : 0.9);
	ROUGHNESS = 1.0;
}
"""

var world: Node
var force_wind := -1.0          # captures / tests
var level := 0.0                # 0..1 current strength (tests)
var active := 0
var height_samples := 0         # terrain queries last frame (perf tests)
var _frame := 0
var _mi: MultiMeshInstance3D
var _mm: MultiMesh
var _s: Array = []
var _rng := RandomNumberGenerator.new()
var _grains: GPUParticles3D       # spindrift: fine grains skimming the snow right round your feet
## A2: drift only where the wind reaches the snow. Openness 0..1 per 8 m cell (canopy height, buildings), cached;
## streaks don't start in a building or its lee (2.5 x its height downwind) and die when they reach a trunk.
const OPEN_CELL := 8.0
var _open := {}
var ground_wind_k := 1.0          # wind near the ground at the player: x0.4 under a dense canopy (GameAudio, features)
var open_here := 1.0
var _blds: Array = []
var _bld_t := 0.0
var lee_rejects := 0              # tests: spawns refused in a building lee
var trunk_kills := 0              # tests: streaks that ran into a trunk
var _gpm: ParticleProcessMaterial
const GRAINS := 1400


func setup(w: Node) -> void:
	world = w
	_rng.seed = 7771
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.035
	fn.fractal_octaves = 3
	nt.noise = fn
	nt.seamless = true
	nt.width = 128
	nt.height = 128
	mat.set_shader_parameter("noise_tex", nt)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = _streak_mesh()
	_mm.instance_count = N
	_mm.visible_instance_count = 0
	_mi = MultiMeshInstance3D.new()
	_mi.multimesh = _mm
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_mi.top_level = true
	_mi.global_transform = Transform3D.IDENTITY
	_make_grains()
	for i in N:
		_s.append({"p": Vector2.ZERO, "len": 3.0, "wid": 0.8, "life": 1.0, "age": 9.9, "ph": _rng.randf(), "v": 1.0})


## Unit cross: a flat sheet (x -0.5..0.5, z -0.5..0.5, uv.y along z) and an upright curtain along the same axis
## (height 0..1 in uv.x). COLOR.r = 1 marks the curtain.
static func _streak_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sheet := [[Vector3(-0.5, 0, -0.5), Vector2(0, 0)], [Vector3(0.5, 0, -0.5), Vector2(1, 0)], [Vector3(0.5, 0, 0.5), Vector2(1, 1)], [Vector3(-0.5, 0, 0.5), Vector2(0, 1)]]
	var curt := [[Vector3(0, 0, -0.5), Vector2(0, 0)], [Vector3(0, 0.6, -0.5), Vector2(1, 0)], [Vector3(0, 0.6, 0.5), Vector2(1, 1)], [Vector3(0, 0, 0.5), Vector2(0, 1)]]
	for q in [[sheet, 0.0, Vector3.UP], [curt, 1.0, Vector3.RIGHT]]:
		var v: Array = q[0]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(q[1], 0, 0, 1))
			st.set_normal(q[2])
			st.set_uv(v[idx][1])
			st.add_vertex(v[idx][0])
	return st.commit()


func _make_grains() -> void:
	_grains = GPUParticles3D.new()
	_grains.amount = GRAINS
	_grains.lifetime = 1.1
	_grains.local_coords = false
	_grains.top_level = true
	_grains.visibility_aabb = AABB(Vector3(-14, -4, -14), Vector3(28, 8, 28))
	_grains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gpm = ParticleProcessMaterial.new()
	_gpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_gpm.emission_box_extents = Vector3(6.5, 0.12, 6.5)
	_gpm.spread = 6.0
	_gpm.gravity = Vector3.ZERO
	_gpm.turbulence_enabled = true
	_gpm.turbulence_noise_strength = 1.4
	_gpm.turbulence_noise_scale = 1.6
	_gpm.turbulence_influence_min = 0.05
	_gpm.turbulence_influence_max = 0.15
	_gpm.scale_min = 0.5
	_gpm.scale_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 0.8))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	_gpm.color_ramp = rt
	_grains.process_material = _gpm
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.07)   # a grain smeared along its path (motion blur)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.55)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.disable_receive_shadows = true   # billboard_mode stays DISABLED: the particle transform aligns Y to velocity
	q.material = m
	_grains.draw_pass_1 = q
	_grains.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_grains.emitting = false
	add_child(_grains)


func openness_at(x: float, z: float) -> float:
	var k := (int(floor(x / OPEN_CELL)) + 100000) * 1000003 + (int(floor(z / OPEN_CELL)) + 100000)
	var v = _open.get(k)
	if v != null: return v
	if _open.size() > 20000: _open.clear()
	var o := 1.0
	var snow: SnowField = world.get("snow") if world != null else null
	if snow != null:
		var cx: float = (floorf(x / OPEN_CELL) + 0.5) * OPEN_CELL
		var cz: float = (floorf(z / OPEN_CELL) + 0.5) * OPEN_CELL
		var ch := 0.0
		for off in [Vector2.ZERO, Vector2(2.5, 2.5), Vector2(-2.5, 2.5), Vector2(2.5, -2.5), Vector2(-2.5, -2.5)]:
			ch += snow.canopy_height_at(cx + off.x, cz + off.y)
		ch /= 5.0
		o = 1.0 - clampf((ch - 2.0) / 9.0, 0.0, 1.0) * 0.88   # under ~2 m (scrub, drifts) counts as open
	_open[k] = o
	return o


## Inside a building, or in the sheltered wake 2.5 x its height downwind of it.
func in_lee(p: Vector2, wd: Vector2) -> bool:
	for b in _blds:
		if not is_instance_valid(b): continue
		if b.has_method("contains_xz"):
			if b.contains_xz(p.x, p.y): return true
		elif b.has_method("contains_room") and b.contains_room(Vector3(p.x, b.global_position.y + 1.0, p.y)): return true
		var c := Vector2(b.global_position.x, b.global_position.z)
		var rel := p - c
		var along := rel.dot(wd)
		var lat := absf(rel.dot(Vector2(-wd.y, wd.x)))
		if along > 0.0 and along < 3.5 + 2.5 * 4.5 and lat < 4.0: return true
	return false


func _refresh_blds(pp: Vector3) -> void:
	_blds.clear()
	if world == null or not world.has_method("_building_list"): return
	for b in world.call("_building_list"):
		if b is Node3D and (b as Node3D).global_position.distance_to(pp) < R + 40.0 and (b.has_method("contains_xz") or b.has_method("contains_room")):
			_blds.append(b)


func _ground(x: float, z: float) -> float:
	return float(world.call("_ground_y", x, z)) if world.has_method("_ground_y") else 0.0


func _respawn(s: Dictionary, pp: Vector2, wd: Vector2, anywhere: bool) -> void:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * R
	var p := pp + Vector2(cos(a), sin(a)) * r
	if not anywhere:   # fresh streaks start upwind so the field keeps streaming past you
		var up := R * _rng.randf_range(0.5, 0.95)
		var lat := sqrt(maxf(R * R - up * up, 0.0)) * 0.95   # stay inside the circle (corner spawns would churn)
		p = pp - wd * up + Vector2(-wd.y, wd.x) * _rng.randf_range(-lat, lat)
	# openness + lee: a few tries for a spot the wind actually sweeps; otherwise this streak sits out its life
	s.o = 0.0
	for attempt in 4:
		if in_lee(p, wd):
			lee_rejects += 1
		elif _rng.randf() < openness_at(p.x, p.y):
			s.o = 1.0
			break
		if not anywhere:
			var up2 := R * _rng.randf_range(0.5, 0.95)
			var lat2 := sqrt(maxf(R * R - up2 * up2, 0.0)) * 0.95
			p = pp - wd * up2 + Vector2(-wd.y, wd.x) * _rng.randf_range(-lat2, lat2)
		else:
			var a2 := _rng.randf() * TAU
			p = pp + Vector2(cos(a2), sin(a2)) * sqrt(_rng.randf()) * R
	s.p = p
	s.chk = p
	s.len = _rng.randf_range(3.0, 8.0)
	s.wid = _rng.randf_range(1.3, 3.2)
	s.life = _rng.randf_range(2.5, 5.0)
	s.age = 0.0 if not anywhere else _rng.randf() * s.life
	s.ph = _rng.randf()
	s.v = _rng.randf_range(0.75, 1.15)
	s.hy = INF   # force a height sample


func _process(delta: float) -> void:
	if world == null:
		return
	var weather: Weather = world.get("weather")
	var p = world.get("player")
	if weather == null or p == null:
		return
	var wind := weather.wind if force_wind < 0.0 else force_wind
	var indoor := float(world.get("_indoor_k")) if world.get("_indoor_k") != null else 0.0
	var pp3: Vector3 = (p as Node3D).global_position
	var snow: SnowField = world.get("snow")
	var on_snow := snow == null or snow.tier_at(pp3.x, pp3.z) > 0
	open_here = openness_at(pp3.x, pp3.z)
	ground_wind_k = lerpf(0.4, 1.0, open_here)
	_bld_t -= delta
	if _bld_t <= 0.0:
		_bld_t = 2.0
		_refresh_blds(pp3)
	var target := clampf((wind * ground_wind_k - MIN_WIND) / (FULL_WIND - MIN_WIND), 0.0, 1.0) * (1.0 - indoor) * (1.0 if on_snow else 0.4)
	level = move_toward(level, target, delta * 0.5)
	var want := int(round(level * N))
	if _grains != null:
		_grains.emitting = level > 0.05
		_grains.amount_ratio = clampf(level, 0.05, 1.0)
		var wd0 := weather.wind_dir.normalized() if weather.wind_dir.length() > 0.01 else Vector2(1, 0)
		# the emitter lies on the slope under you (terrain is not in any particle collider), so the grains
		# skim the snow instead of hanging in the air where the ground falls away
		var c := Vector3(pp3.x, 0, pp3.z) - Vector3(wd0.x, 0, wd0.y) * 3.5
		var hx0 := _ground(c.x - 3.0, c.z)
		var hx1 := _ground(c.x + 3.0, c.z)
		var hz0 := _ground(c.x, c.z - 3.0)
		var hz1 := _ground(c.x, c.z + 3.0)
		var nrm := Vector3(-(hx1 - hx0) / 6.0, 1.0, -(hz1 - hz0) / 6.0).normalized()
		var xa := Vector3(1, 0, 0).slide(nrm).normalized()
		var basis := Basis(xa, nrm, xa.cross(nrm).normalized())
		_grains.global_transform = Transform3D(basis, Vector3(c.x, _ground(c.x, c.z) + 0.16, c.z))
		var wl := (basis.inverse() * Vector3(wd0.x, 0.0, wd0.y)).normalized()
		_gpm.direction = Vector3(wl.x, 0.04, wl.z)
		_gpm.initial_velocity_min = wind * 0.75
		_gpm.initial_velocity_max = wind * 1.1
	if want <= 0:
		_mm.visible_instance_count = 0
		active = 0
		return
	var wd := weather.wind_dir.normalized() if weather.wind_dir.length() > 0.01 else Vector2(1, 0)
	var pp := Vector2(pp3.x, pp3.z)
	var spd := wind * 0.85
	_frame += 1
	height_samples = 0
	for i in want:
		var s: Dictionary = _s[i]
		if i >= active:   # newly enabled: scatter through the field, mid-life
			_respawn(s, pp, wd, true)
		s.age += delta
		s.p += wd * spd * float(s.v) * delta
		if s.age > s.life or (s.p - pp).length() > R:
			_respawn(s, pp, wd, false)
		elif (i + _frame) % 30 == 0 and float(s.get("o", 1.0)) > 0.0:   # ~every 0.5 s: did it run into a trunk?
			var forest = world.get("forest")
			var ck: Vector2 = s.get("chk", s.p)
			if (forest != null and forest.trunks_on_segment(ck.x, ck.y, s.p.x, s.p.y) > 0) or in_lee(s.p, wd):   # a trunk, or drifted into a building / its lee
				trunk_kills += 1
				s.age = maxf(float(s.age), float(s.life) * 0.86)   # fade out against the trunk, not pop
				s.o = 0.0
			s.chk = s.p
		var half: Vector2 = wd * float(s.len) * 0.5
		# terrain heights are resampled for a quarter of the streaks each frame (staggered); a streak moves
		# < 1 m between samples, the slope error is centimetres
		if not s.has("hy") or is_inf(float(s.hy)) or (i + _frame) % 4 == 0:
			s.hy = _ground(s.p.x - half.x, s.p.y - half.y)
			s.hy1 = _ground(s.p.x + half.x, s.p.y + half.y)
			height_samples += 2
		var y0: float = s.hy
		var y1: float = s.hy1
		var fwd := Vector3(wd.x * float(s.len), y1 - y0, wd.y * float(s.len))
		var basis := Basis.looking_at(fwd.normalized(), Vector3.UP)
		basis = basis.scaled_local(Vector3(float(s.wid), 1.0 + 0.6 * level, float(s.len)))
		_mm.set_instance_transform(i, Transform3D(basis, Vector3(s.p.x, (y0 + y1) * 0.5 + 0.04, s.p.y)))
		_mm.set_instance_custom_data(i, Color(float(s.age) / float(s.life), float(s.ph), level * float(s.get("o", 1.0)), 0))
	active = want
	_mm.visible_instance_count = want
	_mm.custom_aabb = AABB(pp3 - Vector3(R + 6, 30, R + 6), Vector3(2 * R + 12, 60, 2 * R + 12))
