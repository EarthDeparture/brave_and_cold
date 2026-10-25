class_name CabinFire
extends Node3D
## Plan A4 E2: a cabin burns (WorldEvents picks one per run, D4-D6, at night, far from the player).
## Stages in game time from start_s:
##  * IGNITION 10 min: the room light flickers orange behind the glass, thin smoke leaks from the eaves.
##  * BLAZE 2.5 h: flames through the roof, sparks, a smoke column ~150 m, an orange light on the snow 32 m round,
##    a roar heard to 220 m, the snow melting back in a ring. 35% in the roof falls in: the cabin becomes the burned
##    shell (cabin_burned.glb). Lures: a light lure at night / a smoke lure by day every 8 s, so hordes come.
##  * SMOULDER 12 h: ember cracks glowing in the charred logs, thin smoke, a dim red light, fading.
##  * SHELL: cold charred walls. No roof: not a shelter from snow or cold, only from wind; the stove still works.
## Saved as start_s on the cabin (WorldEvents); every stage is derived from time, so a reload resumes mid-fire.

const IGNITE_S := 600.0
const BLAZE_S := 9000.0
const COLLAPSE_K := 0.35
const SMOULDER_S := 43200.0
const REFILL_S := 172800.0   # W5: the melt ring fills back in over ~2 days of clear weather (snow clock: faster in snow)
const BURNED_MODEL := "res://assets/models/buildings/cabin_burned.glb"

var world: Node
var cabin: Cabin
var start_s := 0.0
var stage := ""
var collapsed := false
var lures := 0
var _flames: GPUParticles3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _eave_smoke: GPUParticles3D
var _light: OmniLight3D
var _ring: Decal
var _roar: AudioStreamPlayer3D
var _shell: Node3D
var _char_mat: StandardMaterial3D
var _lure_t := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(w: Node, cb: Cabin, t0: float) -> void:
	world = w
	cabin = cb
	start_s = t0
	_rng.seed = hash([t0, cb.get_instance_id()])
	cb.add_child(self)
	position = Vector3.ZERO
	cb.on_fire = self
	_update(true)


func stage_at(now: float) -> String:
	var t := now - start_s
	if t < 0.0: return "none"
	if t < IGNITE_S: return "ignition"
	if t < IGNITE_S + BLAZE_S: return "blaze"
	if t < IGNITE_S + BLAZE_S + SMOULDER_S: return "smoulder"
	return "shell"


