class_name SnowFall
extends GPUParticles3D
## Falling snow around the player. World-space particles in a box that follows the camera; density and wind come from Weather.

var follow: Node3D
var weather: Weather
## Returns the buildings (Array of Node3D) whose roofs must stop the snow. Set by GameWorld.
var buildings: Callable
## Visual layer 20 carries "this mesh shelters you". The heightfield below only sees that layer, so trees and ground
## do not eat snow; every building's meshes get the bit (their normal layer 1 is untouched).
const COVER_BIT := 1 << 19
const HF_SIZE := Vector3(64.0, 44.0, 64.0)
const HF_SNAP := 8.0
var _hf: GPUParticlesCollisionHeightField3D
var _tagged: Dictionary = {}
var _tag_t := 0.0
var _refresh := 0
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
	_pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT   # dies on a roof, on the ceiling it is under, anywhere under cover
	process_material = _pm
	_hf = GPUParticlesCollisionHeightField3D.new()
	_hf.top_level = true
	_hf.size = HF_SIZE
	_hf.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_1024
	_hf.heightfield_mask = COVER_BIT
	_hf.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
	add_child(_hf)
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


## Give every building mesh the cover bit. New buildings (late spawns, tests) are picked up within a couple of seconds.
func _tag_buildings() -> void:
	if not buildings.is_valid():
		return
	for b in buildings.call():
		var bn := b as Node3D
		if bn == null or not is_instance_valid(bn) or _tagged.has(bn.get_instance_id()):
			continue
		_tagged[bn.get_instance_id()] = true
		for gi in bn.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).layers |= COVER_BIT
		_refresh = 3   # re-render the heightfield with the new roofs


func _process(delta: float) -> void:
	if follow == null or weather == null:
		return
	_tag_t -= delta
	if _tag_t <= 0.0:
		_tag_t = 2.0
		_tag_buildings()
	# the collider tracks the player on a coarse grid (re-render only when it jumps), centred so roofs 20 m up and the ground fit
	var fp := follow.global_position
	var snapped := Vector3(roundf(fp.x / HF_SNAP) * HF_SNAP, roundf((fp.y + 8.0) / 4.0) * 4.0, roundf(fp.z / HF_SNAP) * HF_SNAP)
	if _hf != null:
		_hf.global_position = snapped
		if _refresh > 0:
			_refresh -= 1
			_hf.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS
		else:
			_hf.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
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
