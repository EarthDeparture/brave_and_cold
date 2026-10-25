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
const RACK_LOCAL := Vector3(-HX + 0.30, 0.25, -0.55)  # wall-mounted drying rack beside the stove
var _snd: AudioStreamPlayer3D
var door_open := false
var tint := Color.WHITE   # per-cabin weathering variation (hamlet), multiplies the vertex colours
var door_hp := 100.0
var door_broken := false
## Stove rules are the shared FireSource "wood_stove" (identical to the lookout stove).
var fire := FireSource.new("wood_stove")
var stove_fuel_s: float:
	get: return fire.fuel_s
	set(v): fire.set_fuel(v)
var prepared_water: PreparedWater:
	get: return fire.water
var cooking: CookBatch:
	get: return fire.cooking
var cook_display:CookDisplay
var drying_rack: Node3D
var interior: InteriorLighting
## Breakable furniture: gen_cabin.py Furn_* nodes (Blender x,y,z -> Godot x,z,-y).
## Breaking it down is the TLD reclaimed-wood loop: planks burn 1 h in a stove.
const FURNITURE := {
	"Furn_table": {"name": "table", "at": Vector3(-1.6, 1.04, 0.9), "plank": 3, "stick": 2, "hold": 10.0},
	"Furn_stool_a": {"name": "stool", "at": Vector3(-1.9, 0.72, 1.6), "plank": 1, "stick": 2, "hold": 5.0},
	"Furn_stool_b": {"name": "stool", "at": Vector3(-1.2, 0.72, 0.18), "plank": 1, "stick": 2, "hold": 5.0},
}
var broken: Array = []
var toppled: Array = []
var burned := false        # A4 E2: the roof is gone (CabinFire): no shelter from snow or cold, only from wind
var on_fire: Node = null   # the CabinFire while / after it burns   # A4 ransack: knocked over, not destroyed (still breakable for planks)
var _furniture := {}
var wood_pile := 6
var crate_looted := false
var _door_pivot: Node3D
var _door_rect := Rect2(-DOOR_HALF, HZ - 0.06, 2 * DOOR_HALF, 0.12)
var _fire_glow: MeshInstance3D
var smoke: GPUParticles3D


func _set_ember(k: float) -> void:
	(_fire_glow.material_override as ShaderMaterial).set_shader_parameter("intensity", k)
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
	for id: String in FURNITURE:
		var node := model.find_child(id, true, false) as Node3D
		if node != null: _furniture[id] = node
	var mat := wood_material(tint)
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
	cook_display=CookDisplay.new();add_child(cook_display);cook_display.build(2)
	cook_display.position=STOVE_LOCAL+Vector3(0,FLOOR_LOCAL_Y+.852,.13)
	drying_rack=(load("res://assets/food_preservation/stove_drying_rack.glb") as PackedScene).instantiate()
	add_child(drying_rack);drying_rack.position=RACK_LOCAL+Vector3(0,FLOOR_LOCAL_Y,0);drying_rack.rotation.y=PI/2
	refresh_fire()
	_build_openings()
	interior = InteriorLighting.new(); add_child(interior)
	interior.build(openings, Vector3(0, FLOOR_LOCAL_Y + 1.6, 0), maxf(HX, HZ), fire, STOVE_LOCAL + Vector3(0, FLOOR_LOCAL_Y, 0))
	_build_dust()
	return true


static var _grain: NoiseTexture2D
static var _wood_shader: Shader


