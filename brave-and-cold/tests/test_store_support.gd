extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c:Node in n.get_children():freeze(c)
func bounds(n:Node3D,relative:Node3D)->AABB:
	var lo:=Vector3(INF,INF,INF);var hi:=-lo
	for m:MeshInstance3D in n.find_children("*","MeshInstance3D",true,false):
		for surface in m.mesh.get_surface_count():
			for v:Vector3 in m.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p:=relative.to_local(m.to_global(v));lo=lo.min(p);hi=hi.max(p)
	return AABB(lo,hi-lo)
func build(saved:Dictionary={}) -> Node3D:
	SaveGame.pending=saved;seed(20261004)
	var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for f in 700:
		await process_frame
		if w.town_life!=null and w.gear!=null:break
	freeze(w);w.out_path="test-no-autosave";w._frames=100
	return w
func run()->void:
	create_timer(160).timeout.connect(func()->void:quit(2))
	var w:Node3D=await build()
	var store:Store=w.stores[0]
	var kit:Node3D # The case is a named store child.
	if kit==null:
		for child:Node in store.get_children():
			if child is Node3D and child.scene_file_path.ends_with("controller_case.glb"):kit=child
	var objects:Array[Node3D]=[w.opening.case_model,kit,w.opening.electrical.slate,w.town_life.ledger]
	for n:Node3D in objects:
		check(n!=null,"job display exists")
		if n==null:continue
		var b:=bounds(n,store);print("STORE_SUPPORT_BOUNDS ",n.scene_file_path," ",b)
		check(b.position.y>=1.399 and b.position.y<=1.405,"display bottom rests on the actual 1.40 m counter")
		check(b.position.x>=1.25 and b.end.x<=1.95,"display footprint remains supported across counter width")
		check(b.position.z>=-1.32 and b.end.z<=1.34,"display stays at counter rather than in aisle")
	for i in objects.size():
		for j in range(i+1,objects.size()):
			if objects[i]!=null and objects[j]!=null:check(not bounds(objects[i],store).intersects(bounds(objects[j],store)),"separate critical displays do not intersect")
	for i in Store.LOOT_SPOTS.size():
		check(store.to_local(store.loot_world_pos(i)).distance_to(Store.LOOT_SPOTS[i])<.0001,"loot interaction follows its physical spot "+str(i))
	var rifle:ItemPickup
	for p:ItemPickup in get_nodes_in_group("pickups"):
		if p.support=="store_rifle":rifle=p
	check(rifle!=null,"authored rifle uses its own supported placement")
	if rifle!=null:
		var b:=bounds(rifle,store);print("STORE_RIFLE_BOUNDS ",b)
		check(absf(b.position.y-1.427)<.001 and b.position.x>.35 and b.end.x<1.55 and b.position.z>-2.175 and b.end.z<-1.825,"rifle lies wholly on the empty middle shelf")
		var old:=ItemPickup.spawn(w,"north_service_rifle",1,store.to_global(Vector3(-1.5,1.83,-1.95)))
		check(store.is_legacy_rifle_cache(old),"precise elevated legacy cache can migrate")
		old.global_position=store.to_global(Vector3(-1.5,.30,-1.95));check(not store.is_legacy_rifle_cache(old),"ordinary dropped rifles cannot be mistaken for the authored cache");old.queue_free()
		check(w._pickup_list().any(func(d:Dictionary)->bool:return d.get("support","")=="store_rifle"),"authored placement contract is saved with the finite pickup")
	w.inv.counts.clear();w.opening.claim_parts();w.opening.claim_parts()
	check(w.inv.count("power_relay")==1,"supported relay remains a single finite job transaction")
	w.opening.electrical.claim_controller();w.opening.electrical.claim_controller()
	check(w.inv.count("winter_controller")==1,"supported controller remains a single finite transaction")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free();await process_frame;await process_frame;w=await build(saved);store=w.stores[0]
	var supported:Array=get_nodes_in_group("pickups").filter(func(p:ItemPickup)->bool:return p.support=="store_rifle")
	check(supported.size()==1 and absf(bounds(supported[0],store).position.y-1.427)<.001,"actual reload preserves a single supported rifle")
	check(w.opening.state.parts_claimed and w.opening.electrical.service.controller_claimed,"moved job stock stays issued after actual reload")
	for e:Dictionary in saved.pickups:
		if e.get("support","")=="store_rifle":
			var p:=store.to_global(Vector3(-1.5,1.83,-1.95));e.support="";e.x=p.x;e.y=p.y;e.z=p.z
	w.queue_free();await process_frame;await process_frame;w=await build(saved);store=w.stores[0]
	supported=get_nodes_in_group("pickups").filter(func(p:ItemPickup)->bool:return p.support=="store_rifle")
	check(supported.size()==1 and absf(bounds(supported[0],store).position.y-1.427)<.001,"actual legacy reload migrates the elevated cache without adding a rifle")
	w.queue_free();await process_frame;SaveGame.pending={}
	print("STORE_SUPPORT_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
