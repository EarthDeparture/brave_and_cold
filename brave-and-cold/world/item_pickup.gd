class_name ItemPickup
extends Node3D
## Dropped items preserve quantity and condition. Resources use shared, original unit meshes.

var id := ""
var n := 1
var age_s:=0.0
var support := "" # Only authored placements; ordinary player drops keep their position.
var cond := -1.0   # worn tools keep their condition on the ground (-1 = pristine); dropping must not repair them


static func spawn(parent: Node, item_id: String, count: int, pos: Vector3, condition := -1.0,food_age := 0.0) -> ItemPickup:
	var p := ItemPickup.new()
	p.id = item_id
	p.n = count
	p.cond = condition
	p.age_s=maxf(0,food_age)
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group("pickups")
	if Inventory.shelf_s(id)>0:add_to_group("perishable_pickups")
	_build_visual()

func tick(game_s:float, rate:float=1.0) -> void:
	var shelf:=Inventory.shelf_s(id)
	if shelf<=0:return
	age_s+=maxf(0,game_s)*rate
	if age_s>=shelf:
		id="rotten_meat";age_s=0;remove_from_group("perishable_pickups")
		for child:Node in get_children():child.queue_free()
		_build_visual()

func _build_visual() -> void:
	if id.ends_with("_dried"):
		var portion:Node3D=(load("res://assets/food_preservation/dried_portion.glb") as PackedScene).instantiate()
		add_child(portion);portion.rotation.x=PI/2;portion.position=Vector3(0,.022,0);return
	if id in ["dc_fuse","sealed_connector","dc_cable","winter_controller"]:
		var asset:String={"dc_fuse":"dc_fuse","sealed_connector":"sealed_connector","dc_cable":"dc_cable","winter_controller":"winter_controller"}[id]
		add_child((load("res://assets/electrical_fieldwork/"+asset+".glb") as PackedScene).instantiate());return
	if id in ["clean_water","empty_bottle"]:
		var bottle:Node3D=(load("res://assets/opening_props/field_flask.glb") as PackedScene).instantiate();add_child(bottle)
		return
	if id in ["whetstone","sewing_kit","bandage"]:
		var asset:String="dressing_roll" if id=="bandage" else id
		add_child((load("res://assets/maintenance/"+asset+".glb") as PackedScene).instantiate());return
	if id in ["wood", "plank", "stick"]:
		_resource_pile()
		return
	if Inventory.is_rifle(id):
		# The real rifle art, lying on its left side (no animation player needed on the ground).
		var gun: Node3D
		if RifleDB.is_v3(id):
			var wp := WeaponPresentation.new(); add_child(wp); wp.set_weapon(id); gun = wp   # modular v3 art + its fit
		else:
			gun = (load("res://assets/weapons/north_ridge/" + id + ".glb") as PackedScene).instantiate(); add_child(gun)
		gun.rotation = Vector3(0, randf() * TAU, PI * .5); gun.position = Vector3(0, .025, 0)
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
