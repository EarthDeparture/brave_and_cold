class_name Campfire
extends Node3D
## Outdoor fire: logs ring, flame particles, flickering light. All rules (fuel,
## embers, cooking, water, heat, beacon) are the shared FireSource "campfire" type.
var fire := FireSource.new("campfire")
var fuel_s: float:
	get: return fire.fuel_s
	set(v): fire.set_fuel(v)
var prepared_water: PreparedWater:
	get: return fire.water
var cooking: CookBatch:
	get: return fire.cooking
var _light: OmniLight3D
var _flames: CPUParticles3D
var _embers: CPUParticles3D
var _flame_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D
var _ash: MeshInstance3D
var smoke: GPUParticles3D
var _t := 0.0
var _phase := randf() * 10.0
var _snd: AudioStreamPlayer3D


func _ready() -> void:
	# stone ring + logs
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.32, 0.31, 0.30)
	stone_mat.roughness = 1.0
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.28, 0.17, 0.09)
	wood_mat.roughness = 0.95
	wood_mat.emission_enabled = true  # coal glow: under the flames, and alone on embers
	wood_mat.emission = Color(0.95, 0.20, 0.03)
	wood_mat.emission_energy_multiplier = 0.0
	var cracks := NoiseTexture2D.new()  # glowing cracks in charred wood, not neon logs
	cracks.width = 64; cracks.height = 128; cracks.seamless = true
	var fn := FastNoiseLite.new(); fn.frequency = 0.11; fn.fractal_octaves = 3; cracks.noise = fn
	var ramp := Gradient.new(); ramp.offsets = PackedFloat32Array([0.0, 0.52, 0.78]); ramp.colors = PackedColorArray([Color.BLACK, Color.BLACK, Color.WHITE])
	cracks.color_ramp = ramp
	wood_mat.emission_texture = cracks
	_wood_mat = wood_mat
	for i in range(9):
		var a := TAU * i / 9.0
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.10
		s.mesh = sm
		s.material_override = stone_mat
		s.position = Vector3(cos(a) * 0.52, 0.05, sin(a) * 0.52)
		s.rotation.y = a
		add_child(s)
	for i in range(4):
		var l := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.055
		cm.bottom_radius = 0.065
		cm.height = 0.75
		l.mesh = cm
		l.material_override = wood_mat
		l.rotation = Vector3(0.0, TAU * i / 4.0 + 0.4, deg_to_rad(72.0))
		l.position = Vector3(0, 0.12, 0)
		add_child(l)
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_flame_mat.vertex_color_use_as_albedo = true
	_flame_mat.albedo_texture = _soft_dot()
	_flame_mat.billboard_keep_scale = true
	_flames = _make_particles(80, 0.9, 0.5, Color(1.0, 0.6, 0.15, 0.8), Color(0.9, 0.2, 0.05, 0.0), 1.3, 0.2)
	add_child(_flames)
	_embers = _make_particles(18, 2.4, 0.0, Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.3, 0.1, 0.0), 2.4, 0.035)
	_embers.spread = 40.0
	add_child(_embers)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.28)
	_light.omni_range = 14.0
	_light.position = Vector3(0, 0.9, 0)
	_light.shadow_enabled = false
	add_child(_light)
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = Sfx.get_stream("fire")
	_snd.unit_size = 5.0
	_snd.max_distance = 45.0
	_snd.volume_db = -4.0
	_snd.position = Vector3(0, 0.4, 0)
	add_child(_snd)
	# Ash bed: shows once the fire has gone cold; logs char while burning down.
	_ash = MeshInstance3D.new(); var disc := CylinderMesh.new(); disc.top_radius = 0.44; disc.bottom_radius = 0.50; disc.height = 0.03; disc.radial_segments = 14
	_ash.mesh = disc; _ash.position = Vector3(0, 0.012, 0)
	var ash_mat := StandardMaterial3D.new(); ash_mat.albedo_color = Color(0.17, 0.16, 0.15); ash_mat.roughness = 1.0; _ash.material_override = ash_mat
	add_child(_ash); _ash.visible = false
	smoke = FireVisual.smoke(self, Vector3(0, 1.0, 0), 14, 1.3)
	_set_visual(false, false)


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _make_particles(n: int, life: float, _unused: float, c0: Color, c1: Color, vel: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.local_coords = false
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.16
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.4
	var g := Gradient.new()
	g.colors = PackedColorArray([c0, c1])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _flame_mat
	p.mesh = q
	p.position = Vector3(0, 0.2, 0)
	return p


func is_lit() -> bool:
	return fire.is_lit()


## Scripted fuel only (tests/dev); players stoke through FireSource.stoke.
func add_wood(n: int = 1) -> void:
	fire.add_fuel("wood", n)


func heat_at(x: float, z: float) -> float:
	return fire.heat_at(Vector2(x - global_position.x, z - global_position.z).length())


func free_slots() -> int:
	return fire.cooking.free_slots()


func start_cook(cooked_id: String, input_id: String = "", age: float = 0) -> bool:
	if free_slots() <= 0:
		return false
	fire.cooking.portions.append(FoodPortion.create(input_id if input_id != "" else cooked_id, cooked_id, CookBatch.COOK_S, age))
	return true


func cooking_count() -> int:
	return fire.cooking.portions.size() - fire.cooking.ready_count()


func done_count() -> int:
	return fire.cooking.ready_count()


func min_left() -> float:
	var m := 1e9
	for c: Dictionary in fire.cooking.portions:
		if float(c.remaining_s) > 0.0:
			m = minf(m, float(c.remaining_s))
	return m


## Snow or rain on an open fire shortens its embers (ember_rate > 1).
func advance(game_s: float, ember_rate: float = 1.0) -> void:
	fire.advance(game_s, ember_rate)


## Pre-standard saves stored [{id, t, age_s, ...}] per fire.
static func legacy_cook(rows: Array) -> Dictionary:
	var out: Array = []
	for c: Variant in rows:
		if c is Dictionary:
			var p: Dictionary = (c as Dictionary).duplicate(true)
			p.remaining_s = float(p.get("t", p.get("remaining_s", 0)))
			p.erase("t")
			out.append(p)
	return {"portions": out}


func _set_visual(flames: bool, embers: bool) -> void:
	_flames.emitting = flames
	_embers.emitting = flames or embers
	_light.visible = flames or embers
	if flames and not _snd.playing:
		_snd.play()
	elif not flames and _snd.playing:
		_snd.stop()


func _process(delta: float) -> void:
	_t += delta
	var flames := fire.is_lit()
	var embers := fire.has_embers()
	if flames != _flames.emitting or (flames or embers) != _light.visible:
		_set_visual(flames, embers)
	if _light.visible:
		var fl := 0.85 + 0.15 * sin(_t * 13.0 + _phase) + 0.1 * sin(_t * 31.0 + _phase * 2.0)
		_light.light_energy = 1.5 * fl * fire.glow()
		_flames.scale = Vector3.ONE * (0.55 + 0.45 * minf(1.0, fire.fuel_s / 3600.0))
	if _ash != null:
		_ash.visible = fire.needs_starter()
	if _wood_mat != null:
		_wood_mat.albedo_color = Color(0.28, 0.17, 0.09) if flames else Color(0.07, 0.06, 0.055)  # charred once burnt down
		_wood_mat.emission_energy_multiplier = (0.35 if flames else 0.85 * fire.glow() / 0.24) * (0.8 + 0.2 * sin(_t * 1.7 + _phase))