func blaze_k(now: float) -> float:
	return clampf((now - start_s - IGNITE_S) / BLAZE_S, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_update(false)
	if stage == "shell" and _ring.visible:
		_ring.modulate.a = 0.9 * ring_left(world.clock.total_game_s)
		_ring.visible = _ring.modulate.a > 0.01
	if stage == "blaze":
		_lure_t -= delta
		if _lure_t <= 0.0:
			_lure_t = 8.0
			lures += 1
			var bus: NoiseBus = world.get("noise_bus")
			var night: float = world.sky_rig.gameplay_night_factor if world.get("sky_rig") != null else 1.0
			var c := cabin.global_position + Vector3(0, 3, 0)
			if bus != null:
				if night > 0.5: bus.emit_light(c, 108.0, self)
				else: bus.emit_smoke(c, 300.0, self)
				bus.emit_noise(c, 30.0, self)
		_burn_player(delta)


var _snow0 := NAN
## W5: 1 = the melt ring as the blaze left it, 0 = snowed over. Measured on the track log's snow clock
## (1 + 7 x precip per second), so a blizzard buries it in hours; before that clock existed (or after a load)
## the time since the blaze is taken as clear weather.
func ring_left(now: float) -> float:
	var end := start_s + IGNITE_S + BLAZE_S
	if now < end: return 1.0
	var tr = world.get("animal_tracks")
	var sc: float = (tr.log as TrackLog).snow_clock if tr != null else now
	if is_nan(_snow0): _snow0 = sc - (now - end)
	return 1.0 - smoothstep(0.0, REFILL_S, sc - _snow0)


func _burn_player(delta: float) -> void:
	var p = world.get("player")
	if p == null: return
	var lp := cabin.to_local(p.global_position)
	if absf(lp.x) < Cabin.HX - 0.3 and absf(lp.z) < Cabin.HZ - 0.3 and p.has_method("hurt"):
		p.hurt(9.0 * delta, "Burned to death in a burning cabin")


func _update(force: bool) -> void:
	var now: float = world.clock.total_game_s
	var s := stage_at(now)
	var k := blaze_k(now)
	if s != stage or force:
		stage = s
		_enter(s)
	var fl := 0.82 + 0.18 * sin(_t * 13.0) * sin(_t * 5.3 + 1.0)
	match s:
		"ignition":
			var ik := clampf((now - start_s) / IGNITE_S, 0.0, 1.0)
			if cabin.light != null:
				cabin.light.light_color = Color(1.0, 0.45, 0.15)
				cabin.light.light_energy = (1.5 + 4.0 * ik) * fl
			_eave_smoke.amount_ratio = 0.3 + 0.7 * ik
		"blaze":
			if not collapsed and k >= COLLAPSE_K: _collapse()
			var grow := smoothstep(0.0, 0.12, k) * (1.0 - smoothstep(0.75, 1.0, k) * 0.6)
			_flames.amount_ratio = 0.35 + 0.65 * grow
			_flames.position.y = (4.0 if not collapsed else 1.6)
			_light.light_energy = (3.0 + 6.0 * grow) * fl
			_light.omni_range = 18.0 + 14.0 * grow
			_smoke.amount_ratio = 0.4 + 0.6 * grow
			_ring.modulate.a = 0.15 + 0.75 * smoothstep(0.0, 0.6, k)
			_roar.volume_db = lerpf(0.0, 9.0, grow)
			if _char_mat != null: _char_mat.emission_energy_multiplier = 10.0 * fl
		"smoulder":
			var sk := clampf((now - start_s - IGNITE_S - BLAZE_S) / SMOULDER_S, 0.0, 1.0)
			_ring.modulate.a = 0.9 * ring_left(now)
			_light.light_energy = 1.4 * (1.0 - sk) * fl
			_smoke.amount_ratio = 0.3 * (1.0 - sk) + 0.05
			if _char_mat != null: _char_mat.emission_energy_multiplier = 2.6 * pow(1.0 - sk, 1.5) * fl


func _enter(s: String) -> void:
	_ensure_fx()
	_eave_smoke.emitting = s == "ignition"
	_flames.emitting = s == "blaze"
	_sparks.emitting = s == "blaze"
	_smoke.emitting = s == "blaze" or s == "smoulder"
	_light.visible = s == "blaze" or s == "smoulder"
	_ring.visible = s != "ignition" and s != "none"
	if s == "blaze":
		if not _roar.playing: _roar.play()
	else:
		_roar.stop()
	var km: ParticleProcessMaterial = _smoke.process_material
	km.scale_min = 5.0 if s == "smoulder" else 15.0
	km.scale_max = 8.0 if s == "smoulder" else 21.0
	km.initial_velocity_min = 1.5 if s == "smoulder" else 4.0
	km.initial_velocity_max = 2.5 if s == "smoulder" else 5.0
	if s == "smoulder":
		_light.light_color = Color(1.0, 0.3, 0.1)
		_light.omni_range = 10.0
	if s == "smoulder" or s == "shell" or (s == "blaze" and blaze_k(world.clock.total_game_s) >= COLLAPSE_K):
		if not collapsed: _collapse()
	if s == "shell":
		_ring.modulate.a = 0.9 * ring_left(world.clock.total_game_s)
		if _char_mat != null: _char_mat.emission_energy_multiplier = 0.0
		_light.visible = false


## The roof falls in: the cabin becomes the burned shell.
func _collapse() -> void:
	if collapsed: return
	collapsed = true
	cabin.burned = true
	cabin.crate_looted = true
	cabin.wood_pile = 0
	cabin.door_broken = true
	cabin.door_open = true
	for id in Cabin.FURNITURE: cabin.break_furniture(id)
	var keep := [self, cabin.get("_fire_glow"), cabin.get("_fire_light"), cabin.get("_snd")]
	for ch in cabin.get_children():
		if ch is Node3D and not (ch in keep):
			(ch as Node3D).visible = false
	if cabin.light != null: cabin.light.light_energy = 0.0
	_shell = (load(BURNED_MODEL) as PackedScene).instantiate()
	add_child(_shell)
	_char_mat = StandardMaterial3D.new()
	_char_mat.vertex_color_use_as_albedo = true
	_char_mat.albedo_color = Color(0.9, 0.9, 0.92)   # same vertex-colour pipeline as the intact cabin
	_char_mat.roughness = 1.0
	_char_mat.metallic_specular = 0.12   # matte charcoal: the default 0.5 sheen of the snow-lit sky greyed it to brown
	_char_mat.albedo_texture = Cabin._grain_tex()
	_char_mat.uv1_triplanar = true
	_char_mat.uv1_scale = Vector3(0.5, 3.0, 0.5)
	_char_mat.emission_enabled = true
	_char_mat.emission = Color(1.0, 0.33, 0.07)
	_char_mat.emission_texture = _cracks()
	_char_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_char_mat.emission_energy_multiplier = 0.0
	_char_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in _shell.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _char_mat
	if _sparks != null: _sparks.restart()   # the fall throws a burst of sparks
	var thud := AudioStreamPlayer3D.new()
	thud.stream = load("res://assets/audio/sfx/thud.wav")
	thud.unit_size = 14.0; thud.max_distance = 260.0; thud.volume_db = 8.0; thud.pitch_scale = 0.55
	add_child(thud); thud.position = Vector3(0, 3, 0)
	thud.finished.connect(thud.queue_free)
	thud.play()


static var _crack_tex: NoiseTexture2D
static func _cracks() -> Texture2D:
	if _crack_tex == null:   # thin glowing seams in charred wood (cellular edges), mostly black
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		n.fractal_octaves = 3
		n.frequency = 0.03
		var gr := Gradient.new()   # black, thin bright seams only along the ridges
		gr.offsets = PackedFloat32Array([0.0, 0.74, 0.9, 1.0])
		gr.colors = PackedColorArray([Color(0, 0, 0), Color(0, 0, 0), Color(1, 1, 1), Color(1, 1, 1)])
		var t := NoiseTexture2D.new()
		t.noise = n; t.width = 256; t.height = 256; t.seamless = true; t.color_ramp = gr
		_crack_tex = t
	return _crack_tex


func _ensure_fx() -> void:
	if _flames != null: return
	_flames = _particles(170, 1.3, _flame_mat(), Vector3(2.8, 0.7, 2.3))
	(_flames.draw_pass_1 as QuadMesh).size = Vector2(0.55, 1.25)   # tongues, not discs
	var pm: ParticleProcessMaterial = _flames.process_material
	pm.direction = Vector3(0, 1, 0); pm.spread = 12.0
	pm.initial_velocity_min = 2.5; pm.initial_velocity_max = 5.5
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 1.6; pm.scale_max = 3.6
	pm.scale_curve = _curve([[0.0, 0.5], [0.3, 1.0], [1.0, 0.25]])
	pm.color_ramp = _ramp([[0.0, Color(1.0, 0.62, 0.26, 0.0)], [0.08, Color(1.0, 0.6, 0.24, 0.42)], [0.4, Color(0.95, 0.32, 0.07, 0.34)], [0.75, Color(0.55, 0.1, 0.02, 0.16)], [1.0, Color(0.2, 0.03, 0.01, 0.0)]])
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 1.2; pm.turbulence_noise_scale = 3.0
	_flames.position = Vector3(0, 4.0, 0)
	_sparks = _particles(140, 3.0, _spark_mat(), Vector3(3.0, 1.0, 2.5))
	var sm: ParticleProcessMaterial = _sparks.process_material
	sm.direction = Vector3(0, 1, 0); sm.spread = 25.0
	sm.initial_velocity_min = 5.0; sm.initial_velocity_max = 11.0
	sm.gravity = Vector3(0, -1.0, 0)
	sm.scale_min = 0.05; sm.scale_max = 0.12
	sm.turbulence_enabled = true; sm.turbulence_noise_strength = 3.0
	sm.color_ramp = _ramp([[0.0, Color(1.0, 0.8, 0.4, 1.0)], [1.0, Color(1.0, 0.3, 0.05, 0.0)]])
	_sparks.position = Vector3(0, 3.0, 0)
	_smoke = _particles(360, 40.0, _smoke_mat(), Vector3(2.4, 0.8, 2.0))
	var km: ParticleProcessMaterial = _smoke.process_material
	km.direction = Vector3(0, 1, 0); km.spread = 9.0
	km.initial_velocity_min = 4.0; km.initial_velocity_max = 5.0
	km.gravity = Vector3(0.45, 0.12, 0.15)   # buoyant, leaning downwind as it climbs
	km.damping_min = 0.03; km.damping_max = 0.05
	km.scale_min = 15.0; km.scale_max = 21.0   # big overlapping puffs: one column, not specks
	km.scale_curve = _curve([[0.0, 0.18], [0.15, 0.3], [0.5, 0.65], [1.0, 1.0]])   # widens as it climbs
	km.color_ramp = _ramp([[0.0, Color(0.09, 0.08, 0.075, 0.0)], [0.03, Color(0.09, 0.08, 0.075, 0.95)], [0.4, Color(0.2, 0.19, 0.19, 0.8)], [0.8, Color(0.33, 0.33, 0.34, 0.45)], [1.0, Color(0.38, 0.38, 0.4, 0.0)]])
	# no turbulence: Godot lerps particle velocity toward the noise field every frame, which killed the rise at ~25 m.
	# Variety comes from the spread, per-puff speed and the downwind lean instead.
	km.turbulence_enabled = false
	km.angle_min = -180.0; km.angle_max = 180.0
	km.angular_velocity_min = -6.0; km.angular_velocity_max = 6.0
	_smoke.position = Vector3(0, 4.5, 0)
	_smoke.visibility_aabb = AABB(Vector3(-90, -10, -90), Vector3(180, 240, 180))
	_eave_smoke = FireVisual.smoke(self, Vector3(0, 3.4, 0), 30, 1.4)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.52, 0.2); _light.omni_range = 30.0; _light.omni_attenuation = 1.3
	_light.light_volumetric_fog_energy = 0.3
	add_child(_light); _light.position = Vector3(0, 3.2, 0)
	_ring = Decal.new()
	_ring.size = Vector3(28.0, 8.0, 26.0)
	_ring.texture_albedo = _ring_tex()
	_ring.upper_fade = 0.2; _ring.lower_fade = 0.3
	_ring.modulate.a = 0.0
	_ring.cull_mask = 1
	add_child(_ring); _ring.position = Vector3(0, 0.5, 0)
	_roar = AudioStreamPlayer3D.new()
	_roar.stream = StoreLights._loop("res://assets/audio/sfx/fire.wav")
	_roar.pitch_scale = 0.62; _roar.unit_size = 14.0; _roar.max_distance = 220.0
	add_child(_roar); _roar.position = Vector3(0, 3, 0)


