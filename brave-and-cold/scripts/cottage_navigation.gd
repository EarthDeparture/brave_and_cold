extends NavigationRegion3D
## Flat blockout ground with clearance around the cottage walls.
## Update these bounds when the cottage footprint or terrain changes.


var breach_links: Dictionary = {}


func _ready() -> void:
	var mesh := NavigationMesh.new()
	var edges := [-48.0, -5.8, 5.8, 48.0]
	var vertices := PackedVector3Array()
	for z in edges:
		for x in edges:
			vertices.append(Vector3(x, 0, z))
	mesh.vertices = vertices
	for z in range(3):
		for x in range(3):
			if x == 1 and z == 1:
				continue
			var start := z * 4 + x
			mesh.add_polygon(PackedInt32Array([start, start + 4, start + 5, start + 1]))
	# Interior floor and narrow links through the three actual openings.
	var start := vertices.size()
	vertices.append_array(PackedVector3Array([
		Vector3(-4.4, 0, -3.6), Vector3(-4.4, 0, 4.4),
		Vector3(4.4, 0, 4.4), Vector3(4.4, 0, -3.6)]))
	mesh.vertices = vertices
	mesh.add_polygon(PackedInt32Array([start, start + 1, start + 2, start + 3]))
	navigation_mesh = mesh
	call_deferred("_create_breach_links")


func _create_breach_links() -> void:
	if not is_inside_tree():
		return
	for barrier in get_tree().get_nodes_in_group("attracting_windows"):
		var link := NavigationLink3D.new()
		var center: Vector3 = barrier.global_position
		var north := center.z < 0.0
		center.y = 0.0
		if not north:
			center.x += 0.95
		link.start_position = Vector3(center.x, 0, -5.9 if north else 5.9)
		link.end_position = Vector3(center.x, 0, -3.5 if north else 4.3)
		link.enabled = barrier.is_passable()
		add_child(link)
		breach_links[barrier] = link


func _process(_delta: float) -> void:
	for barrier in breach_links:
		var link: NavigationLink3D = breach_links[barrier]
		link.enabled = is_instance_valid(barrier) and barrier.is_passable()
