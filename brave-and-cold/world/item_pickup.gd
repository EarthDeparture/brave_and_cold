class_name ItemPickup
extends Node3D
## An item lying in the snow. Shown as a small coloured block (no per-item 3D models yet). Picked up via the action menu or the Gear screen.

var id := ""
var n := 1


static func spawn(parent: Node, item_id: String, count: int, pos: Vector3) -> ItemPickup:
	var p := ItemPickup.new()
	p.id = item_id
	p.n = count
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group("pickups")
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var kind := Inventory.kind_of(id)
	match kind:
		"weapon":
			bm.size = Vector3(0.9, 0.06, 0.12)
		"clothing":
			bm.size = Vector3(0.5, 0.08, 0.4)
		"fuel":
			bm.size = Vector3(0.5, 0.14, 0.14)
		_:
			bm.size = Vector3(0.22, 0.12, 0.16)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DZ.item_color(id)
	mat.roughness = 0.9
	m.material_override = mat
	m.position = Vector3(0, bm.size.y * 0.5 - 0.02, 0)
	m.rotation.y = randf() * TAU
	add_child(m)