## W1: the cabin's one material. Procedural boards / logs / knots / grime in object space
## (building_wood.gdshader) over the vertex colours; the mesh has no UVs.
static func wood_material(t: Color) -> ShaderMaterial:
	if _wood_shader == null:
		_wood_shader = load("res://world/shaders/building_wood.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _wood_shader
	m.set_shader_parameter("tint", t)
	m.set_shader_parameter("noise_tex", _grain_tex())
	m.set_shader_parameter("floor_top", FLOOR_LOCAL_Y)
	m.set_shader_parameter("door_xz", Vector2(0.0, HZ))
	m.set_shader_parameter("stove_xz", Vector2(STOVE_LOCAL.x, STOVE_LOCAL.z))
	return m


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


var cue_suppressed := false   # a resident's own stove before the outbreak (TownLife): homes are lit, nobody is hunting yet
func emit_light_cue() -> void:
	if burned: return
	if cue_suppressed:
		return
	fire.cue(bus, global_position, _night, light_signal(), self)


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
	# Same coal-bed ember window as the lookout stove (FireVisual), not a flat emissive quad.
	_fire_glow = FireVisual.ember_window(Vector2(0.26, 0.2))
	_fire_glow.position = STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.42, 0.285)
	add_child(_fire_glow)
	_set_ember(0.0)
	# gen_cabin.py: stove pipe tops out 1 m above the 4.27 m ridge
	smoke = FireVisual.smoke(self, Vector3(STOVE_LOCAL.x, 5.35, STOVE_LOCAL.z))
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = Sfx.get_stream("fire")
	_snd.unit_size = 3.0
	_snd.max_distance = 25.0
	_snd.volume_db = -6.0
	_snd.position = STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.4, 0.0)
	add_child(_snd)
	_fire_light = OmniLight3D.new()
	_fire_light.position = STOVE_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.55, 0.5)
	_fire_light.light_color = Color(1.0, 0.62, 0.36)  # amber, less red
	_fire_light.light_energy = 0.0
	_fire_light.omni_range = 6.0
	_fire_light.shadow_enabled = true
	add_child(_fire_light)


func is_lit() -> bool:
	return fire.is_lit()


## Scripted fuel only (tests/dev); players stoke through FireSource.stoke.
func add_wood() -> void:
	fire.add_fuel("wood")


func furniture_world_pos(id: String) -> Vector3:
	return to_global(FURNITURE[id].at)


func break_furniture(id: String) -> void:
	if id in broken or not FURNITURE.has(id): return
	broken.append(id)
	if _furniture.has(id): (_furniture[id] as Node3D).visible = false


## Knock a piece over where it stands: a stool on its side, the table on two legs against the floor.
func topple_furniture(id: String) -> void:
	if id in toppled or id in broken or not FURNITURE.has(id): return
	toppled.append(id)
	if not _furniture.has(id): return
	var n := _furniture[id] as Node3D
	var h: float = float(FURNITURE[id].at.y) - FLOOR_LOCAL_Y   # pivot height above the floor
	var side := 1.0 if (hash(id) % 2) == 0 else -1.0
	var ang := PI / 2 * 0.98 if FURNITURE[id].name == "stool" else 1.25
	n.rotate_object_local(Vector3(0, 0, 1) if FURNITURE[id].name == "stool" else Vector3(1, 0, 0), ang * side)
	n.position.y -= h * (0.55 if FURNITURE[id].name == "stool" else 0.55)


func apply_toppled(ids: Array) -> void:
	for id: Variant in ids:
		topple_furniture(String(id))


