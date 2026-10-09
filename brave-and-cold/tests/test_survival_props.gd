extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child: Node in node.get_children(): freeze(child)
func build_world() -> Node3D:
	var w: Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	freeze(w);return w
func units(op: LookoutOpening,id: String) -> int:
	var pile := op._stock.get_node("Stock_"+id) as MultiMeshInstance3D
	return pile.multimesh.instance_count
func skin_vertices(hand: SurvivorHandRig,gloved:=false) -> PackedVector3Array:
	var mesh := hand.glove if gloved else hand.bare
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Imported glTF stores absolute positions in NORMALIZED blend shapes.
	assert(mesh.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	var base:=vertices.duplicate()
	for shape in mesh.mesh.get_blend_shape_count():
		var blend:float=mesh.get_blend_shape_value(shape)
		if absf(blend)<.000001:continue
		var target:PackedVector3Array=mesh.mesh.surface_get_blend_shape_arrays(0)[shape][Mesh.ARRAY_VERTEX]
		for i in vertices.size():vertices[i]+=(target[i]-base[i])*blend
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var matrices: Array[Transform3D] = []
	for bind in mesh.skin.get_bind_count():
		var bone := hand.skeleton.find_bone(mesh.skin.get_bind_name(bind))
		if bone<0: bone=mesh.skin.get_bind_bone(bind)
		matrices.append(hand.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var result := PackedVector3Array()
	var stride := int(weights.size()/vertices.size())
	for i in vertices.size():
		var v := Vector3.ZERO
		for j in stride:
			v += (matrices[bones[i*stride+j]]*vertices[i])*weights[i*stride+j]
		result.append(v)
	return result
func run() -> void:
	create_timer(120).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	SaveGame.pending={};seed(20261004)
	var w:Node3D=await build_world();var op:LookoutOpening=w.opening;var vm:Viewmodel=w.viewmodel
	check(units(op,"wood")==6 and units(op,"beans")==4 and units(op,"jerky")==2,"opening displays each of six logs, four tins and two pouches")
	check(not op.home_model.get_node("HomeWood").visible and not op.home_model.get_node("PantryFood").visible,"old grouped stock remains hidden")
	var pile:=op._stock.get_node("Stock_wood");op.update_presentation()
	check(pile==op._stock.get_node("Stock_wood"),"unchanged stock does not rebuild each frame")
	op.pantry.remove("beans",1);check(units(op,"beans")==3,"one removed tin disappears immediately")
	op.pantry.put("beans",1,.75,0);check(units(op,"beans")==4,"deposited tin returns immediately")
	op.pantry.remove("jerky",2);check(units(op,"jerky")==0,"empty pouch stock leaves no visible pouches")
	op.pantry.put("beans",30,1,0)
	check(units(op,"beans")==4 and op.pantry.count("beans")==34 and "extra stock stored" in op._stock_label.text,"overflow display is bounded and explicitly marked without losing stock")
	var before:int=w.inv.count("wood");op.take_wood()
	check(op.wood_left==5 and units(op,"wood")==5 and w.inv.count("wood")==before+1,"taking wood removes exactly one visible and stored log")
	w.inv.counts["wood"]=100;op.take_wood()
	check(op.wood_left==5 and units(op,"wood")==5,"full backpack cannot silently consume reserve")
	w.inv.counts["wood"]=2
	for i in 5:op.take_wood()
	check(op.wood_left==0 and units(op,"wood")==0,"entire loose reserve can visibly run out")
	for id:String in ["wood","plank","stick"]:
		var p:=ItemPickup.spawn(w,id,3,w.player.position-Vector3.UP*w.player.eye_h,.45)
		var mm:=p.get_node("Stock_"+id) as MultiMeshInstance3D
		check(mm.multimesh.instance_count==3 and p.n==3 and p.cond==.45,"original "+id+" pickup preserves exact quantity and condition")
		check(p.find_children("*","CollisionShape3D",true,false).is_empty(),id+" visual creates no walking obstacle")
	var huge:=ItemPickup.spawn(w,"stick",1000,w.player.position-Vector3.UP*w.player.eye_h)
	check((huge.get_node("Stock_stick") as MultiMeshInstance3D).multimesh.instance_count==16 and huge.n==1000,"large drop remains bounded without truncating inventory")
	w.inv.add("hammer");w.inv.add("rifle");w.rifle_up=true;vm.mode="rifle";vm._cur="rifle";vm._equip=1
	var initial:int=w.inv.count("plank");var results:={"n":0}
	var action:={"hold":6.0,"work":"hammer","text":"Work test","act":func()->void:results.n+=1}
	w._act_begin(action);w._act_update(1,true);vm._process(0)
	check(vm._hammer.visible and not vm._rifle.visible and not vm._axe.visible,"hammering uses the service hammer while actual equipment remains rifle")
	check(absf(vm._right.position.distance_to(vm._sl_r.position)-.05)<.0001,"working sleeve overlaps the anatomical forearm at its cuff")
	check(vm.work_impacts(3)==4,"all hammer strikes align with action ending at final impact")
	w._act_update(.1,false);vm._process(0)
	check(results.n==0 and w.inv.count("plank")==initial and vm.work_kind=="" and vm._rifle.visible,"release cancels work, consumes nothing and restores equipped rifle")
	w._act_begin(action);w._act_update(3.01,true);vm._process(0)
	check(results.n==1 and vm._hammer.visible,"completion occurs once and retains a short physical recovery")
	vm._process(2)
	check(vm.work_kind=="" and vm._rifle.visible,"completed tool recovery returns to chosen equipment")
	for kind:String in ["hammer","split","chop","reach"]:
		vm.begin_work(kind,2.5)
		for i in 51:
			vm.update_work(2.5*i/50);vm._process(0)
			if not vm._right.transform.origin.is_finite() or absf(vm._right.position.distance_to(vm._sl_r.position)-.05)>.0001:check(false,"pose continuity "+kind)
		check(vm._right.visible and not vm._left.visible,kind+" maintains bounded, attached right-arm presentation")
	vm.begin_work("hammer",3);vm.update_work(.7);vm._process(0)
	for gloved:bool in [false,true]:
		var penetration:=0.0;var touching:=0;var inverse:=vm._hammer.transform.affine_inverse()
		for point:Vector3 in skin_vertices(vm._right,gloved):
			var tool:Vector3=inverse*(vm._right.transform*point)
			if absf(tool.y)>.04:continue
			var radial:float=pow(pow(absf(tool.x/.0122),2.4)+pow(absf((tool.z-.002)/.0168),2.4),1.0/2.4)
			var distance:float=(radial-1)*.0122*1.2
			penetration=maxf(penetration,-distance)
			if absf(distance)<.004:touching+=1
		print("HAMMER_CONTACT gloves=",gloved," penetration=",penetration," near_surface_vertices=",touching)
		check(penetration<.0035 and touching>20,"actual skinned hammer grip preserves pad contact and clearance, gloves="+str(gloved))
	vm.begin_work("chop",.425);vm.update_work(.425);vm._process(0)
	var finish:=vm._right.transform
	vm.begin_work("chop",.425,true);vm._process(0)
	check(finish.origin.distance_to(vm._right.position)<.0001 and finish.basis.is_equal_approx(vm._right.basis),"repeated tree chopping starts at previous impact without snapping wrist")
	var tin:=SurvivalProps.mesh_for("beans");var uv_ok:=false
	for surface in tin.get_surface_count():
		if tin.surface_get_material(surface).resource_name=="vm_ration":
			var uvs:PackedVector2Array=tin.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
			var low:=Vector2(1,1);var high:=Vector2.ZERO
			for uv:Vector2 in uvs:low=low.min(uv);high=high.max(uv)
			uv_ok=(high-low).x>.9 and (high-low).y>.9
	check(uv_ok,"joined tin keeps the full original label UV range")
	vm.end_work(false);w.rifle_up=false
	w._act_begin({"hold":5.0,"work":"split","text":"Split","act":func()->void:results.n+=1})
	w.rifle_up=true;w._act_update(.1,true)
	check(vm.work_kind=="" and results.n==1,"putting away hatchet interrupts splitting without completion")
	w.rifle_up=false;w._act_begin(action);w.player.health-=1;w._act_update(.1,true)
	check(vm.work_kind=="" and results.n==1,"damage cancels all work feedback")
	w._act_begin(action);w.player.ui_open=true;w._act_update(.1,true);w.player.ui_open=false
	check(vm.work_kind=="" and results.n==1,"opening inventory cancels work feedback")
	var snap:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free();await process_frame;await process_frame
	SaveGame.pending=snap;w=await build_world();op=w.opening
	check(units(op,"wood")==0 and units(op,"beans")==4 and op.pantry.count("beans")==34,"fresh loading derives bounded visuals from authoritative saved counts")
	var exact:=0
	for pick:ItemPickup in get_nodes_in_group("pickups"):
		if not Inventory.is_rifle(pick.id):exact+=pick.n
	check(exact==1009,"pickup save/load preserves large quantities and original unit models")
	w.queue_free();await process_frame;print("SURVIVAL_PROPS_TEST failures=",failures);quit(1 if failures else 0)
