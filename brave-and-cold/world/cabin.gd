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
const WOOD_BURN_S := 7200.0  # GAME seconds per log (2 h)
static var game_scale := 48.0
var _snd: AudioStreamPlayer3D
var door_open := false
var tint := Color.WHITE   # per-cabin weathering variation (hamlet), multiplies the vertex colours
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
signal event(name: String, pos: Vector3)
var openings: Array[Opening] = []
var door_boards := 0
var door_plank_hp := 40.0
var _door_planks: Node3D
var bus: NoiseBus
var _lt := 0.0
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
	mat.albedo_color = tint * 1.12   # the grain texture below averages ~0.85
	mat.albedo_texture = _grain_tex()
	mat.uv1_triplanar = true          # the generated mesh has no UVs: project the grain from object space
	mat.uv1_scale = Vector3(0.35, 3.2, 0.35)   # stretched vertically => horizontal streaks along the logs on every wall
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
			m.visible = false  # replaced by per-window Opening nodes (real glass, boards, curtains)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			m.material_override = mat
	light = OmniLight3D.new()
	light.position = Vector3(0.0, FLOOR_LOCAL_Y + 2.2, -0.2)
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.shadow_enabled = false
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
	_build_openings()
	_build_dust()
	return true


static var _grain: NoiseTexture2D


## Soft wood-grain / weathering noise (greys 0.68..1.0) multiplied over the vertex colours.
static func _grain_tex() -> Texture2D:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.035
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		var gr := Gradient.new()
		gr.set_color(0, Color(0.66, 0.64, 0.62))
		gr.set_color(1, Color(1.0, 1.0, 1.0))
		var t := NoiseTexture2D.new()
		t.noise = n
		t.width = 256
		t.height = 256
		t.seamless = true
		t.color_ramp = gr
		_grain = t
	return _grain


## A few dozen dust motes hanging in the room: lit by the stove / window light, invisible in the dark.
func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-4.0, -2.0, -3.5), Vector3(8.0, 4.0, 7.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.7, 1.0, 2.2)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.03
	pm.gravity = Vector3(0.0, -0.006, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.2
	pm.turbulence_noise_scale = 1.5
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.08
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.02, 0.02)
	var m := StandardMaterial3D.new()
	var gd := Gradient.new()
	gd.set_color(0, Color(1, 1, 1, 1))
	gd.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = gd
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 16
	gt.height = 16
	m.albedo_texture = gt   # round soft mote, not a square
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.88, 0.76, 0.55)
	m.roughness = 1.0
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0.0, FLOOR_LOCAL_Y + 1.2, 0.0)
	add_child(p)


func _build_openings() -> void:
	# positions from gen_cabin.py (WIN_SIDE / WIN_BACK); blender y -> godot -z
	openings.append(Opening.make(self, "window", 1.2, 0.8, Vector3(HX, 1.75, -0.3), 90.0))
	openings.append(Opening.make(self, "window", 1.2, 0.8, Vector3(-HX, 1.75, -0.3), -90.0))
	openings.append(Opening.make(self, "window", 1.1, 0.8, Vector3(-1.15, 1.75, -HZ), 180.0))
	_apply_glow()


## 0..1 how much stove light escapes: sum of uncovered openings (+ open door), normalised to 3.
func noise_leak() -> float:
	if door_open:
		return 1.0
	for o in openings:
		if o.passable():
			return 1.0
	return 0.35


## Can the segment a->b (world, one end inside) pass through the door gap or an uncovered window?
func sight_line_open(a: Vector3, b: Vector3) -> bool:
	if door_open:
		var la := to_local(a)
		var lb := to_local(b)
		if (la.z > HZ) != (lb.z > HZ):
			var t := (HZ - la.z) / (lb.z - la.z)
			var p := la + (lb - la) * t
			if absf(p.x) < DOOR_HALF and p.y > FLOOR_LOCAL_Y and p.y < 2.4:
				return true
	for o in openings:
		if o.open_fraction() >= 0.5 and o.segment_through(a, b):
			return true
	return false


func emit_light_cue() -> void:
	var sg := light_signal()
	if bus != null and sg > 0.0 and _night > 0.15:
		bus.emit_light(global_position, 8.0 + 28.0 * sg * _night, self)
	elif bus != null and _night <= 0.15 and is_lit():
		bus.emit_smoke(global_position, 24.0, self)


