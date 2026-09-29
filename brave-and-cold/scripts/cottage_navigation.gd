extends NavigationRegion3D
## Flat blockout ground with clearance around the cottage walls.
## Update these bounds when the cottage footprint or terrain changes.


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
	navigation_mesh = mesh
