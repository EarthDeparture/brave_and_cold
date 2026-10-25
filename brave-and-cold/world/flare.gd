class_name Flare
extends Node3D
## Road flare: bright red light + sparks for LIFE_S real seconds. Predators within REPEL_RADIUS back off (see Wolf._flare_check).

const LIFE_S := 60.0
const REPEL_RADIUS := 18.0

var _t := 0.0
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _glow: CPUParticles3D


func _ready() -> void:
	add_to_group("flares")
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.018
	cm.height = 0.28
	body.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.75, 0.08, 0.06)
	body.material_override = bm
	body.position = Vector3(0, 0.14, 0)
	body.rotation.z = deg_to_rad(80.0)
	add_child(body)
	_glow = _particles(mat, 6, 0.5, Color(1.0, 0.35, 0.25, 0.9), Color(1.0, 0.1, 0.05, 0.0), 0.9, 0.0, 0.7)
	add_child(_glow)
	_sparks = _particles(mat, 40, 0.9, Color(1.0, 0.75, 0.6, 1.0), Color(1.0, 0.2, 0.1, 0.0), 2.2, 0.06, 0.05)
	_sparks.spread = 70.0
	add_child(_sparks)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.25, 0.15)
	_light.omni_range = 26.0
	_light.light_energy = 3.0
	_light.position = Vector3(0, 0.6, 0)
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = 2.6 + sin(_t * 31.0) * 0.4 + randf() * 0.4
	if _t > LIFE_S - 6.0:
		_light.light_energy *= maxf(0.0, (LIFE_S - _t) / 6.0)
	if _t >= LIFE_S:
		queue_free()


func _particles(mat: StandardMaterial3D, amount: int, life: float, c0: Color, c1: Color, vel: float, size: float, scale_b: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, -2.0, 0)
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	var grad := Gradient.new()
	grad.set_color(0, c0)
	grad.set_color(1, c1)
	p.color_ramp = grad
	var qm := QuadMesh.new()
	qm.size = Vector2(scale_b, scale_b) if size == 0.0 else Vector2(size, size)
	p.mesh = qm
	p.material_override = mat
	p.position = Vector3(0, 0.26, 0)
	return p


func _soft_dot() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