var litter_seed := 0   # A4 ransack: tins, rags and a broken plank or two on the floor (0 = none). Saved.
func scatter_litter(sd: int) -> void:
	if litter_seed != 0 or sd == 0: return
	litter_seed = sd
	var r := RandomNumberGenerator.new(); r.seed = sd
	var root := Node3D.new(); root.name = "Litter"; add_child(root)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.36, 0.25, 0.16); wood.roughness = 0.9
	var tin := StandardMaterial3D.new(); tin.albedo_color = Color(0.62, 0.62, 0.6); tin.metallic = 0.7; tin.roughness = 0.45
	var cloth := StandardMaterial3D.new(); cloth.albedo_color = Color(0.42, 0.18, 0.14); cloth.roughness = 1.0
	for id in broken:   # what was smashed leaves its planks where it stood
		var at: Vector3 = FURNITURE[id].at
		for k in 3:
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(r.randf_range(0.35, 0.7), 0.025, 0.09)
			m.mesh = bm; m.material_override = wood
			root.add_child(m)
			m.position = Vector3(at.x + r.randf_range(-0.4, 0.4), FLOOR_LOCAL_Y + 0.015 + k * 0.026, at.z + r.randf_range(-0.4, 0.4))
			m.rotation = Vector3(0, r.randf() * TAU, r.randf_range(-0.08, 0.08))
	for k in r.randi_range(3, 6):   # emptied tins and rags thrown down
		var m := MeshInstance3D.new()
		if r.randf() < 0.6:
			var cm := CylinderMesh.new(); cm.top_radius = 0.04; cm.bottom_radius = 0.04; cm.height = 0.11; cm.radial_segments = 10
			m.mesh = cm; m.material_override = tin
			m.rotation = Vector3(PI / 2, r.randf() * TAU, 0)
			m.position.y = FLOOR_LOCAL_Y + 0.04
		else:
			var bm2 := BoxMesh.new(); bm2.size = Vector3(r.randf_range(0.2, 0.35), 0.012, r.randf_range(0.12, 0.25))
			m.mesh = bm2; m.material_override = cloth
			m.rotation.y = r.randf() * TAU
			m.position.y = FLOOR_LOCAL_Y + 0.008
		root.add_child(m)
		m.position.x = r.randf_range(-HX + 0.6, HX - 0.6)
		m.position.z = r.randf_range(-HZ + 0.6, HZ - 0.6)


## Forced open (A4 ransack): the same end state as a door bashed in.
func break_door() -> void:
	if door_broken: return
	door_hp = 0.0
	door_broken = true
	door_open = true
	if _door_pivot != null: _door_pivot.rotation.y = deg_to_rad(120.0)


func apply_broken(ids: Array) -> void:
	for id: Variant in ids:
		break_furniture(String(id))


func rack_world_pos() -> Vector3:
	return to_global(RACK_LOCAL + Vector3(0.0, FLOOR_LOCAL_Y + 0.4, 0.0))


## Pans and rack strips follow the fire's reserved food.
func refresh_fire() -> void:
	if cook_display != null:
		cook_display.sync(cooking.portions)
	if drying_rack != null and fire.rack != null:
		FoodPreservation.sync_model(drying_rack, fire.rack)


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
	var l := to_local_xz(x, z)
	if absf(l.x) > HX or absf(l.y) > HZ:
		return 0.0
	return fire.heat_at(l.distance_to(Vector2(STOVE_LOCAL.x, STOVE_LOCAL.z)), true)


func advance(game_s:float) -> void:
	fire.advance(game_s)
	refresh_fire()

func _process(delta: float) -> void:
	if _fire_glow == null:
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
	var glow := fire.glow()
	if glow > 0.0:
		var fl := 0.75 + 0.25 * sin(_t * 11.0) * sin(_t * 7.3) + 0.1 * sin(_t * 23.0)
		_set_ember(clampf(fl * glow, 0.0, 1.2))
		_fire_light.light_energy = 1.7 * fl * glow
	else:
		_set_ember(0.0)
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
	light.light_energy = 0.05 + 0.25 * _night + 0.45 * lit  # room bounce now comes from InteriorLighting; this only feeds the glow
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


## Head clearance for the custom controller; does not affect the walking floor.
func ceiling_at_world(eye: Vector3) -> float:
	if burned: return INF
	var p := to_local(eye)
	if absf(p.x) < DOOR_HALF + 0.20 and absf(p.z - HZ) < 0.30:
		return global_position.y + 2.35
	if absf(p.x) > HX or absf(p.z) > HZ: return INF
	var roof := global_position.y + 2.63 + 1.55 * (1.0 - absf(p.z) / 3.25)
	for beam_x in [-2.4, 0.0, 2.4]:
		if absf(p.x - beam_x) < 0.16: roof = minf(roof, global_position.y + 2.79)
	return roof
