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
const STOVE_LOCAL := Vector3(-2.35, 0.0, -1.75)
const WOOD_BURN_S := 300.0  # real seconds per log
var door_open := false
var door_hp := 100.0
var door_broken := false
var stove_fuel_s := 0.0
var wood_pile := 6
var crate_looted := false
var _door_pivot: Node3D
var _door_rect := Rect2(-DOOR_HALF, HZ - 0.06, 2 * DOOR_HALF, 0.12)
var _fire_glow: MeshInstance3D
var _fire_mat: StandardMaterial3D
var _fire_light: OmniLight3D
var _t := 0.0


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
	_build_door()
	_build_stove_fire()
	return true


func _build_door() -> void:
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-DOOR_HALF, FLOOR_LOCAL_Y, HZ)
	add_child(_door_pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2 * DOOR_HALF, 2.05, 0.08)
	mi.mesh = bm
	mi.position = Vector3(DOOR_HALF, 1.025, 0.0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.22, 0.15, 0.10)
	dm.roughness = 0.95
	mi.material_override = dm
	_door_pivot.add_child(mi)


func _build_stove_fire() -> void:
	_fire_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.2)
	_fire_glow.mesh = q
	_fire_glow.position = STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.42, 0.285)
	_fire_mat = StandardMaterial3D.new()
	_fire_mat.albedo_color = Color(0.1, 0.03, 0.01)
	_fire_mat.emission_enabled = true
	_fire_mat.emission = Color(1.0, 0.45, 0.12)
	_fire_mat.emission_energy_multiplier = 0.0
	_fire_glow.material_override = _fire_mat
	add_child(_fire_glow)
	_fire_light = OmniLight3D.new()
	_fire_light.position = STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.55, 0.5)
	_fire_light.light_color = Color(1.0, 0.5, 0.2)
	_fire_light.light_energy = 0.0
	_fire_light.omni_range = 6.0
	_fire_light.shadow_enabled = true
	add_child(_fire_light)


func is_lit() -> bool:
	return stove_fuel_s > 0.0


func add_wood() -> void:
	stove_fuel_s += WOOD_BURN_S


func take_firewood() -> bool:
	if wood_pile <= 0:
		return false
	wood_pile -= 1
	return true


func bash_door(dmg: float) -> void:
	if door_broken or door_open:
		return
	door_hp -= dmg
	_door_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.06) * 0.03 * (1.0 - door_hp / 100.0 + 0.3)
	if door_hp <= 0.0:
		door_broken = true
		door_open = true
		var tw := create_tween()
		tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(120.0), 0.25)


func toggle_door() -> void:
	if door_broken:
		return
	door_open = not door_open
	var tw := create_tween()
	tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(105.0) if door_open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func door_world_pos() -> Vector3:
	return to_global(Vector3(0.0, FLOOR_LOCAL_Y + 1.2, HZ))


func stove_world_pos() -> Vector3:
	return to_global(STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.9, 0.0))


func crate_world_pos() -> Vector3:
	return to_global(Vector3(2.5, FLOOR_LOCAL_Y + 0.5, 1.6))


func woodpile_world_pos() -> Vector3:
	return to_global(Vector3(2.5, FLOOR_LOCAL_Y + 0.5, HZ + 0.55))


## Heat (W) felt at world xz from the stove: strong near it, room-level inside the cabin.
func heat_at(x: float, z: float) -> float:
	if not is_lit():
		return 0.0
	var l := to_local_xz(x, z)
	if absf(l.x) > HX or absf(l.y) > HZ:
		return 0.0
	var d := l.distance_to(Vector2(STOVE_LOCAL.x, STOVE_LOCAL.z))
	return 120.0 + 430.0 * clampf(1.0 - d / 2.5, 0.0, 1.0)


func _process(delta: float) -> void:
	if _fire_mat == null:
		return
	_t += delta
	if stove_fuel_s > 0.0:
		stove_fuel_s = maxf(0.0, stove_fuel_s - delta)
		var fl := 0.75 + 0.25 * sin(_t * 11.0) * sin(_t * 7.3) + 0.1 * sin(_t * 23.0)
		_fire_mat.emission_energy_multiplier = 3.0 * fl
		_fire_light.light_energy = 2.2 * fl
	else:
		_fire_mat.emission_energy_multiplier = 0.0
		_fire_light.light_energy = 0.0


func set_night(f: float) -> void:
	glass_mat.emission_energy_multiplier = 1.2 * f
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
	var rects := _walls.duplicate()
	if not door_open:
		rects.append(_door_rect)
	for w in rects:
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