func light_signal() -> float:
	if not is_lit():
		return 0.0
	var sgn := 1.0 if door_open else 0.0
	for o in openings:
		sgn += o.open_fraction()
	return clampf(sgn / 3.0, 0.0, 1.0)


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
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = Sfx.get_stream("fire")
	_snd.unit_size = 3.0
	_snd.max_distance = 25.0
	_snd.volume_db = -6.0
	_snd.position = STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.4, 0.0)
	add_child(_snd)
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
	if door_boards > 0:
		door_plank_hp -= dmg
		_door_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.06) * 0.01
		if door_plank_hp <= 0.0:
			door_boards -= 1
			door_plank_hp = 40.0
			_build_door_planks()
			event.emit("board_break", door_world_pos())
		return
	door_hp -= dmg
	_door_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.06) * 0.03 * (1.0 - door_hp / 100.0 + 0.3)
	if door_hp <= 0.0:
		door_broken = true
		door_open = true
		var tw := create_tween()
		tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(120.0), 0.25)


func add_door_board() -> bool:
	if door_boards >= 3 or door_open or door_broken:
		return false
	door_boards += 1
	door_plank_hp = 40.0
	_build_door_planks()
	return true


func remove_door_board() -> bool:
	if door_boards <= 0:
		return false
	door_boards -= 1
	door_plank_hp = 40.0
	_build_door_planks()
	return true


func _build_door_planks() -> void:
	if _door_planks == null:
		_door_planks = Node3D.new()
		add_child(_door_planks)
	for c in _door_planks.get_children():
		c.queue_free()
	var wm := Opening.wood_material()
	for i in door_boards:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.5, 0.17, 0.045)
		mi.mesh = bm
		mi.material_override = wm
		mi.position = Vector3(0.0, FLOOR_LOCAL_Y + 0.55 + 0.6 * float(i), HZ - 0.22)
		mi.rotation.z = deg_to_rad(float((i * 5) % 7) - 3.0)
		_door_planks.add_child(mi)


func door_inside_pos() -> Vector3:
	return to_global(Vector3(0.0, FLOOR_LOCAL_Y + 1.0, HZ - 0.9))


func toggle_door() -> void:
	if door_broken or door_boards > 0:
		return
	door_open = not door_open
	var tw := create_tween()
	tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(105.0) if door_open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func door_world_pos() -> Vector3:
	return to_global(Vector3(0.0, FLOOR_LOCAL_Y + 1.2, HZ))


func stove_world_pos() -> Vector3:
	return to_global(STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.9, 0.0))


## Mattress top (back-right corner, matches gen_cabin.py bed) and the eye spot when lying on it.
func bed_world_pos() -> Vector3:
	return to_global(Vector3(2.0, FLOOR_LOCAL_Y + 0.5, -1.65))


func bed_lie_pos() -> Vector3:
	return to_global(Vector3(1.85, FLOOR_LOCAL_Y + 0.46 + 0.3, -1.65))


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
	if _snd != null:
		if stove_fuel_s > 0.0 and not _snd.playing:
			_snd.play()
		elif stove_fuel_s <= 0.0 and _snd.playing:
			_snd.stop()
	if (stove_fuel_s > 0.0) != _was_lit:
		_was_lit = stove_fuel_s > 0.0
		_apply_glow()
	if stove_fuel_s > 0.0:
		stove_fuel_s = maxf(0.0, stove_fuel_s - delta * game_scale)
		var fl := 0.75 + 0.25 * sin(_t * 11.0) * sin(_t * 7.3) + 0.1 * sin(_t * 23.0)
		_fire_mat.emission_energy_multiplier = 3.0 * fl
		_fire_light.light_energy = 2.2 * fl
	else:
		_fire_mat.emission_energy_multiplier = 0.0
		_fire_light.light_energy = 0.0
	_lt += delta
	if _lt > 2.0:
		_lt = 0.0
		emit_light_cue()


var _night := 0.0
var _was_lit := false


func set_night(f: float) -> void:
	_night = f
	_apply_glow()


func _apply_glow() -> void:
	var lit := 1.0 if stove_fuel_s > 0.0 else 0.0
	glass_mat.emission_energy_multiplier = 0.1 + 1.4 * _night + 1.1 * lit
	light.light_energy = 0.1 + 0.9 * _night + 0.7 * lit
	for o in openings:
		o.set_glow(0.1 + 1.4 * _night + 1.1 * lit)


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
