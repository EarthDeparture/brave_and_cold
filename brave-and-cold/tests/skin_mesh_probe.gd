extends RefCounted
## Independent CPU probe of imported morph+skin buffers for pose assertions.
static func vertices(mesh:MeshInstance3D,surface:int,sk:Skeleton3D)->PackedVector3Array:
	var arrays:=mesh.mesh.surface_get_arrays(surface)
	var source:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
	var targets:=mesh.mesh.surface_get_blend_shape_arrays(surface)
	for shape in targets.size():
		var value:=mesh.get_blend_shape_value(shape)
		if absf(value)<.000001:continue
		var positions:PackedVector3Array=targets[shape][Mesh.ARRAY_VERTEX]
		for i in source.size():
			var delta:=positions[i]-(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[i] if mesh.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED else positions[i]
			source[i]+=delta*value
	var slots:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var matrices:Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=sk.find_bone(mesh.skin.get_bind_name(bind))
		if bone<0:bone=mesh.skin.get_bind_bone(bind)
		matrices.append(sk.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var result:=PackedVector3Array();var stride:=int(weights.size()/source.size())
	for i in source.size():
		var p:=Vector3.ZERO
		for j in stride:
			if weights[i*stride+j]>0:p+=(matrices[slots[i*stride+j]]*source[i])*weights[i*stride+j]
		result.append(p)
	return result
