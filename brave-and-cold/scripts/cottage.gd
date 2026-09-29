extends Node3D
## Compact blockout interior. Window openings are left in the north wall.


func _ready() -> void:
	add_to_group("temperature_shelters")
	var wood := Color(0.23, 0.14, 0.085)
	var stone := Color(0.24, 0.25, 0.27)
	_box("Floor", Vector3(10, 0.2, 10), Vector3(0, -0.1, 0), wood)
	_box("Roof", Vector3(10.4, 0.3, 10.4), Vector3(0, 3.65, 0), wood)
	_box("WestWall", Vector3(0.3, 3.6, 10), Vector3(-5, 1.8, 0), wood)
	_box("EastWall", Vector3(0.3, 3.6, 10), Vector3(5, 1.8, 0), wood)
	for side in [-1, 1]:
		_box("SouthWall", Vector3(4, 3.6, 0.3), Vector3(side * 3, 1.8, 5), wood)
	_box("DoorLintel", Vector3(2, 1, 0.3), Vector3(0, 3.1, 5), wood)
	_box("NorthSill", Vector3(2.6, 1, 0.3), Vector3(0, 0.5, -5), wood)
	for side in [-1, 1]:
		_box("SillEnd", Vector3(1.9, 1, 0.3), Vector3(side * 4.05, 0.5, -5), wood)
	for window in [$LeftWindow, $RightWindow]:
		_box(window.name + "Sill", Vector3(1.8, 1, 0.3), Vector3(window.position.x, 0.5, -5), wood)
	_box("NorthLintel", Vector3(10, 1.2, 0.3), Vector3(0, 3, -5), wood)
	_box("NorthCenter", Vector3(2.6, 1.4, 0.3), Vector3(0, 1.7, -5), wood)
	for side in [-1, 1]:
		_box("NorthEnd", Vector3(1.9, 1.4, 0.3), Vector3(side * 4.05, 1.7, -5), wood)
	_box("Hearth", Vector3(2.4, 0.2, 1.2), Vector3(0, 0.1, -4.2), stone)
	_box("Chimney", Vector3(2.0, 2, 0.6), Vector3(0, 2.6, -4.6), stone)
	for side in [-1, 1]:
		_box("HearthPillar", Vector3(0.3, 1.4, 0.8), Vector3(side * 0.85, 0.9, -4.5), stone)


func contains_point(world_position: Vector3) -> bool:
	return AABB(Vector3(-5, 0, -5), Vector3(10, 3.6, 10)).has_point(to_local(world_position))


func _box(label: String, size: Vector3, location: Vector3, color: Color, glowing: bool = false) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = location
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = glowing
	material.emission = color
	material.emission_energy_multiplier = 3.0
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func has_breach() -> bool:
	for barrier in get_children():
		if barrier.is_in_group("attracting_windows") and barrier.broken and not barrier.boarded:
			return true
	return false


func update_window_breach(window: Node3D) -> void:
	var sill = get_node_or_null(str(window.name) + "Sill")
	if sill:
		sill.visible = not window.is_passable()
		sill.collision_layer = 0 if window.is_passable() else 1
		sill.collision_mask = 0
