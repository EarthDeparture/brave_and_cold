extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func build(saved:Dictionary={})->Node3D:
	SaveGame.pending=saved;seed(20261004)
	var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for f in 600:
		await process_frame
		if w.first_week!=null and w.reading!=null:break
	freeze(w);w.out_path="test-no-autosave";return w
func run()->void:
	create_timer(170).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	var inv:=Inventory.new(BodyTemperature.new());inv.needs=Needs.new();var pot:=PreparedWater.new()
	check(pot.begin(inv).contains("Bring"),"empty kettle cannot create water without snow and containers")
	inv.add("empty_bottle",4);inv.add("snow_portion",4);var total:=inv.total_weight()
	pot.begin(inv)
	check(pot.batch==4 and inv.count("empty_bottle")==0 and inv.count("snow_portion")==0,"starting batch reserves four snow portions and four bottles exactly once")
	pot.begin(inv);check(pot.batch==4,"repeated start cannot duplicate a batch")
	pot.advance(0);pot.advance(-10);check(pot.remaining_s==1200,"unlit or backwards time cannot boil water")
	pot.advance(600);check(pot.ready==0 and pot.remaining_s==600,"half batch cannot be collected")
	var snapshot:=pot.to_dict();var restored:=PreparedWater.new();restored.restore(snapshot)
	check(restored.remaining_s==600 and restored.batch==4,"part-boiled water preserves containers and progress")
	pot.advance(900);check(pot.ready==4 and pot.batch==0,"only finished burn creates exactly four clean portions")
	inv.add("wood",100);check(pot.collect(inv)==0 and pot.ready==4,"full backpack leaves finished water in kettle")
	inv.remove("wood",100);check(pot.collect(inv)==4 and pot.ready==0 and is_equal_approx(total,inv.total_weight()),"collection conserves bottle quantity and total prepared weight")
	inv.needs.water=50;inv.use("clean_water");check(inv.needs.water==75 and inv.count("clean_water")==3 and inv.count("empty_bottle")==1,"drinking adds hydration while retaining the reusable container")
	inv.needs.water=100;inv.use("clean_water");check(inv.count("clean_water")==3,"fully hydrated player cannot waste water")
	check(pot.collect(inv)==0,"repeated collection cannot duplicate finished water")
	restored.restore({});check(restored.ready==0 and restored.batch==0,"legacy kettle state creates no free water")
	var w:Node3D=await build();var op:LookoutOpening=w.opening;var route:FirstWeekRoute=w.first_week
	check(route.points.size()==3 and route.timber!=null,"new assignment authors all three stops on existing lookout track")
	var authored:Array=w.fire_lookout.site.path.points_world_xyz
	for point:Vector3 in route.points:
		var near:=INF
		for row:Array in authored:near=minf(near,Vector2(point.x,point.z).distance_to(Vector2(row[0],row[2])))
		check(near>1.85 and near<7.5,"roadside work stays beside actual preserved mountain access lane")
	check(route.points[0].distance_to(w.fire_lookout.global_position)<260,"first timber stop is reachable near the lookout rather than at unrelated town paths")
	check(route.points[0].distance_to(route.points[1])>60 and route.points[1].distance_to(route.points[2])>60,"authored stops are distinct destinations rather than overlapping markers")
	check(w._log_list().is_empty(),"authored trunk is saved by identity rather than duplicated as ordinary felled timber")
	var n:int=w.inv.count("wood");w._split_log(route.timber)
	check(route.timber_done and w.inv.count("wood")>n,"existing axe splitting completes authored timber and grants actual fuel")
	var saved_cache:int=route.cache.count("beans");w.chest_take(route.cache,"beans",1)
	check(route.cache.count("beans")==saved_cache-1,"crew cache supplies are actual finite inventory")
	w.inv.remove("service_kit");route.isolate();check(not route.feeder_isolated and op.state.field_load_w==6,"unqualified player cannot isolate live crew branch")
	w.inv.add("service_kit");route.isolate();w.reading.close()
	check(route.feeder_isolated and op.state.field_load_w==0,"service-kit isolation persistently removes real backup load")
	w.inv.add("snow_portion",4);var hydration:float=w.needs.water;op.boil()
	check(op.water.batch>0 and w.needs.water==hydration,"stove boil interaction starts preparation without instant hydration")
	op.fuel_s=300;op.advance(600);check(op.water.remaining_s==900,"boiling advances only through actual remaining stove burn")
	op.advance(600);check(op.water.remaining_s==900,"stove exhaustion pauses unfinished batch")
	var saved_positions:Array=route.points.duplicate();var save:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));w.queue_free();await process_frame;await process_frame
	w=await build(save);op=w.opening;route=w.first_week
	check(route.points==saved_positions,"saved authored stop positions stay fixed after forest depletion")
	check(route.timber_done and route.timber==null,"depleted authored trunk never respawns on load")
	check(route.cache.count("beans")==saved_cache-1 and route.feeder_isolated and op.state.field_load_w==0,"cache depletion and isolated supply survive fresh-world restoration")
	check(op.water.remaining_s==900 and op.water.batch>0,"unfinished water and reserved containers survive world save/load")
	op.fuel_s=900;op.advance(900);check(op.water.ready>0,"relit stove can finish saved batch")
	check(w.gear._entries("clean_water","pack",1)[0].label=="Drink 0.5 L","live inventory exposes water use before drop/store")
	print("ROUTE_SURVEY ",JSON.stringify(route.points.map(func(v:Vector3)->Array:return [v.x,v.y,v.z])))
	w.queue_free();await process_frame;await process_frame;SaveGame.pending={};print("FIRST_WEEK_CORE_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
