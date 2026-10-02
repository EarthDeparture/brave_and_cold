class_name StorageChest
extends Node3D
## Craftable wooden storage chest. Holds up to CAP different stacks. Remembers wear/age of what it holds.
## Contents do not age while stored (cold box in the snow). Node origin is on the floor.

const CAP := 24
const W := 0.9
const D := 0.55
const H := 0.5

var contents: Dictionary = {}   # id -> n
var cond: Dictionary = {}       # id -> condition 0..1 (only when worn)
var age: Dictionary = {}        # id -> age seconds (perishables)


func _ready() -> void:
	add_to_group("chests")
	_build()


func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.23, 0.14)
	wood.roughness = 0.92
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.17, 0.16, 0.15)
	dark.roughness = 0.6
	dark.metallic = 0.45
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.86, 0.9, 0.96)
	snow.roughness = 1.0
	_box(Vector3(W, H, D), Vector3(0, H * 0.5, 0), wood)
	_box(Vector3(W + 0.03, 0.13, D + 0.03), Vector3(0, H + 0.06, 0), wood)
	for sx in [-0.28, 0.28]:
		_box(Vector3(0.07, H + 0.16, D + 0.05), Vector3(sx, (H + 0.16) * 0.5, 0), dark)
	_box(Vector3(0.1, 0.12, 0.04), Vector3(0, H - 0.02, D * 0.5 + 0.03), dark)
	_box(Vector3(W * 0.8, 0.03, D * 0.8), Vector3(0, H + 0.14, 0), snow)  # a little snow on the lid


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func center_world() -> Vector3:
	return global_position + Vector3(0.0, 0.35, 0.0)


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
