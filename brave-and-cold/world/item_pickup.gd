class_name ItemPickup
extends Node3D
## Dropped items preserve quantity and condition. Resources use shared, original unit meshes.

var id := ""
var n := 1
var cond := -1.0   # worn tools keep their condition on the ground (-1 = pristine); dropping must not repair them


static func spawn(parent: Node, item_id: String, count: int, pos: Vector3, condition := -1.0) -> ItemPickup:
	var p := ItemPickup.new()
	p.id = item_id
	p.n = count
	p.cond = condition
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group("pickups")
	if id in ["clean_water","empty_bottle"]:
		var bottle:Node3D=(load("res://assets/first_week/water_bottle.glb") as PackedScene).instantiate();add_child(bottle)
		return
	if id in ["wood", "plank", "stick"]:
		_resource_pile()
		return
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

## Bounded unit count, without solid collision or an enlarged interaction footprint.
## Excess quantities remain accurately reported by the existing pickup prompt.
func _resource_pile() -> void:
	var poses: Array[Transform3D] = []
	var capacity := 12 if id == "wood" else (8 if id == "plank" else 16)
	for i in mini(maxi(n, 0), capacity):
		var pos: Vector3
		var yaw: float
		if id == "wood":
			pos = Vector3(0, floorf(float(i)/3)*.066, (float(i%3)-1)*.13)
			yaw = sin(float(i)*2.7)*.06
		elif id == "plank":
			pos = Vector3(0, i*.029, 0)
			yaw = sin(float(i)*1.9)*.035
		else:
			pos = Vector3((float(i%4)-1.5)*.025, floorf(float(i)/4)*.02, (float(i%3)-1)*.032)
			yaw = sin(float(i)*2.4)*.20
		poses.append(Transform3D(Basis(Vector3.UP, yaw), pos))
	SurvivalProps.pile(self, id, poses)
