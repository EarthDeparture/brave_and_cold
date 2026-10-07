extends "res://tests/measure_opening_route.gd"
## Controlled static prey beside the cleared access track; actual movement,
## ballistic hit, harvest action, game clock and home preparation. Not AI balance.
func run() -> void:
	create_timer(240).timeout.connect(func()->void:print("FAIL hunt route timeout");quit(2))
	output="res://shots/hunt-cooking-2026-10-07/";DirAccess.make_dir_recursive_absolute(output)
	SaveGame.pending={};Inventory.infinite=false;seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	freeze(w);w.out_path="measurement-no-autosave";w._frames=100
	w.player.sim_on=true;w.player.sim_dir=Vector3.ZERO
	w.clock.hour=5.5;w.clock.day=1;w.clock.total_game_s=0
	w.opening.state.last_s=0;w.opening.state.align_calendar(1,5.5,0,true)
	w.body.core=37;w.needs.calories=2000;w.needs.water=85;w.needs.fatigue=0
	w.inv.add("rifle");w.inv.add("ammo",3);w.inv.add("knife");w.inv.cond.knife=1
	var initial_fuel:float=w.opening.fuel_s;var initial_ammo:int=w.inv.count("ammo")
	var tower:FireLookout=w.fire_lookout
	var ok:bool=await walk(tower.to_global(Vector3(.65,0,.05)))
	if ok:w.opening.toggle_walkie_dock()
	mark("depart_room")
	if not tower.door_open:tower.toggle_door()
	var stairs:Array[Vector3]=[tower.to_global(Vector3(0,0,2.8)),tower.to_global(Vector3(3.45,0,2.3)),tower.to_global(Vector3(4.45,0,2.1)),tower.to_global(Vector3(5.80,0,2.1))]
	for flight in range(FireLookout.FLIGHT_COUNT-1,-1,-1):
		var z:float=2.1 if flight%2==0 else -2.1
		stairs.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[flight%2],0,z)))
		if flight>0:stairs.append(tower.to_global(Vector3(FireLookout.STAIR_LANES[(flight-1)%2],0,z)))
	if ok:ok=await chain(stairs)
	if not w.opening.boundary.gate_open:w.opening.boundary.toggle_gate()
	var ground_route:Array[Vector3]=[tower.to_global(Vector3(-5,0,4)),tower.to_global(Vector3(1.9,0,6)),tower.to_global(Vector3(1.9,0,8.8))]
	if ok:ok=await chain(ground_route)
	mark("outside_gate")
	var prey:Node3D=w._add_deer(w._ground(tower.to_global(Vector3(1.9,0,17)).x,tower.to_global(Vector3(1.9,0,17)).z),7109)
	freeze(prey);w.instant_bullets=true;w.player.aim_k=1
	if ok:
		w.player.cam.look_at(prey.to_global(Vector3(.85,1.6,0)));w._shoot()
		if not prey.is_in_group("carcasses"):failed="Controlled ballistic hunt did not kill target";ok=false
	mark("ballistic_kill")
	if ok:ok=await walk(prey.global_position-Vector3(0,0,1.0))
	if ok:
		var quarter:Dictionary=w._carcass_actions(prey)[0];quarter.auto=true;w._act_begin(quarter)
		for i in 180:
			await tick()
			if w._act.is_empty():break
		if w.inv.count("venison_raw")!=6:failed="Harvest did not yield six finite portions";ok=false
	mark("harvested")
	ground_route.reverse();stairs.reverse()
	if ok:ok=await chain(ground_route)
	if ok:ok=await walk(tower.to_global(Vector3(-5,0,4)))
	if ok:ok=await walk(tower.to_global(Vector3(1.9,0,6)))
	if ok:ok=await chain(stairs)
	if ok:ok=await walk(w.opening.home_point(Vector3(-.50,0,.45)))
	mark("returned_stove")
	if ok:ok=await action("Cook one portion on stove")
	if ok:
		for i in 3000:
			if w.opening.cooking.remaining_s<=0:break
			await tick()
		if w.opening.cooking.remaining_s>0:failed="Stove portion did not finish";ok=false
	if ok:ok=await action("Take cooked food")
	mark("cooked")
	if ok:
		if w.player.position.distance_to(w.opening.home_point(Vector3(-1.94,.65,.35)))>3:failed="Drying rack out of reach";ok=false
		else:
			var drying:Dictionary
			for entry:Dictionary in w.opening.actions():
				if String(entry.text).begins_with("Load cooked meat"):drying=entry
			if drying.is_empty():failed="Missing drying load action";ok=false
			else:
				drying.auto=true;w._act_begin(drying)
				for i in 90:await tick()
	if ok:
		for i in 16000:
			if w.opening.preservation.ready_count()>0:break
			await tick()
		if w.opening.preservation.ready_count()==0:failed="Reserved food did not dry with initial stove fuel";ok=false
	if ok:
		w.opening.take_dried()
		if w.inv.count("venison_dried")!=1:failed="Dried harvest not collectable";ok=false
	mark("preserved")
	var food_message:=""
	if ok:food_message=w.inv.use("venison_dried")
	mark("ate")
	var receipt:Dictionary={"completed":ok and failed.is_empty(),"failure":failed,"samples":samples,"ammo_spent":initial_ammo-w.inv.count("ammo"),"knife_condition":w.inv.condition("knife"),"stove_fuel_game_s_spent":initial_fuel-w.opening.fuel_s,"raw_remaining":w.inv.count("venison_raw"),"food_message":food_message,"limitations":"Controlled static deer, supplied rifle/three rounds/knife and direct aimed action selection. Actual ballistic trace, Player collision, survival/weather clock, finite fuel, harvesting/cooking/preservation. Entity AI frozen; does not measure natural prey availability, search time, pursuit, predator danger or human difficulty. No user save files used."}
	var file:=FileAccess.open(output+"hunt-route.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt,"  "));file.close()
	print("HUNT_ROUTE_MEASURE ",JSON.stringify(receipt))
	w.queue_free();await process_frame;SaveGame.pending={};quit(0 if ok and failed.is_empty() else 1)
