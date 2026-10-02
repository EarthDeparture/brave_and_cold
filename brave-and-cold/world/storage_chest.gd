class_name StorageChest
extends Node3D
## Craftable wooden storage chest (Blender model chest.glb, lid pivots on the hinge). Holds up to CAP stacks.
## Remembers wear and age of what it holds. Perishables age at COLD_RATE of normal (a box out in the snow).
## Solid for the player (rect collider like Outbuilding). Node origin is on the ground.

const MODEL := "res://assets/models/props/chest.glb"
const CAP := 24
const HX := 0.47        # collider half extents
const HZ := 0.31
const COLD_RATE := 0.35
const LID_OPEN_DEG := 105.0
const W := 0.9
const D := 0.55
const H := 0.5

var contents: Dictionary = {}   # id -> n
var cond: Dictionary = {}       # id -> condition 0..1 (only when worn)
var age: Dictionary = {}        # id -> age seconds (perishables)
var want_open := false          # set by GameWorld while the gear screen is on this chest
var lid_k := 0.0                # 0 shut .. 1 open
var _lid: Node3D


func _ready() -> void:
	add_to_group("chests")
	_build()


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if ResourceLoader.exists(MODEL):
		var root := (load(MODEL) as PackedScene).instantiate()
		add_child(root)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
		_lid = root.find_child("chest_lid", true, false) as Node3D
	if _lid == null:
		_build_fallback(mat)
	# trampled patch of bare ground under it
	var pm := CylinderMesh.new()
	pm.top_radius = 0.78
	pm.bottom_radius = 0.82
	pm.height = 0.02
	pm.radial_segments = 20
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.27, 0.25, 0.24)
	pmat.roughness = 1.0
	var patch := MeshInstance3D.new()
	patch.mesh = pm
	patch.material_override = pmat
	patch.position = Vector3(0, 0.03, 0)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(patch)


func _build_fallback(mat: Material) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.23, 0.14)
	wood.roughness = 0.92
	_box(Vector3(W, H, D), Vector3(0, H * 0.5, 0), wood, self)
	_lid = Node3D.new()
	_lid.position = Vector3(0, H, -D * 0.5)
	add_child(_lid)
	_box(Vector3(W + 0.03, 0.12, D + 0.03), Vector3(0, 0.06, D * 0.5), wood, _lid)


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _process(delta: float) -> void:
	var tgt := 1.0 if want_open else 0.0
	if is_equal_approx(lid_k, tgt):
		return
	lid_k = move_toward(lid_k, tgt, delta * 2.6)
	if _lid != null:
		var e := lid_k * lid_k * (3.0 - 2.0 * lid_k)
		_lid.rotation.x = -deg_to_rad(LID_OPEN_DEG) * e


func center_world() -> Vector3:
	return global_position + Vector3(0.0, 0.35, 0.0)


## Push a circle (world x,z,r) out of the chest footprint. Returns corrected (x, z).
func resolve(x: float, z: float, r: float) -> Vector2:
	var l := to_local(Vector3(x, global_position.y, z))
	var cx := clampf(l.x, -HX, HX)
	var cz := clampf(l.z, -HZ, HZ)
	var dv := Vector2(l.x - cx, l.z - cz)
	var dl := dv.length()
	if dl >= r:
		return Vector2(x, z)
	if dl > 0.0001:
		dv = dv / dl * r
		l.x = cx + dv.x
		l.z = cz + dv.y
	else:
		var px := HX - absf(l.x)
		var pz := HZ - absf(l.z)
		if px < pz:
			l.x = signf(l.x if l.x != 0.0 else 1.0) * (HX + r)
		else:
			l.z = signf(l.z if l.z != 0.0 else 1.0) * (HZ + r)
	var wv := to_global(Vector3(l.x, 0.0, l.z))
	return Vector2(wv.x, wv.z)


## Slow spoilage: game seconds elapsed. Spoiled stacks turn into rotten meat.
func tick(game_s: float) -> void:
	var spoiled: Array = []
	for id in contents.keys():
		var s := Inventory.shelf_s(String(id))
		if s <= 0.0:
			continue
		age[id] = float(age.get(id, 0.0)) + game_s * COLD_RATE
		if float(age[id]) >= s:
			spoiled.append(String(id))
	for id in spoiled:
		var n: int = count(id)
		contents.erase(id)
		cond.erase(id)
		age.erase(id)
		contents["rotten_meat"] = count("rotten_meat") + n


func count(id: String) -> int:
	return int(contents.get(id, 0))


func stack_count() -> int:
	return contents.size()


func is_empty() -> bool:
	return contents.is_empty()


func can_hold(id: String) -> bool:
	return contents.has(id) or contents.size() < CAP


## Sorted [{id, n}] for the UI.
func stacks() -> Array:
	var out: Array = []
	var ids := contents.keys()
	ids.sort_custom(func(a, b) -> bool:
		var ka := Inventory.KIND_ORDER.find(Inventory.kind_of(String(a)))
		var kb := Inventory.KIND_ORDER.find(Inventory.kind_of(String(b)))
		return String(a) < String(b) if ka == kb else ka < kb)
	for id in ids:
		out.append({"id": String(id), "n": int(contents[id])})
	return out


func put(id: String, n: int, c: float, a: float) -> void:
	var old := count(id)
	if c < 0.999 or cond.has(id):
		cond[id] = (float(cond.get(id, 1.0)) * old + c * n) / float(old + n)
	if a > 0.0 or age.has(id):
		age[id] = (float(age.get(id, 0.0)) * old + a * n) / float(old + n)
	contents[id] = old + n


func remove(id: String, n: int) -> void:
	var left := count(id) - n
	if left <= 0:
		contents.erase(id)
		cond.erase(id)
		age.erase(id)
	else:
		contents[id] = left


func to_dict() -> Dictionary:
	return {"x": global_position.x, "y": global_position.y, "z": global_position.z, "yaw": rotation.y, "c": contents.duplicate(), "cond": cond.duplicate(), "age": age.duplicate()}


func load_dict(d: Dictionary) -> void:
	contents.clear()
	for k in (d.get("c", {}) as Dictionary).keys():
		contents[String(k)] = int(d["c"][k])
	cond = (d.get("cond", {}) as Dictionary).duplicate()
	age = (d.get("age", {}) as Dictionary).duplicate()
