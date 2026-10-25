extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n:Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func build(saved:Dictionary={}) -> Node3D:
	SaveGame.pending=saved;seed(20261004)
	var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.first_week!=null and w.reading!=null:break
	freeze(w);w.out_path="test-no-autosave";w._frames=100;return w
func run() -> void:
	create_timer(180).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	Inventory.infinite=false
	for id:String in FoodPreservation.RECIPES:
		var out:String=FoodPreservation.RECIPES[id]
		check(Inventory.ITEMS[id].kcal==Inventory.ITEMS[out].kcal,"drying conserves calories: "+id)
		check(is_equal_approx(Inventory.weight_of(out),Inventory.weight_of(id)*.5),"drying halves portion mass: "+id)
		check(Inventory.shelf_s(out)==240*3600,"bounded ten-day normal shelf life: "+id)
	var inv:=Inventory.new();var rack:=FoodPreservation.new()
	check(rack.reason(inv).contains("knife"),"no knife cannot prepare portions")
	inv.add("knife");inv.add("venison_raw",4)
	check(rack.reason(inv).contains("Cook"),"raw meat cannot skip cooking")
	inv.add("venison_cooked",5);inv.age.venison_cooked=36*3600.0
	inv.cond.knife=.03;var before:=inv.counts.duplicate()
	rack.begin(inv);check(rack.portions.is_empty() and inv.counts==before,"broken or inadequate knife commits no ingredients")
	inv.cond.knife=1.0;rack.begin(inv)
	check(rack.portions.size()==4 and inv.count("venison_cooked")==1,"one load reserves exactly four cooked portions")
	check(is_equal_approx(inv.condition("knife"),.96),"slicing wears knife by one percent per actual portion")
	rack.begin(inv);check(inv.count("venison_cooked")==1,"repeated load cannot duplicate or consume another batch")
	rack.advance(-100,100);check(rack.portions[0].remaining_s==7200,"negative wall time cannot progress drying")
	rack.advance(3600,300)
	check(rack.portions[0].remaining_s==6900 and rack.portions[0].age_s==37*3600,"short fuel pauses heat while all elapsed time ages food")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(rack.to_dict()));var resumed:=FoodPreservation.new();resumed.restore(saved)
	check(resumed.portions==rack.portions,"JSON round trip preserves reserved quantity, progress and original age")
	resumed.advance(6900,6900)
	var expected:=((37*3600.0+6900)/(72*3600.0))*240*3600
	check(resumed.ready_count()==4 and is_equal_approx(resumed.portions[0].age_s,expected),"completion retains spent fraction of cooked shelf life")
	inv.add("wood",100);check(resumed.collect(inv)==0 and resumed.ready_count()==4,"full pack retains all rack food")
	resumed.advance(3600,0);check(is_equal_approx(resumed.portions[0].age_s,expected+3600),"finished food ages before collection without heat")
	inv.remove("wood",100);check(resumed.collect(inv)==4 and resumed.portions.is_empty(),"finished batch collects once after space is made")
	check(is_equal_approx(float(inv.age.venison_dried),expected+3600),"collection preserves rack age into inventory")
	check(resumed.collect(inv)==0,"repeated collection yields nothing")
	var dying:=FoodPortion.create("venison_cooked","venison_dried",7200,71.5*3600)
	FoodPortion.advance(dying,7200,7200);check(dying.id=="rotten_meat","food expiring before drying completes becomes spoiled, never preserved")
	var whole:=FoodPortion.create("trout_cooked","trout_dried",7200,10*3600)
	var slices:Dictionary=whole.duplicate(true);FoodPortion.advance(whole,28800,28800)
	for i in 8:FoodPortion.advance(slices,3600,3600)
	check(whole==slices,"long sleep step equals sliced burn and ready-food aging")
	FoodPortion.advance(whole,240*3600,0);check(whole.id=="rotten_meat","uncollected dried food eventually spoils")
	resumed.restore({});check(resumed.portions.is_empty(),"legacy save receives no free preserved food")
	var fire:=Campfire.new();fire.fuel_s=300;fire.start_cook("trout_cooked","trout_raw",3600)
	fire.advance(900);check(fire.cooking.portions[0].remaining_s==900 and fire.fuel_s==0,"campfire cooks only through its actual 300-second fuel remainder")
	fire.advance(900);check(fire.cooking.portions[0].remaining_s==900 and fire.cooking.portions[0].age_s==5400 and not fire.fire.has_embers(),"unlit campfire still ages its unfinished fish")
	fire.free()
	inv=Inventory.new();inv.add("venison_raw");inv.age.venison_raw=15*3600.0
	var cooked:=CookBatch.new(1);cooked.begin(inv,true);cooked.advance(1200,1200);cooked.collect(inv)
	check(is_equal_approx(float(inv.age.venison_cooked),36.8*3600),"timed raw-to-cooked preparation retains shelf fraction through actual burn")

	var w:Node3D=await build();var op:LookoutOpening=w.opening
	check(op.preservation.portions.is_empty() and op.drying_rack!=null,"new game presents an empty original drying rack without food gifts")
	check(is_equal_approx(op.drying_rack.position.y-FireLookout.DECK_Y,.25),"rack bolts to timber wall below the window rather than floating on glass")
	op.advance(1);check(is_equal_approx(op.pantry.spoilage_rate,Spoilage.rate_c(w.air_at(w.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+1,0))))),"indoor pantry ages food at the lookout room's air, not outdoor snow cooling (%.2fx)"%op.pantry.spoilage_rate)
	w.inv=Inventory.new(w.body);w.inv.needs=w.needs;w.inv.add("knife");w.inv.add("venison_raw");w.inv.age.venison_raw=3600
	op.fuel_s=300;op.cook();op.advance(900)
	check(op.cooking.portions[0].remaining_s==900 and op.cooking.portions[0].age_s==4500,"actual lookout cooking follows heat limit and input age")
	op.fuel_s=900;op.advance(900);op.take_cooked()
	check(w.inv.count("venison_cooked")==1 and op.cooking.portions.is_empty(),"lookout stove collection moves exactly one cooked portion")
	var cooked_age:=float(w.inv.age.venison_cooked)
	check(cooked_age>3600,"cooking changes shelf fraction rather than resetting raw age")
	op.fuel_s=0;op.dry_food();check(op.preservation.portions.is_empty(),"unlit rack start leaves cooked food in pack")
	op.fuel_s=9000
	var load_action:Dictionary={}
	for a:Dictionary in op.actions():
		if String(a.text).begins_with("Load cooked meat"):load_action=a
	var initial_food:int=w.inv.count("venison_cooked");var initial_knife:float=w.inv.condition("knife")
	w._act_begin(load_action);w._act_update(.4,true);op._process(.4)
	var door:=op.drying_rack.find_child("RackDoor",true,false) as Node3D
	check(door!=null and door.rotation.y<-.9 and op.preservation.portions.is_empty(),"loading opens rack door before any ingredient transaction")
	w._act_update(.1,false);op._process(.5)
	check(door.rotation.y==0 and w.inv.count("venison_cooked")==initial_food and w.inv.condition("knife")==initial_knife,"cancelled load closes door and consumes neither knife nor food")
	w._act_begin(load_action);w.player.health-=1;w._act_update(.1,true)
	check(w._act.is_empty() and op.preservation.portions.is_empty(),"damage cancels actual food preparation")
	w._act_begin(load_action);w.inv.cond.knife=.01;w._act_update(2,true)
	check(op.preservation.portions.is_empty() and w.inv.count("venison_cooked")==initial_food,"completion rechecks changed knife condition without taking food")
	w.inv.cond.knife=initial_knife;w._act_begin(load_action);w._act_update(2,true)
	check(is_equal_approx(w._act_hold,2),"loading retains globally halved two-second active wait")
	check(op.preservation.portions.size()==1 and w.inv.count("venison_cooked")==0,"actual rack interaction reserves food after stove validation")
	var amount:Dictionary=w.inv.counts.duplicate();op.dry_food();check(w.inv.counts==amount,"repeated world action cannot start occupied rack")
	var pnode:=op.drying_rack.find_child("Portion0",true,false) as Node3D
	check(pnode!=null and pnode.visible,"rack shows actual loaded portion stock")
	var other:=op.drying_rack.find_child("Portion1",true,false) as Node3D
	check(other!=null and not other.visible,"unloaded shelves do not visually invent portions")
	w.inv.add("trout_cooked");w.inv.age.trout_cooked=12*3600;w.drop_item("trout_cooked",1)
	var pickup:ItemPickup
	for node:ItemPickup in get_nodes_in_group("pickups"):
		if node.id=="trout_cooked":pickup=node
	check(pickup!=null and pickup.age_s==12*3600,"dropping food carries its original age")
	pickup.tick(3600);w.take_pickup(pickup)
	check(w.inv.age.trout_cooked==13*3600,"picking up food cannot refresh it and counts ground time")
	w.inv.add("whitefish_cooked");w.inv.age.whitefish_cooked=10*3600;w.drop_item("whitefish_cooked",1)
	op.advance(1800);var save:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free();await process_frame;await process_frame;w=await build(save);op=w.opening
	check(op.preservation.portions.size()==1 and op.preservation.portions[0].remaining_s==5400,"world reload retains loaded rack and exact drying progress")
	pickup=null
	for node:ItemPickup in get_nodes_in_group("pickups"):
		if node.id=="whitefish_cooked":pickup=node
	check(pickup!=null and pickup.age_s==10*3600,"food pickup ages survive fresh-world save restoration")
	op.fuel_s=5400;op.advance(5400);op.take_dried()
	check(w.inv.count("venison_dried")==1 and op.preservation.portions.is_empty(),"saved rack completes after remaining real fuel burn")
	check(not (op.drying_rack.find_child("Portion0",true,false) as Node3D).visible,"collected rack visibly empties")
	w.chest_put(op.pantry,"venison_dried",1);var stored_age:=float(op.pantry.age.venison_dried)
	op.advance(3600);var prate:=op.pantry.spoilage_rate;w.chest_take(op.pantry,"venison_dried",1)
	check(is_equal_approx(float(w.inv.age.venison_dried),stored_age+3600*prate),"storage and retrieval preserve dried age at correct indoor rate")
	pickup.tick(Inventory.shelf_s("whitefish_cooked"));check(pickup.id=="rotten_meat","ground food eventually spoils and cannot become free fresh food")
	var outdoor:=Campfire.new();w.add_child(outdoor);w.campfires.append(outdoor);freeze(outdoor)
	w.inv.add("pike_raw");w.inv.age.pike_raw=8*3600
	check(w._cook_start(outdoor)==0 and w.inv.count("pike_raw")==1,"cold campfire cannot take food (standard: cook only while lit)")
	outdoor.fuel_s=1200
	check(w._cook_start(outdoor)==1 and w.inv.count("pike_raw")==0,"actual campfire loading reserves raw fish once")
	outdoor.advance(1200)
	var fire_age:float=outdoor.cooking.portions[0].age_s
	w.inv.add("wood",100);w._take_cooked(outdoor)
	check(outdoor.cooking.portions.size()==1 and w.inv.count("pike_cooked")==0,"actual full-pack campfire collection retains prepared food instead of losing age on a fresh ground drop")
	w.inv.remove("wood",100);w._take_cooked(outdoor)
	check(w.inv.count("pike_cooked")==1 and outdoor.cooking.portions.is_empty() and is_equal_approx(w.inv.age.pike_cooked,fire_age),"actual campfire collection retains finished portion age")
	check(op.drying_rack.find_children("*","CollisionObject3D",true,false).is_empty(),"rack exports no invisible collider through the room walking area")
	op.read_food_notes();check(w.reading.is_open,"food preparation notes use readable dismissible modal");w.reading.close()
	w.queue_free();await process_frame;await process_frame;SaveGame.pending={}
	print("FOOD_PRESERVATION_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
