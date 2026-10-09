class_name FirstWeekRoute
extends Node3D
## Additive stops beside the surveyed existing lookout track. Save identities are independent of ordinary felled trees.
var world: Node3D
var timber_done:=false
var feeder_isolated:=false
var cache: StorageChest
var timber: WoodLog
var points: Array[Vector3]=[]
var directions: Array[Vector3]=[]
var models: Array[Node3D]=[]
var _lid: Node3D
var _label: Label3D
const CACHE_ITEMS:=["clean_water","bandage","beans","matches"]
var _cache_stock_nodes:Array[Node3D]=[]
func build(w: Node3D, saved: Dictionary={}) -> void:
	world=w;timber_done=bool(saved.get("timber_done",false));feeder_isolated=bool(saved.get("feeder_isolated",false))
	var path:Array=[]
	var top:=Vector2(w.fire_lookout.global_position.x,w.fire_lookout.global_position.z)
	for row:Array in w.fire_lookout.site.path.points_world_xyz:path.append(Vector2(row[0],row[2]))
	if path.is_empty():push_error("First-week stops require existing lookout trail");return
	if top.distance_squared_to(path[0])>top.distance_squared_to(path[-1]):path.reverse()
	for fraction: float in [.28,.55,.78]:
		var i:=clampi(int((path.size()-1)*fraction),1,path.size()-2)
		var direction:Vector2=(path[i+1]-path[i-1]).normalized()
		var side:=Vector2(-direction.y,direction.x)
		var chosen:Vector2=path[i]+side*2.1;var clear:=false
		for step in range(0,22):
			var j:=clampi(i+(int(ceil(step/2.0)) if step%2==0 else -int(ceil(step/2.0))),1,path.size()-2)
			direction=(path[j+1]-path[j-1]).normalized();side=Vector2(-direction.y,direction.x)
			for sign_v:float in [1.0,-1.0]:
				for offset:float in [2.1,2.6,3.2]:
					var candidate:Vector2=path[j]+side*offset*sign_v
					var correction:Vector2=w.forest.resolve_trunks(candidate.x,candidate.y,2.4)
					var ground:Vector3=w._ground(candidate.x,candidate.y)
					var grade:=0.0
					for axis:Vector2 in [Vector2(.8,0),Vector2(0,.8),Vector2(-.8,0),Vector2(0,-.8)]:
						grade=maxf(grade,absf(ground.y-w._ground(candidate.x+axis.x,candidate.y+axis.y).y)/.8)
					if correction.distance_to(candidate)<.01 and grade<.40:
						chosen=candidate;clear=true;break
				if clear:break
			if clear:break
		if not clear:push_warning("Route stop uses fallback shoulder location")
		points.append(w._ground(chosen.x,chosen.y));directions.append(Vector3(direction.x,0,direction.y))
	if saved.get("positions",[]).size()==3:
		for i in 3:
			var a:Array=saved.positions[i];points[i]=Vector3(a[0],a[1],a[2])
			var d:Array=saved.directions[i];directions[i]=Vector3(d[0],d[1],d[2])
	var marker:=asset("timber_marker",points[0]+Vector3(.9,0,.3));models.append(marker)
	if not timber_done:
		timber=WoodLog.new();w.add_child(timber);timber.set_meta("authored_stop","timber")
		timber.setup(w.terrain,points[0].x,points[0].z,directions[0],6,.22)
	models.append(asset("field_cache",points[1]));_lid=models[-1].find_child("CacheLid",true,false)
	cache=StorageChest.new();cache.visual_enabled=false;add_child(cache);cache.global_position=points[1]
	w.player.chests=w.player.chests.duplicate();w.player.chests.append(cache)
	if saved.has("cache"):cache.load_dict(saved.cache)
	else:
		for pair: Array in [["matches",4],["beans",2],["bandage",2],["clean_water",2],["empty_bottle",2]]:cache.put(pair[0],pair[1],1,0)
	cache.rotation.y=models[1].rotation.y
	_bind_cache_visuals();cache.contents_changed.connect(_update_cache_stock);_update_cache_stock()
	models.append(asset("feeder_cabinet",points[2]))
	_label=Label3D.new();add_child(_label);_label.global_position=points[2]+Vector3(0,1.65,.24);_label.font_size=32;_label.pixel_size=.003;_label.outline_size=4;_label.visible=false
	update(0)
