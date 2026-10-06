extends "res://tests/test_viewmodel.gd"
## Diagnostic actual skinned vertices and actual imported prop triangles.
func array(v: Vector3) -> Array: return [v.x,v.y,v.z]
func geometry(node: Node3D, inverse: Transform3D) -> Array:
	var records: Array = []
	var meshes: Array = node.find_children("*","MeshInstance3D",true,false)
	if node is MeshInstance3D: meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		if mesh.global_basis.determinant()<.000001:continue
		for surface in mesh.mesh.get_surface_count():
			var data := mesh.mesh.surface_get_arrays(surface);var points:Array=[]
			for point: Vector3 in data[Mesh.ARRAY_VERTEX]:points.append(array(inverse*mesh.global_transform*point))
			records.append({"name":String(mesh.name),"points":points,"indices":Array(data[Mesh.ARRAY_INDEX])})
	return records
func hand_record(hand: SurvivorHandRig, inverse: Transform3D) -> Dictionary:
	var points:Array=[];var regions:Array=[]
	var mesh:=hand.glove;var data:=mesh.mesh.surface_get_arrays(0)
	var bones:PackedInt32Array=data[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=data[Mesh.ARRAY_WEIGHTS]
	var skin:=skin_vertices(hand,true);var stride:=int(weights.size()/skin.size())
	for i in skin.size():
		points.append(array(skin[i]));var best:=0
		for j in stride:
			if weights[i*stride+j]>weights[i*stride+best]:best=j
		var bind:=bones[i*stride+best];var name:=String(mesh.skin.get_bind_name(bind))
		if name=="":name=hand.skeleton.get_bone_name(mesh.skin.get_bind_bone(bind))
		regions.append(name)
	var transform:=inverse*hand.global_transform
	return {"points":points,"regions":regions,"basis":[array(transform.basis.x),array(transform.basis.y),array(transform.basis.z)],"origin":array(transform.origin)}
func run() -> void:
	p=Player.new();root.add_child(p);p.set_process(false);p.set_physics_process(false);p.cam=Camera3D.new();p.add_child(p.cam);p.cam.fov=70
	vm=Viewmodel.new();vm.player=p;vm.detail_enabled=true;p.cam.add_child(vm);vm.set_process(false)
	var records:Dictionary={}
	for id:String in WeaponPresentation.IDS:
		vm.equip_weapon(id)
		for state:String in ["hold","bolt","magazine"]:
			pose("rifle",-1,.62 if state=="bolt" else -1)
			if state=="magazine":vm.play_weapon_clip("reload_tactical" if not vm._rifle.is_lever_action() else "reload_insert");vm._weapon_clip_t=.68 if not vm._rifle.is_lever_action() else .4;vm._process(0)
			var inverse:=vm._rifle.global_transform.affine_inverse()
			var anchor_r:=inverse.basis*vm.global_basis*vm._rifle.socket_transform("BoltHand" if state=="bolt" else "HandR").basis
			var anchor_l:=inverse.basis*vm.global_basis*vm._rifle.socket_transform("MagazineHand" if state=="magazine" and not vm._rifle.is_lever_action() else "HandL").basis
			records[id+"/"+state]={"geometry":geometry(vm._rifle.model,inverse),"right":hand_record(vm._right,inverse),"left":hand_record(vm._left,inverse),"anchors":{"right":[array(anchor_r.x),array(anchor_r.y),array(anchor_r.z)],"left":[array(anchor_l.x),array(anchor_l.y),array(anchor_l.z)]}}
			vm.cancel_weapon_clip()
	pose("axe")
	var inverse:=vm._axe.global_transform.affine_inverse()
	records["tool"]={"geometry":geometry(vm._axe,inverse),"right":hand_record(vm._right,inverse)}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/anatomical-weapons"))
	var file:=FileAccess.open("res://shots/anatomical-weapons/contact_geometry.json",FileAccess.WRITE);file.store_string(JSON.stringify(records));file.close()
	print("ANATOMICAL_CONTACT_DUMP_PASS ",records.size());p.free();quit()
