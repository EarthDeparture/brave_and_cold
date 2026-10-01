class_name SnowFall
extends GPUParticles3D
## Falling snow around the player. World-space particles in a box that follows the camera; density and wind come from Weather.

var follow: Node3D
var weather: Weather
const MAX_AMOUNT := 12000
var _pm: ParticleProcessMaterial
var _placed := false


func _ready() -> void:
	amount = MAX_AMOUNT
	lifetime = 4.0
	preprocess = 4.0
	local_coords = false
	fixed_fps = 0
	visibility_aabb = AABB(Vector3(-24, -16, -24), Vector3(48, 32, 48))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pm = ParticleProcessMaterial.new()
	_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_pm.emission_box_extents = Vector3(13.0, 7.0, 13.0)
	_pm.direction = Vector3(0, -1, 0)
	_pm.spread = 8.0
	_pm.initial_velocity_min = 2.2
	_pm.initial_velocity_max = 3.6
	_pm.gravity = Vector3(0.0, -0.5, 0.0)
	_pm.turbulence_enabled = true
	_pm.turbulence_noise_strength = 0.8
	_pm.turbulence_noise_scale = 2.5
	_pm.turbulence_influence_min = 0.03
	_pm.turbulence_influence_max = 0.09
	_pm.scale_min = 0.6
	_pm.scale_max = 1.4
	process_material = _pm
	var q := QuadMesh.new()
	q.size = Vector2(0.10, 0.10)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	m.disable_receive_shadows = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 1))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.5
	m.distance_fade_max_distance = 2.5
	q.material = m
	draw_pass_1 = q
	emitting = false


func _process(_delta: float) -> void:
	if follow == null or weather == null:
		return
	var p := weather.precip
	emitting = p > 0.02
	amount_ratio = clampf(p, 0.05, 1.0)
	var wd := weather.wind_dir * weather.wind
	_pm.gravity = Vector3(wd.x * 0.35, -0.5 - 0.6 * p, wd.y * 0.35)
	_pm.initial_velocity_max = 3.6 + weather.wind * 0.12
	global_position = follow.global_position + Vector3(0.0, 6.0, 0.0) - Vector3(wd.x, 0.0, wd.y) * 0.6
	if not _placed:
		_placed = true
		restart()
