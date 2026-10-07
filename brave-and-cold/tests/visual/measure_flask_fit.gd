extends SceneTree
## Actual skinned hand vertices for bounded flask-fit diagnosis; no world/saves.
func _initialize()->void:call_deferred("run")
func run()->void:
	var p:=Player.new();root.add_child(p);p.set_process(false);p.set_physics_process(false);p.cam=Camera3D.new();p.add_child(p.cam)
	var vm:=Viewmodel.new();vm.player=p;p.cam.add_child(vm);vm.set_process(false);vm.mode="fists";vm._cur="fists";vm._equip=1
	vm.begin_work("drink",2);vm.update_work(1);vm._process(0)
	var result:Dictionary={}
	for release:float in [0,.12,.24,.36]:
		vm._right.pose("BottleGrip","",0,release)
		var row:Dictionary={}
		for gloved:bool in [false,true]:
			var mesh:MeshInstance3D=vm._right.glove if gloved else vm._right.bare
			var a:=mesh.mesh.surface_get_arrays(0);var base:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var vertices:=base.duplicate()
			for shape in mesh.mesh.get_blend_shape_count():
				var weight:=mesh.get_blend_shape_value(shape)
				if weight==0:continue
				var target:PackedVector3Array=mesh.mesh.surface_get_blend_shape_arrays(0)[shape][Mesh.ARRAY_VERTEX]
				for i in vertices.size():vertices[i]+=(target[i]-base[i])*weight
			var bones:PackedInt32Array=a[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var matrices:Array[Transform3D]=[]
			for bind in mesh.skin.get_bind_count():
				var bone:=vm._right.skeleton.find_bone(mesh.skin.get_bind_name(bind))
				if bone<0:bone=mesh.skin.get_bind_bone(bind)
				matrices.append(vm._right.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
			var points:Array=[];var stride:=int(weights.size()/vertices.size());var to_bottle:=vm._bottle.transform.affine_inverse()*vm._right.transform
			for i in vertices.size():
				var v:=Vector3.ZERO
				for j in stride:v+=(matrices[bones[i*stride+j]]*vertices[i])*weights[i*stride+j]
				v=to_bottle*v;points.append([v.x,v.y,v.z])
			row["gloved" if gloved else "bare"]=points
		result[str(release)]=row
	var f:=FileAccess.open("res://shots/opening-quality/flask_vertices.json",FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close();p.free();print("FLASK_FIT_VERTICES_READY");quit()