func _particles(n: int, life: float, mat: Material, box: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	p.process_material = pm
	var q := QuadMesh.new(); q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 40, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _flame_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tongue_tex()
	return m


func _spark_mat() -> StandardMaterial3D:
	var m := _flame_mat()
	m.albedo_texture = null
	return m


func _smoke_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff_tex()
	m.roughness = 1.0
	m.disable_receive_shadows = true
	return m


static func _curve(pts: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 5.0
	for p in pts: c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new(); t.curve = c
	return t


static func _ramp(pts: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(pts.map(func(p: Array) -> float: return p[0]))
	g.colors = PackedColorArray(pts.map(func(p: Array) -> Color: return p[1]))
	var t := GradientTexture1D.new(); t.gradient = g
	return t


static var _tongue: ImageTexture
static func _tongue_tex() -> ImageTexture:   # a flame tongue: wide soft base, pointed ragged tip
	if _tongue == null:
		var img := Image.create(48, 96, false, Image.FORMAT_RGBA8)
		var n := FastNoiseLite.new(); n.frequency = 0.09; n.seed = 3
		for y in 96:
			for x in 48:
				var u := (x + 0.5) / 48.0 * 2.0 - 1.0
				var v := 1.0 - (y + 0.5) / 96.0   # 0 bottom .. 1 top
				var w := 0.85 * pow(1.0 - v, 0.7) * (0.85 + 0.3 * n.get_noise_2d(x * 1.5, y))
				var a := clampf(1.0 - absf(u) / maxf(w, 0.02), 0.0, 1.0)
				a *= smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.7, 1.0, v))
				img.set_pixel(x, y, Color(1, 1, 1, pow(a, 0.8)))
		_tongue = ImageTexture.create_from_image(img)
	return _tongue


static var _puff: ImageTexture
static func _puff_tex() -> ImageTexture:
	if _puff == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var n := FastNoiseLite.new(); n.frequency = 0.08; n.fractal_octaves = 3; n.seed = 5
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var a := smoothstep(1.0, 0.25, d)   # soft full disc, only a light billow in it
				a *= clampf(0.82 + 0.35 * n.get_noise_2d(x, y), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_puff = ImageTexture.create_from_image(img)
	return _puff


static var _ring_img: ImageTexture
static func _ring_tex() -> ImageTexture:   # snow melted back round the fire: wet dark ground, ash, ragged edge
	if _ring_img == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		var n := FastNoiseLite.new(); n.frequency = 0.05; n.fractal_octaves = 4; n.seed = 9
		for y in 128:
			for x in 128:
				var p := Vector2(x - 63.5, y - 63.5) / 63.5
				var d := p.length() + 0.18 * n.get_noise_2d(x, y)
				var a := 1.0 - smoothstep(0.62, 0.95, d)
				var ash := clampf(0.5 + 0.9 * n.get_noise_2d(x * 2.3 + 40, y * 2.3), 0.0, 1.0)
				var col := Color(0.11, 0.095, 0.085).lerp(Color(0.26, 0.25, 0.24), ash * (1.0 - smoothstep(0.3, 0.8, d)))
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
		_ring_img = ImageTexture.create_from_image(img)
	return _ring_img
