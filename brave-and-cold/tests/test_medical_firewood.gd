extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c:Node in n.get_children():freeze(c)
func build(saved:Dictionary={})->Node3D:
	SaveGame.pending=saved;seed(20261004)
	var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null:break
	freeze(w);w.out_path="test-no-autosave";return w
func wood(op:LookoutOpening)->int:
	return (op._stock.get_node("Stock_wood") as MultiMeshInstance3D).multimesh.instance_count
func ui_event(g:GearScreen,code:MouseButton,point:Vector2,down:bool)->void:
	var e:=InputEventMouseButton.new();e.button_index=code;e.position=g._origin()+point*g._scale();e.pressed=down;g._on_gui(e)
func run()->void:
	create_timer(150).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	var w:Node3D=await build();var op:LookoutOpening=w.opening;var p:Player=w.player;var g:GearScreen=w.gear
	check(op.wood_left==6 and op.pantry.count("wood")==6 and wood(op)==6,"new game has six real stored and visible logs")
	check(op.fuel_s+op.wood_left*7200+w.inv.count("wood")*7200==24*3600,"starting stove/rack/pack fuel lasts one day: restock before the second night")
	p.health=70;p.injury.wound(1,0);w.needs.calories=2000;w.needs.water=85;w.body.core=37
	var old_hp:=p.health;w._process(1)
	check(p.health<old_hp and p.injury.bleeding(),"real world update loses blood during untreated bleeding")
	g.open();g._process(0);await process_frame;await process_frame
	var stack_index:=-1;var stacks:Array=w.inv.stacks()
	for index in stacks.size():
		if stacks[index].id=="bandage":stack_index=index;break
	check(stack_index>=0,"starter bandage appears in live inventory")
	var entries:=g._entries("bandage","pack",1)
	check(entries[0].label=="Apply bandage","medical use is first action ahead of drop and store")
	check(g._entries("antiseptic","pack",1)[0].label=="Clean wound" and g._entries("antibiotics","pack",1)[0].label=="Take antibiotics","other medicines also have working use actions")
	var point:=g._pack_rect(stack_index).get_center();var bandages:int=w.inv.count("bandage");old_hp=p.health
	ui_event(g,MOUSE_BUTTON_LEFT,point,true);ui_event(g,MOUSE_BUTTON_LEFT,point,false)
	ui_event(g,MOUSE_BUTTON_LEFT,point,true);ui_event(g,MOUSE_BUTTON_LEFT,point,false)
	check(not p.injury.bleeding() and w.inv.count("bandage")==bandages-1 and p.health==old_hp,"actual inventory double-click consumes bandage and stops bleeding without instant healing")
	check(get_nodes_in_group("pickups").filter(func(p:ItemPickup)->bool:return not Inventory.is_rifle(p.id)).is_empty(),"using medical item never drops it on ground")
	w.inv.add("bandage",2);p.injury.wound(.5,0)
	ui_event(g,MOUSE_BUTTON_RIGHT,point,true)
	check(not g._menu.is_empty() and g._menu.entries[0].label=="Apply bandage","right-click menu offers treatment first")
	(g._menu.entries[0].act as Callable).call();g._menu={}
	check(not p.injury.bleeding() and w.inv.count("bandage")==1,"right-click treatment consumes exactly one")
	var unused:int=w.inv.count("bandage");w.gear_use("bandage")
	check(w.inv.count("bandage")==unused,"clicking treatment when not bleeding preserves bandage")
	var stray:=Injury.new();stray.bleed=1;Inventory.injury=stray;p.injury.wound(.6,0);w.gear_use("bandage")
	check(not p.injury.bleeding() and stray.bleeding(),"treatment targets current player rather than stale global wound object")
	g.close();p.health=60;p.injury.inf_t=-1;w.needs.calories=2000;w.needs.water=85;w.body.core=37
	old_hp=p.health;var old_s:float=w.clock.total_game_s;w._process(.1)
	check(is_equal_approx(p.health-old_hp,(w.clock.total_game_s-old_s)/3600),"world has one awake recovery pass on actual advanced game seconds")
	w.needs.calories=900;old_hp=p.health;w._process(.1)
	check(p.health==old_hp,"low food blocks recovery in actual world update")
	w.needs.calories=2000;w.needs.water=45;old_hp=p.health;w._process(.1)
	check(p.health==old_hp,"low water blocks recovery in actual world update")
	w.needs.water=85;w.body.core=37;w._sleep_begin(w.fire_lookout,2);w._sleep_update(w.SLEEP_FADE)
	old_hp=p.health;old_s=w.clock.total_game_s;w._process(.1)
	check(is_equal_approx(p.health-old_hp,3*(w.clock.total_game_s-old_s)/3600),"accelerated sleep uses same recovery once rather than both old and new healing")
	w.needs.calories=100;old_hp=p.health;w._process(.1)
	check(p.health==old_hp,"sleep cannot regain blood below nutrition threshold")
	w._sleep_restore_clock();w._sl_on=false;p.sleeping=false;w.hud.sleep_fade=0
	w.inv.add("wood",6);var pack_before:int=w.inv.count("wood");w.chest_put(op.pantry,"wood",3)
	check(op.wood_left==9 and wood(op)==9 and w.inv.count("wood")==pack_before-3,"inventory storage deposits synchronously add correctly placed logs to rack")
	var pile:=op._stock.get_node("Stock_wood") as MultiMeshInstance3D
	check(is_equal_approx(pile.global_position.y,w.fire_lookout.global_position.y+FireLookout.DECK_Y) and op._stock.find_children("*","CollisionShape3D",true,false).is_empty(),"deposited pile stays on elevated lookout floor without adding walking obstacles")
	op.take_wood();check(op.wood_left==8 and wood(op)==8,"rack withdrawal removes matching stored and visible unit")
	op.stack_wood();check(op.wood_left==12 and wood(op)==12,"physical Stack firewood action replenishes the visible rack")
	var conserved:int=op.wood_left+w.inv.count("wood");op.stack_wood()
	check(op.wood_left==12 and conserved==op.wood_left+w.inv.count("wood"),"full rack action never duplicates or consumes excess wood")
	w.inv.add("wood",7);w.chest_put(op.pantry,"wood",7)
	check(op.wood_left==19 and wood(op)==12 and op._stock_label.text.contains("extra stock stored"),"storage overflow stays authoritative while visible pile remains bounded")
	w.chest_take(op.pantry,"wood",10)
	check(op.wood_left==9 and wood(op)==9,"gear withdrawal and rack withdrawal share one stock count")
	w.chest_take(op.pantry,"wood",9)
	check(op.wood_left==0 and wood(op)==0,"emptying storage clears every visible log")
	w.inv.counts["wood"]=5;w.chest_put(op.pantry,"wood",5)
	check(op.wood_left==5 and wood(op)==5,"restocking a fully emptied rack restores original stacked transforms")
	var fuel_before:float=op.fuel_s;var pack_fuel:int=w.inv.count("wood");op.take_wood();op.stoke()
	check(op.wood_left==4 and wood(op)==4 and op.fuel_s==fuel_before+7200 and w.inv.count("wood")==pack_fuel,"stored gathered log can be taken and burned exactly once")
	var saved_fuel:float=op.fuel_s;var saved_matches:int=w.inv.count("matches")
	w.inv.counts["wood"]=2;op.fuel_s=11*3600;op.stoke()
	check(op.fuel_s==11*3600 and w.inv.count("wood")==2 and w.inv.count("matches")==saved_matches,"nearly full stove preserves whole log rather than discarding partial burn time")
	op.fuel_s=10*3600;op.stoke()
	check(op.fuel_s==12*3600 and w.inv.count("wood")==1,"stove accepts a complete two-hour log at exact remaining capacity")
	op.fuel_s=0;w.inv.counts.erase("matches");op.stoke()
	check(op.fuel_s==0 and w.inv.count("wood")==1,"unlit stove cannot consume wood without a match")
	w.inv.add("matches",1);op.stoke()
	check(op.fuel_s==7200 and w.inv.count("wood")==0 and w.inv.count("matches")==0,"relighting consumes one match and one log for full two-hour burn")
	op.fuel_s=saved_fuel;w.inv.add("matches",saved_matches)
	w.inv.counts["wood"]=100;op.take_wood()
	check(op.wood_left==4 and wood(op)==4,"full backpack cannot remove a visible or stored log")
	w.inv.counts["wood"]=1;var save:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	check(save.opening.home.schema==2 and save.opening.home.storage.c.wood==4,"new home schema identifies unified saved wood inventory")
	w.queue_free();await process_frame;await process_frame;w=await build(save);op=w.opening
	check(op.wood_left==4 and wood(op)==4 and w.player.health==save.player.hp,"fresh loading preserves rack and blood without refill")
	var again:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));w.queue_free();await process_frame;await process_frame;w=await build(again);op=w.opening
	check(op.wood_left==4 and wood(op)==4,"repeated schema-two loading cannot double-count diagnostic wood_left")
	# Legacy save had collected wood in storage plus a separate loose rack.
	var legacy:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));legacy.opening.home.erase("schema");legacy.opening.home.wood_left=7;legacy.opening.home.storage.c.wood=3;legacy.opening.home.storage.cond.wood=.5
	w.queue_free();await process_frame;await process_frame;w=await build(legacy);op=w.opening
	check(op.wood_left==10 and wood(op)==10 and is_equal_approx(op.pantry.cond.wood,.85),"legacy loose and collected logs merge once while preserving weighted condition")
	again=JSON.parse_string(JSON.stringify(w._save_data()));w.queue_free();await process_frame;await process_frame;w=await build(again);op=w.opening
	check(op.wood_left==10 and wood(op)==10,"migrated save reload does not recreate original loose reserve")
	w.queue_free();await process_frame;await process_frame;SaveGame.pending={};print("MEDICAL_FIREWOOD_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
