class_name Cabin
extends Node3D
## Log cabin instance: model + window glow + interior light + wall collision + interior floor height.
## Local space (Godot): x across (-3.35..3.35), z depth; door on +z wall. Origin sits at foundation base reference.

const MODEL := "res://assets/models/buildings/cabin.glb"
const FLOOR_LOCAL_Y := 0.3
const HX := 3.0
const HZ := 2.5
const WALL_T := 0.36
const DOOR_HALF := 0.55
const RAMP_LEN := 1.6

var floor_y := 0.0  # world y of the interior floor
var glass_mat: StandardMaterial3D
var light: OmniLight3D
var _walls: Array[Rect2] = []  # local xz rects


func setup(terrain: Terrain3D, x: float, z: float, yaw_deg: float) -> bool:
	# pick foundation height from the highest corner so the floor is never buried
	var hmax := -1e9
	var hmin := 1e9
	for cx in [-3.4, 0.0, 3.4]:
		for cz in [-2.9, 0.0, 2.9]:
			var p := Vector3(x, 0, z) + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(cx, 0, cz)
			var h: float = terrain.data.get_height(p)
			if is_nan(h):
				return false
			hmax = maxf(hmax, h)
			hmin = minf(hmin, h)
	position = Vector3(x, hmax - 0.1, z)
	rotation_degrees = Vector3(0, yaw_deg, 0)
	floor_y = position.y + FLOOR_LOCAL_Y
	var scene := load(MODEL) as PackedScene
	var model := scene.instantiate()
	add_child(model)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.25, 0.32, 0.42)
	glass_mat.roughness = 0.2
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(1.0, 0.62, 0.28)
	glass_mat.emission_energy_multiplier = 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("cabin_glass"):
			m.material_override = glass_mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			m.material_override = mat
	light = OmniLight3D.new()
	light.position = Vector3(0.0, FLOOR_LOCAL_Y + 2.2, -0.2)
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.shadow_enabled = true
	add_child(light)
	# wall rects (local xz). Front wall is +z with a door gap.
	var t := WALL_T
	_walls = [
		Rect2(-HX - t, -HZ - t, 2 * HX + 2 * t, 2 * t),                       # back wall (z=-HZ)
		Rect2(-HX - t, HZ - t, HX + t - DOOR_HALF, 2 * t),                    # front-left
		Rect2(DOOR_HALF, HZ - t, HX + t - DOOR_HALF, 2 * t),                  # front-right
		Rect2(-HX - t, -HZ - t, 2 * t, 2 * HZ + 2 * t),                       # left wall
		Rect2(HX - t, -HZ - t, 2 * t, 2 * HZ + 2 * t),                        # right wall
	]
	return true


func set_night(f: float) -> void:
	glass_mat.emission_energy_multiplier = 2.5 * f
	light.light_energy = 1.6 * f + 0.7


func to_local_xz(x: float, z: float) -> Vector2:
	var l := to_local(Vector3(x, position.y, z))
	return Vector2(l.x, l.z)


func contains_xz(x: float, z: float) -> bool:
	var l := to_local_xz(x, z)
	return absf(l.x) < HX - 0.2 and absf(l.y) < HZ - 0.2


## World-space push-out of a circle from the wall rects. Returns corrected (x, z).
func resolve(x: float, z: float, r: float) -> Vector2:
	var l := to_local_xz(x, z)
	var moved := false
	for w in _walls:
		var cx := clampf(l.x, w.position.x, w.end.x)
		var cz := clampf(l.y, w.position.y, w.end.y)
		var d := l - Vector2(cx, cz)
		var dl := d.length()
		if dl < r:
			moved = true
			if dl > 0.0001:
				l = Vector2(cx, cz) + d / dl * r
			else:
				l.x += r
	if not moved:
		return Vector2(x, z)
	var wv := to_global(Vector3(l.x, 0.0, l.y))
	return Vector2(wv.x, wv.z)


## Interior floor height at world xz (NAN if outside). Ramp from the door to terrain so stepping in is smooth.
func floor_at(x: float, z: float, terrain_h: float) -> float:
	var l := to_local_xz(x, z)
	if absf(l.x) < HX - 0.2 and l.y > -HZ + 0.2 and l.y <= HZ - 0.2:
		return floor_y
	if absf(l.x) < DOOR_HALF + 0.2 and l.y > HZ - 0.2 and l.y <= HZ + 0.4:
		return floor_y
	if absf(l.x) < DOOR_HALF + 0.35 and l.y > HZ + 0.4 and l.y < HZ + 0.4 + RAMP_LEN:
		var t := (l.y - (HZ + 0.4)) / RAMP_LEN
		return lerpf(floor_y, terrain_h, t)
	return NAN
