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
	SaveGame.pending=saved;seed(20261004);var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.first_week!=null and w.gear!=null:break
	freeze(w);w.out_path="test-no-autosave";w._frames=100;return w
func action(w:Node3D,cn:Node3D,prefix:String) -> Dictionary:
	for a:Dictionary in w._carcass_actions(cn):
		if String(a.text).begins_with(prefix):return a
	return {}
func run() -> void:
	create_timer(200).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	Inventory.infinite=false
	var inv:=Inventory.new();inv.add("trout_raw",3);inv.age.trout_raw=3*3600
	var food:=CookBatch.new(2);food.begin(inv,false)
	check(food.portions.is_empty() and inv.count("trout_raw")==3,"unlit cabin cooking does not reserve food")
	food.begin(inv,true);food.begin(inv,true);food.begin(inv,true)
	check(food.portions.size()==2 and inv.count("trout_raw")==1,"two cabin slots reserve one portion per load and cannot overfill")
	food.advance(900,300);check(food.portions[0].remaining_s==900 and food.portions[0].age_s==3*3600+900,"food work stops at exact heat remainder while aging through all time")
	var restored:=CookBatch.new(2);restored.restore(JSON.parse_string(JSON.stringify(food.to_dict())))
	check(restored.portions==food.portions,"cabin cooking state preserves source-age basis and partial work through JSON")
	restored.advance(900,900);inv.add("wood",100)
	check(restored.collect(inv)==0 and restored.ready_count()==2,"full pack leaves completed cabin meals in their slots")
	inv.remove("wood",100);check(restored.collect(inv)==2 and restored.portions.is_empty(),"collection frees exactly occupied cabin slots")
	check(is_equal_approx(inv.age.trout_cooked,3.5/24*60*3600),"cabin collection retains raw-to-cooked shelf fraction")
	restored.restore({});check(restored.portions.is_empty(),"legacy cabin snapshot grants no extra meals")
	var single:=CookBatch.new(1);single.begin(inv,true);single.advance(10*3600,1200)
	check(single.ready_count()==1,"long frame can cook through its real heat then age finished fish")
	var split:=CookBatch.new(1);var input:=Inventory.new();input.add("trout_raw");input.age.trout_raw=3*3600;split.begin(input,true)
	for i in 10:split.advance(3600,1200 if i==0 else 0)
	check(single.portions==split.portions,"offscreen ten-hour batch matches ten smaller updates with same fuel")
	var cabin:=Cabin.new();cabin.stove_fuel_s=300;cabin.cooking.begin(input,true);cabin.advance(-20)
	check(cabin.stove_fuel_s==300,"negative elapsed time cannot replenish a cabin fire")
	cabin.advance(900);check(cabin.stove_fuel_s==0,"authoritative cabin clock burns only existing fuel");cabin.free()
	var w:Node3D=await build();var cb:Cabin=w.cabins[0];var op:LookoutOpening=w.opening
	w.inv=Inventory.new(w.body);w.inv.needs=w.needs;w.inv.add("trout_raw",3);cb.stove_fuel_s=9000
	var load:Dictionary=w._cabin_food_actions(cb)[0]
	w._act_begin(load);w._act_update(.4,true);w._act_update(.1,false)
	check(cb.cooking.portions.is_empty() and w.inv.count("trout_raw")==3,"actual cancelled cabin load consumes no raw food")
	w._act_begin(load);cb.stove_fuel_s=0;w._act_update(1,true)
	check(cb.cooking.portions.is_empty() and w.inv.count("trout_raw")==3,"completed load rechecks exhausted stove")
	cb.stove_fuel_s=9000;w._act_begin(load);w._act_update(1,true)
	check(cb.cooking.portions.size()==1 and w.inv.count("trout_raw")==2 and w._act_hold==1,"real cabin load has one-second globally halved wait, no instant cooked food")
	check(cb.cook_display.foods[0].visible and not cb.cook_display.foods[1].visible,"cabin skillets display only reserved food")
	w._act_begin(w._cabin_food_actions(cb)[0]);w._act_update(1,true)
	check(cb.cooking.free_slots()==0 and cb.cook_display.foods[1].visible,"second actual load occupies second pan only")
	cb.stove_fuel_s=300;cb.prepared_water.batch=1;cb.prepared_water.remaining_s=1200
	var start_game:float=w.clock.total_game_s;w.clock.time_scale=300;w.player.sim_on=true;w.player.sim_dir=Vector3.ZERO;w._process(1)
	check(w.clock.total_game_s-start_game==300 and cb.stove_fuel_s==0 and cb.cooking.portions[0].remaining_s==900,"world time advances cabin fuel and meals by the same authoritative 300 seconds")
	check(cb.prepared_water.remaining_s==900,"cabin water follows the same authoritative burn as food")
	cb._process(1);check(cb.cooking.portions[0].remaining_s==900 and cb.prepared_water.remaining_s==900,"visual cabin processing cannot burn fuel or advance food a second time")
	w.clock.time_scale=w.clock.base_time_scale
	var kill:Node3D=w._add_deer(w._ground(w.player.position.x+4,w.player.position.z),7109)
	kill.call("hit",99999,w.player.position);freeze(kill)
	check(Carcass.species_of(kill)=="deer" and kill.is_in_group("carcasses"),"actual killed deer enters harvest group")
	w.inv.add("knife");w.inv.cond.knife=0
	check(not Carcass.tool_step("deer","meat",w.inv).ok,"broken knife cannot grant full meat yield")
	w.inv.add("axe");w.inv.cond.axe=1
	check(Carcass.tool_step("deer","meat",w.inv).n==3 and Carcass.tool_step("deer","meat",w.inv).tool=="axe","usable axe fallback gives three portions rather than full knife yield")
	check(not Carcass.tool_step("deer","hide",w.inv).ok,"axe cannot skin or gut a carcass")
	w.inv.cond.knife=1;var quarter:=action(w,kill,"Quarter")
	var initial:Dictionary=w.inv.counts.duplicate();var calories:float=w.needs.calories
	w._act_begin(quarter);w._act_update(.4,true);w._act_update(.1,false)
	check(w.inv.counts==initial and not (kill.get_meta("done",{}) as Dictionary).get("meat",false),"cancelled butchery leaves carcass and inventory untouched")
	w._act_begin(quarter);w.inv.cond.knife=0;w._act_update(5,true)
	check(w.inv.count("venison_raw")==0 and w.needs.calories==calories and not (kill.get_meta("done",{}) as Dictionary).get("meat",false),"tool breaking during work cannot grant captured full yield or spend completion calories")
	w.inv.cond.knife=1;Carcass.advance_food(kill,10*3600)
	check(Carcass.food_age(kill)==3.5*3600,"outdoor carcass food ages at the existing 0.35 cold rate using game time")
	w._act_begin(action(w,kill,"Quarter"));w._act_update(5,true)
	check(w.inv.count("venison_raw")==6 and is_equal_approx(w.inv.age.venison_raw,3.5*3600),"successful harvest grants six finite portions retaining carcass age")
	check(is_equal_approx(w.inv.condition("knife"),.99) and w.needs.calories==calories-30,"successful knife quartering wears the chosen tool and spends calories once")
	w._carcass_step(kill,"deer","meat","venison_raw",6,"knife")
	check(w.inv.count("venison_raw")==6 and w.needs.calories==calories-30,"duplicate harvest callback cannot repeat meat, wear or costs")
	var axe_kill:Node3D=w._add_deer(w._ground(w.player.position.x+5,w.player.position.z),7110);axe_kill.call("hit",99999,w.player.position);freeze(axe_kill)
	w.inv.cond.knife=0;var axe_action:=action(w,axe_kill,"Quarter");w.inv.cond.axe=0;w._act_begin(axe_action);w._act_update(10,true)
	check(not (axe_kill.get_meta("done",{}) as Dictionary).get("meat",false),"stale axe action rechecks axe condition")
	w.inv.cond.axe=1;w._act_begin(action(w,axe_kill,"Quarter"));w._act_update(10,true)
	check(w.inv.count("venison_raw")==9 and is_equal_approx(w.inv.condition("axe"),.98),"completed axe work uses half yield, double time and exact axe wear")
	w.inv.cond.knife=1
	var aged:Node3D=w._add_deer(w._ground(w.player.position.x+6,w.player.position.z),7111);aged.call("hit",99999,w.player.position);freeze(aged)
	Carcass.advance_food(aged,Inventory.shelf_s("venison_raw")/StorageChest.COLD_RATE)
	check(String(action(w,aged,"Quarter").text).contains("spoiled"),"expired carcass advertises spoiled meat before harvesting")
	w._act_begin(action(w,aged,"Quarter"));w._act_update(5,true)
	check(w.inv.count("rotten_meat")==6 and w.inv.count("venison_raw")==9,"expired carcass cannot grant fresh meat")
	check(Carcass.open_steps("deer",aged.get_meta("done",{})).has("hide"),"meat spoilage does not silently erase remaining hide/gut work")

	var saved_inv:Inventory=w.inv;w.inv=Inventory.new(w.body);w.inv.needs=w.needs;w.inv.add("knife");w.inv.add("wood",36)
	var spill:Node3D=w._add_deer(w._ground(w.player.position.x+8,w.player.position.z),7113);spill.call("hit",99999,w.player.position);freeze(spill);Carcass.advance_food(spill,3600)
	w._act_begin(action(w,spill,"Quarter"));w._act_update(5,true)
	var dropped:ItemPickup
	for pickup:ItemPickup in get_nodes_in_group("pickups"):
		if pickup.id=="venison_raw" and pickup.n==5:dropped=pickup
	check(w.inv.count("venison_raw")==1 and dropped!=null,"weight-limited quartering retains one portion and leaves five on the ground")
	check(dropped!=null and is_equal_approx(dropped.age_s,1260),"spilled harvest retains carcass age on its ground pickup")
	check(is_equal_approx(w.inv.age.venison_raw,1260),"carried share retains the same carcass age as spilled harvest")
	check(is_equal_approx(w.inv.condition("knife"),.99),"full-pack harvest spends tool wear once even when food stays outside")
	w.inv=saved_inv
	if dropped!=null:dropped.queue_free()
	var pending:Node3D=w._add_deer(w._ground(w.player.position.x+7,w.player.position.z),7112);pending.call("hit",99999,w.player.position);freeze(pending);Carcass.advance_food(pending,3600)
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));var fuel:float=cb.stove_fuel_s
	w.queue_free();await process_frame;await process_frame;w=await build(snapshot);cb=w.cabins[0];op=w.opening
	check(cb.cooking.portions.size()==2 and cb.cooking.portions[0].remaining_s==900 and cb.stove_fuel_s==fuel,"fresh-world restore retains occupied pans, work and exact fuel")
	check(cb.cook_display.foods[0].visible and cb.cook_display.foods[1].visible,"restored cabin visuals match saved food stock")
	var found:Node3D
	for cn:Node3D in get_nodes_in_group("carcasses"):
		if not (cn.get_meta("done",{}) as Dictionary).get("meat",false) and is_equal_approx(Carcass.food_age(cn),1260):found=cn
	check(found!=null,"unharvested meat age survives a real world save/reload")
	cb.stove_fuel_s=900;cb.advance(900);var collect:Dictionary=w._cabin_food_actions(cb)[0];w._act_begin(collect)
	check(w.inv.count("trout_cooked")==2 and cb.cooking.portions.is_empty(),"restored cabin meals finish only after remaining real burn and collect through actual action")
	check(not cb.cook_display.foods[0].visible and not cb.cook_display.foods[1].visible,"collected cabin meals disappear from pans")
	check(cb.cook_display.find_children("*","CollisionObject3D",true,false).is_empty(),"skillets add no collision on walking surfaces")
	op.fuel_s=1200;op.cook();check(op.cook_display.foods[0].visible,"lookout stove now visibly shows its reserved portion")
	op.advance(1200);check(op.cook_display.marks[0].visible,"finished lookout portion shows searing and cooked state")
	op.take_cooked();check(not op.cook_display.foods[0].visible,"collecting lookout food empties its skillet")
	snapshot=JSON.parse_string(JSON.stringify(w._save_data()))
	for row:Dictionary in snapshot.cabins:
		row.stove=row.fire.fuel_s;row.prepared_water=row.fire.water;row.erase("fire") # pre-standard row: no pans recorded
	for row:Dictionary in snapshot.carcasses:row.erase("food_age_s")
	w.queue_free();await process_frame;await process_frame;w=await build(snapshot)
	check(w.cabins[0].cooking.portions.is_empty(),"legacy cabin state loads empty without inventing reserved meals")
	check(Carcass.food_age(get_nodes_in_group("carcasses")[0])==0,"legacy unrecorded carcass age starts tracking from restoration")
	w.queue_free();await process_frame;await process_frame;SaveGame.pending={}
	print("HUNT_COOKING_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
