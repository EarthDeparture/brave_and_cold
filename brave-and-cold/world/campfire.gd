class_name Campfire
extends Node3D
## Outdoor fire: logs ring, flame particles, flickering light, radiant heat. Fuel is in GAME seconds.

const LOG_BURN_S := 2400.0      # 40 game-minutes per log
const MAX_FUEL_S := 4.0 * 3600.0
const HEAT_W := 480.0
const HEAT_RADIUS := 7.0

var fuel_s := 0.0
var _light: OmniLight3D
var _flames: CPUParticles3D
var _embers: CPUParticles3D
var _flame_mat: StandardMaterial3D
var _t := 0.0
var _phase := randf() * 10.0


func _ready() -> void:
	# stone ring + logs
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.32, 0.31, 0.30)
	stone_mat.roughness = 1.0
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.28, 0.17, 0.09)
	wood_mat.roughness = 0.95
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
	_set_visual(false)


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
	return fuel_s > 0.0


func add_wood(n: int = 1) -> void:
	fuel_s = minf(MAX_FUEL_S, fuel_s + LOG_BURN_S * n)


func heat_at(x: float, z: float) -> float:
	if fuel_s <= 0.0:
		return 0.0
	var d := Vector2(x - global_position.x, z - global_position.z).length()
	if d >= HEAT_RADIUS:
		return 0.0
	var f := 1.0 - d / HEAT_RADIUS
	return HEAT_W * f * f * (0.6 + 0.4 * minf(1.0, fuel_s / 900.0))


func advance(game_s: float) -> void:
	if fuel_s > 0.0:
		fuel_s = maxf(0.0, fuel_s - game_s)
		if fuel_s == 0.0:
			_set_visual(false)


func _set_visual(on: bool) -> void:
	_flames.emitting = on
	_embers.emitting = on
	_light.visible = on


func _process(delta: float) -> void:
	_t += delta
	if fuel_s > 0.0 and not _flames.emitting:
		_set_visual(true)
	if _light.visible:
		var fl := 0.85 + 0.15 * sin(_t * 13.0 + _phase) + 0.1 * sin(_t * 31.0 + _phase * 2.0)
		var low := clampf(fuel_s / 600.0, 0.3, 1.0)
		_light.light_energy = 1.5 * fl * low
		_flames.scale = Vector3.ONE * (0.7 + 0.3 * low)
