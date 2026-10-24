class_name RootCellar
extends Node3D
## A7: a root cellar dug under one hamlet cabin floor. A hinged board hatch with an iron ring;
## opening it shows the earth pit (cellar_pit.gdshader, interior mapping, no hole cut in the
## floor) and the store below. The store is a hidden StorageChest held at a fixed 2 C: food keeps
## the same pace whatever the weather or the stove (slower than a heated room, faster than a box
## in deep frost). Underground, it survives the cabin burning, and ransackers never find it.
## Child of the cabin (local space); the world ticks it and saves it as 'cellar'.

const LOCAL := Vector3(0.7, 0.0, -0.2)   # hatch centre, cabin local xz (y = Cabin.FLOOR_LOCAL_Y)
const OPEN_W := 0.8                       # shaft width
const LID := 0.88
const DEPTH := 1.6
const TEMP_C := 2.0
const OPEN_DEG := 100.0
const BOARD_TOP := 0.015   # gen_cabin floor planks: top 15 mm above FLOOR_LOCAL_Y
const WOOD_COL := Color(0.30, 0.215, 0.145)   # a shade darker than the floor boards round it (newer, less worn)

var cabin: Cabin
var store: StorageChest
var want_open := false
var hold_open := false   # captures / debug: keep the hatch up without the gear screen
var lid_k := 0.0
var _lid: Node3D
var _pit: MeshInstance3D
var _pit_mat: ShaderMaterial
var _wood: StandardMaterial3D
var _was_burned := false


## Pick the cellar cabin: a hamlet cabin that is not the start cabin and not a resident home
## (TownLife takes hamlet[1] and hamlet[3]).
static func pick(cabins: Array) -> Cabin:
	var hamlet: Array = []
	for cb in cabins:
		if cb != cabins[0]: hamlet.append(cb)
	if hamlet.is_empty(): return null
	return hamlet[2] if hamlet.size() > 3 else hamlet[0]


func setup(cb: Cabin, saved: Dictionary, seed_v: int) -> void:
	cabin = cb
	name = "RootCellar"
	cb.add_child(self)
	position = Vector3(LOCAL.x, Cabin.FLOOR_LOCAL_Y, LOCAL.z)
	_build()
	store = StorageChest.new()
	store.visual_enabled = false
	store.listed = false
	store.fixed_c = TEMP_C
	store.label = "ROOT CELLAR  2 °C"
	add_child(store)
	store.position = Vector3(0.0, -1.2, 0.0)
	if saved.has("store"):
		store.load_dict(saved["store"])
	else:   # someone's winter stores, left behind
		var r := RandomNumberGenerator.new()
		r.seed = seed_v * 7919 + 4417
		store.put("beans", r.randi_range(1, 3), 1.0, 0.0)
		if r.randf() < 0.5: store.put("rag", r.randi_range(1, 2), 0.7, 0.0)
	_apply_burn()


func to_dict() -> Dictionary:
	return {"store": store.to_dict()}


func rate() -> float:
	return Spoilage.rate_c(store.fixed_c)


func hatch_world_pos() -> Vector3:
	return to_global(Vector3(0.0, 0.08, 0.0))


func label() -> String:
	return "Open root cellar (2 °C, %d stacks)" % store.stack_count() if not store.is_empty() else "Open root cellar (2 °C, empty)"


func tick(game_s: float) -> void:
	store.spoilage_rate = rate()
	store.tick(game_s)


func _process(delta: float) -> void:
	if cabin != null and cabin.burned != _was_burned: _apply_burn()
	var tgt := 1.0 if want_open or hold_open else 0.0
	if is_equal_approx(lid_k, tgt): return
	lid_k = move_toward(lid_k, tgt, delta * 2.2)
	var e := lid_k * lid_k * (3.0 - 2.0 * lid_k)
	_lid.rotation.x = -deg_to_rad(OPEN_DEG) * e   # the far edge (ring) lifts toward +y
	_pit.visible = lid_k > 0.02


func _apply_burn() -> void:
	_was_burned = cabin != null and cabin.burned
	_wood.albedo_color = Color(0.07, 0.065, 0.06) if _was_burned else WOOD_COL
	_pit_mat.set_shader_parameter("char_k", 1.0 if _was_burned else 0.0)


func _build() -> void:
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = WOOD_COL
	_wood.albedo_texture = Cabin._grain_tex()
	_wood.uv1_triplanar = true
	_wood.uv1_scale = Vector3(5.0, 5.0, 0.7)   # grain stretched along the boards (z)
	_wood.roughness = 0.9
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.2, 0.15, 0.1)
	frame.roughness = 0.95
	# the pit (only drawn while the hatch is up)
	_pit_mat = ShaderMaterial.new()
	_pit_mat.shader = load("res://world/shaders/cellar_pit.gdshader")
	_pit_mat.set_shader_parameter("depth", DEPTH)
	_pit_mat.set_shader_parameter("half_w", OPEN_W * 0.5)
	var pm := PlaneMesh.new()
	pm.size = Vector2(OPEN_W, OPEN_W)
	_pit = MeshInstance3D.new()
	_pit.mesh = pm
	_pit.material_override = _pit_mat
	_pit.position = Vector3(0, BOARD_TOP + 0.003, 0)
	_pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pit.visible = false
	add_child(_pit)
	# frame boards round the opening, flush with the floor
	var fw := (LID - OPEN_W) * 0.5 + 0.03
	for s in [-1.0, 1.0]:
		_box(Vector3(LID + 0.06, 0.012, fw), Vector3(0, BOARD_TOP + 0.006, s * (OPEN_W * 0.5 + fw * 0.5 - 0.01)), frame, self)
		_box(Vector3(fw, 0.012, OPEN_W), Vector3(s * (OPEN_W * 0.5 + fw * 0.5 - 0.01), BOARD_TOP + 0.006, 0), frame, self)
	# the lid: hinged on its -z edge, four boards on two battens, an iron ring
	_lid = Node3D.new()
	_lid.position = Vector3(0, BOARD_TOP + 0.012, -LID * 0.5)
	add_child(_lid)
	var bw := LID / 4.0
	for i in 4:
		var mi := _box(Vector3(bw - 0.008, 0.028, LID), Vector3(-LID * 0.5 + bw * (i + 0.5), 0.014, LID * 0.5), _wood, _lid)
		mi.rotation.y = (float((i * 5) % 3) - 1.0) * 0.004
	for bz in [0.16, LID - 0.16]:
		_box(Vector3(LID - 0.1, 0.02, 0.07), Vector3(0, -0.006, bz), _wood, _lid)   # battens under (seen when open)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.1, 0.1)
	iron.metallic = 0.7
	iron.roughness = 0.55
	var tor := TorusMesh.new()
	tor.inner_radius = 0.032
	tor.outer_radius = 0.042
	var ring := MeshInstance3D.new()
	ring.mesh = tor
	ring.material_override = iron
	ring.position = Vector3(0, 0.03, LID - 0.12)
	_lid.add_child(ring)
	_box(Vector3(0.05, 0.008, 0.03), Vector3(0, 0.03, LID - 0.075), iron, _lid)
	for hx in [-0.28, 0.28]:   # strap hinges
		_box(Vector3(0.05, 0.006, 0.16), Vector3(hx, 0.03, 0.07), iron, _lid)


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