func asset(id: String, pos: Vector3) -> Node3D:
	var n:Node3D=(load("res://assets/first_week/"+id+".glb") as PackedScene).instantiate();add_child(n);n.global_position=pos
	var nearest:=Vector2.ZERO;var best:=INF
	for row:Array in world.fire_lookout.site.path.points_world_xyz:
		var xy:=Vector2(row[0],row[2]);var distance:=xy.distance_squared_to(Vector2(pos.x,pos.z))
		if distance<best:best=distance;nearest=xy
	n.rotation.y=atan2(nearest.x-pos.x,nearest.y-pos.z)
	for mesh: MeshInstance3D in n.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=100
	return n
func update(gs: float) -> void:
	if cache==null:return
	cache.tick(gs);cache.want_open=world.gear!=null and world.gear.is_open and world.gear._chest==cache and world.gear._tab=="chest"
	# Reserved lid-mounted spares are collected through the same work runner.
	# Show the actual lid opening while reaching in; cancellation closes it.
	cache.want_open=cache.want_open or String(world._act.get("text","")).begins_with("Collect sealed fuse")
	var label:="CREW SPUR • ISOLATED" if feeder_isolated else "CREW SPUR • 6 W STANDBY"
	if _label.text!=label:_label.text=label
func _bind_cache_visuals()->void:
	_cache_stock_nodes.clear()
	for id:String in ["CacheWaterStock","CacheMedicalStock","CacheFoodStock","CacheMatchStock"]:
		_cache_stock_nodes.append(models[1].find_child(id,true,false) as Node3D)
func _update_cache_stock()->void:
	for i in _cache_stock_nodes.size():
		if _cache_stock_nodes[i]!=null:_cache_stock_nodes[i].visible=cache.count(CACHE_ITEMS[i])>0
func _process(delta:float) -> void:
	if cache==null:return
	cache.lid_k=move_toward(cache.lid_k,1.0 if cache.want_open else 0.0,delta*2.6)
	if _lid!=null:_lid.rotation.x=-smoothstep(0.0,1.0,cache.lid_k)*deg_to_rad(100)
func actions() -> Array:
	if points.size()!=3:return []
	var op:LookoutOpening=world.opening
	var out:Array=[op._action(points[1]+Vector3.UP*.6,"Open crew reserve",func()->void:world.gear.open_chest(cache)),op._action(points[1]+Vector3(.5,.9,0),"Read crew shift note",read_note,0,.03)]
	out.append(op._action(points[2]+Vector3(0,1,.25),"Crew spur isolated • inspect record" if feeder_isolated else "Isolate unused crew spur • save 6 W",isolate,6))
	return out
func consume_timber() -> void:timber_done=true
func isolate() -> void:
	if world.inv.count("service_kit")<1:world._say("Bring your insulated service kit");return
	if not feeder_isolated:feeder_isolated=true;world.opening.state.field_load_w=0
	world.reading.open("North Ridge • crew feeder","The vacant crew shelter's standby branch is isolated. This removes its 6 W load from the lookout's backup supply. The town grid and public transmitter are independent. Leave the labelled disconnect isolated until another crew signs it back into service.",world.player,world.hud)
func read_note() -> void:
	world.reading.open("Mara's shift • Monday","Left the emergency crate beside the timber pull-off for the next crew. Water, dressings and matches are counted; sign out what you take.\n\nA dry trunk is set aside nearer the tower. Split it and restock before the evening wind.\n\nThe supply truck comes tomorrow afternoon. If you run short before then, the clinic on the town road keeps medical reserves.\n\nMara: I left your sister's letter in the lookout. Write back and the truck driver can take it down.",world.player,world.hud)
func to_dict() -> Dictionary:return {"positions":points.map(func(v:Vector3)->Array:return [v.x,v.y,v.z]),"directions":directions.map(func(v:Vector3)->Array:return [v.x,v.y,v.z]),"timber_done":timber_done,"feeder_isolated":feeder_isolated,"cache":cache.to_dict() if cache!=null else {}}
