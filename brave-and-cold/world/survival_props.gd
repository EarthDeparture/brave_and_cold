class_name SurvivalProps
extends RefCounted
## Shared imported meshes and bounded instancing. Presentation never changes inventory.
const MODELS := {"wood":"resource_wood", "stick":"resource_stick", "plank":"resource_plank", "beans":"ration_tin", "jerky":"ration_pouch", "tray":"provisions_tray"}
static var _meshes: Dictionary = {}
static func mesh_for(id: String) -> Mesh:
	if _meshes.has(id): return _meshes[id]
	if not MODELS.has(id): return null
	var root := (load("res://assets/survival_props/"+MODELS[id]+".glb") as PackedScene).instantiate()
	var source := root.find_child(MODELS[id], true, false) as MeshInstance3D
	assert(source != null)
	var mesh := source.mesh.duplicate() as Mesh
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i) as StandardMaterial3D
		if mat != null:
			mat = mat.duplicate() as StandardMaterial3D
			mat.vertex_color_use_as_albedo = true
			mat.roughness = maxf(mat.roughness, .80) if id != "beans" else mat.roughness
			mesh.surface_set_material(i, mat)
	root.free()
	_meshes[id] = mesh
	return mesh
static func pile(parent: Node3D, id: String, poses: Array[Transform3D]) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = "Stock_"+id
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_for(id)
	mm.instance_count = poses.size()
	for i in poses.size(): mm.set_instance_transform(i, poses[i])
	node.multimesh = mm
	node.visibility_range_end = 90
	node.visibility_range_end_margin = 10
	parent.add_child(node)
	return node
