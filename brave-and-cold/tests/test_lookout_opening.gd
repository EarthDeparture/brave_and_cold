extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func freeze(node: Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func run() -> void:
	create_timer(120).timeout.connect(func()->void:print("FAIL diagnostic timeout");quit(2))
	SaveGame.pending = {};seed(20261004)
	var w: Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.hud != null and w.opening != null: break
	if w.opening == null: check(false,"opening builds");quit(1);return
	freeze(w)
	var op: LookoutOpening=w.opening;var s:=op.state;var p:Player=w.player
	check(w.fire_lookout.contains_room(p.position),"new assignment starts inside elevated lookout")
	check(w.inv.count("service_kit")==1 and w.inv.jacket()=="parka","technician starts with service kit and worn winter layers")
	check(w.pop.all_alive().is_empty(),"opening begins before zombie population seeds")
	check(op.pantry.count("beans")==4 and op.wood_left==6,"home stock is finite and explicit")
	# Check targets from free standing positions, rather than only calling helpers.
	var original_pos:=p.position
	for point:Vector3 in [Vector3(-.45,1.7,-.6),Vector3(-.4,1.7,.45),Vector3(0,1.7,-1.3),Vector3(.65,1.7,-.6),Vector3(1.7,1.7,.8)]:
		var standing:Vector3=w.fire_lookout.to_global(point+Vector3.UP*FireLookout.DECK_Y)
		var foot:=standing-Vector3.UP*p.eye_h
		check(w.fire_lookout.resolve_at(foot,foot,.35).distance_to(Vector2(foot.x,foot.z))<.001,"home interaction stance has free capsule at "+str(point))
	p.position=original_pos
	op.install_relay();check(s.repair_stage==0,"missing part cannot bypass inspection")
	op.inspect_relay();op.inspect_relay();check(s.repair_stage==1,"inspection is repeat-safe")
	op.claim_parts();op.claim_parts();check(w.inv.count("power_relay")==1 and s.parts_claimed,"reserved case yields exactly one guaranteed part")
	var interrupted:Dictionary=op._action(op.relay.global_position,"Install test",op.install_relay,6)
	w._act_begin(interrupted);w._act_update(1,false)
	check(s.repair_stage==1 and w.inv.count("power_relay")==1,"released timed maintenance consumes no part")
	w._act_begin(interrupted);p.position+=Vector3(1,0,0);w._act_update(.5,true)
	check(s.repair_stage==1 and w.inv.count("power_relay")==1,"movement interruption consumes no part");p.position-=Vector3(1,0,0)
	op.install_relay();op.install_relay();check(s.repair_stage==2 and w.inv.count("power_relay")==0,"installation consumes once")
	op.verify_relay();check(s.repair_stage==3,"verification commissions local relay")
	var old_fuel:=op.fuel_s;var old_wood:int=w.inv.count("wood")
	op.stoke();check(op.fuel_s==old_fuel+7200 and w.inv.count("wood")==old_wood-1,"stoking trades one log for two hours")
	op.fuel_s=0;w.inv.remove("matches",w.inv.count("matches"));old_wood=w.inv.count("wood");op.stoke()
	check(op.fuel_s==0 and w.inv.count("wood")==old_wood,"failed relight consumes no wood")
	w.inv.add("matches");op.stoke();check(op.fuel_s>0 and w.inv.count("matches")==0,"cold stove consumes one ignition match")
	w.inv.add("venison_raw");op.cook();op.fuel_s=30
	w.clock.total_game_s+=120;op.advance(120)
	check(is_equal_approx(float(op.cooking.remaining_s),1170),"cooking cannot advance beyond actual stove burn time")
	check(op.heat_at(w.fire_lookout.to_global(Vector3(0,1.7,0)))==0,"upstairs stove cannot heat ground through 21 metres")
	# Independent live devices seek elapsed audio; neither queues missed messages.
	s.walkie_carried=true;s.receiver_on=false;s.last_s=2.5*3600+96
	op._radio_update()
	check(op.walkie.playing and not op.speaker.playing and w.hud.radio_device=="dispatch","personal walkie receives live dispatch with desk off")
	check(absf(op.walkie.get_playback_position()-2)<.2,"late dispatch starts two real seconds into transmission")
	s.last_s=3*3600;op._radio_update()
	check(not op.walkie.playing and w.hud.radio_text=="","expired dispatch stops without backlog")
	s.last_s=6.5*3600;s.receiver_on=true;op._radio_update()
	check(op.speaker.playing and not op.walkie.playing,"desk reaches the live noon bulletin alone")
	s.receiver_on=false;op._radio_update()
	check(not op.speaker.playing and op.walkie.playing and w.hud.radio_device=="public","desk switch stops desk speaker; handset still monitors public signal")
	var boundary:=op.boundary
	var previous:=boundary.to_global(boundary.ground_local(1.9,8))
	var candidate:=boundary.to_global(boundary.ground_local(1.9,6.8))
	var blocked:=boundary.resolve_at(candidate,previous,.3)
	check(blocked.distance_to(Vector2(candidate.x,candidate.z))>.3,"closed gate blocks ground capsule")
	var ground_y:=previous.y
	var actor_blocked:=RoadNet.resolve_actor(candidate,previous,.3)
	check(actor_blocked.distance_to(Vector2(candidate.x,candidate.z))>.3,"creatures share gate collision")
	boundary.toggle_gate();var open:=boundary.resolve_at(candidate,previous,.3)
	check(open.distance_to(Vector2(candidate.x,candidate.z))<.001,"open aperture passes without steering jitter")
	check(not op.is_refuge(candidate),"open compound does not claim safe ground")
	boundary.toggle_gate()
	var point:=boundary.to_global(boundary.ground_local(0,0))
	check(not boundary.contains_ground(RefugeBoundary.safe_spawn(point)),"population materialization cannot occur inside closed refuge")
	var remote:=Vector3(-500,90,500);check(RefugeBoundary.resolve_actor(remote,remote+Vector3(.01,0,0),.3)==Vector2(remote.x,remote.z),"remote movement stays bit-exact")
	check(op.is_refuge(p.position),"upper home is defensible")
	w.body.core=35.0;check(w._sleep_block_reason()!="","refuge does not bypass hypothermia sleep rules")
	w.body.core=37;w.player.injury.wound(1,0);check(w._sleep_block_reason()!="","refuge does not bypass bleeding")
	w.player.injury=Injury.new();w.body.core=37
	w.drop_item("beans",1)
	var dropped:ItemPickup=get_nodes_in_group("pickups")[0]
	check(absf(dropped.global_position.y-(w.fire_lookout.global_position.y+FireLookout.DECK_Y))<.01,"items dropped at home stay on elevated floor")
	w.fire_lookout.restore_door({"boards":2,"plank_hp":13,"hp":73})
	var snapshot:Dictionary=w._save_data();var encoded:=JSON.stringify(snapshot);var decoded:Dictionary=JSON.parse_string(encoded)
	var saved_state:=LookoutAssignment.new();saved_state.restore(decoded.opening.state)
	check(is_equal_approx(saved_state.grid_fail_s,s.grid_fail_s) and is_equal_approx(saved_state.source_end_s,s.source_end_s) and saved_state.repair_stage==s.repair_stage and saved_state.parts_claimed==s.parts_claimed,"full world snapshot preserves opening state through JSON")
	check(int(decoded.opening.home.storage.c.beans)==op.pantry.count("beans"),"pantry inventory survives full snapshot")
	var recovered:=StorageChest.new();recovered.load_dict(decoded.opening.home.storage)
	check(recovered.contents==op.pantry.contents,"pantry restore does not refill supplies");recovered.free()
	var elevated:Dictionary=decoded.get("lookout_location",{})
	check(not elevated.is_empty(),"home save keeps elevated location")
	w._sleep_begin(w.fire_lookout,2)
	check(w._sl_on and not w.save_game(),"tower sleep uses existing rest system and blocks unsafe mid-sleep save")
	w._sleep_restore_clock();w._sl_on=false;w.player.sleeping=false
	# Scheduled world population must seed once even after long time skips.
	w.clock.total_game_s=29*3600;op.advance(0)
	check(s.zombies_seeded,"disruption seeds population once")
	s.backup_on=true;s.receiver_on=true;s.last_s=s.grid_fail_s;s.battery_wh=22
	w.clock.total_game_s=s.grid_fail_s+3600;op.advance(3600)
	check(s.battery_wh==0 and not s.powered(),"blackout and backup exhaustion affect live world")
	var lamp:=w.fire_lookout.get_node("LookoutDeskLamp") as OmniLight3D
	check(lamp.light_energy==0,"empty reserve extinguishes actual home lamp")
	w.queue_free();await process_frame;await process_frame
	check(RefugeBoundary.instances.is_empty(),"refuge registry cleans up on scene exit")
	SaveGame.pending=decoded
	var loaded:Node3D=load("res://world/game_world.gd").new();root.add_child(loaded)
	for frame in 600:
		await process_frame
		if loaded.hud!=null and loaded.opening!=null:break
	freeze(loaded)
	check(loaded.opening!=null and loaded.opening.state.repair_stage==3,"fresh world restores completed commissioning")
	check(loaded.opening.state.parts_claimed and loaded.inv.count("power_relay")==0,"loading cannot duplicate spent reservation")
	check(is_equal_approx(loaded.opening.state.grid_fail_s,saved_state.grid_fail_s),"loading does not reroll outage date")
	check(loaded.fire_lookout.contains_room(loaded.player.position),"fresh world restores elevated home")
	check(loaded.fire_lookout.door_boards==2 and loaded.fire_lookout.door_plank_hp==13 and loaded.fire_lookout.door_hp==73,"fresh world restores elevated door reinforcement and damage")
	var loaded_pickup:ItemPickup=get_nodes_in_group("pickups")[0]
	check(absf(loaded_pickup.global_position.y-(loaded.fire_lookout.global_position.y+FireLookout.DECK_Y))<.01,"loading retains dropped item elevation")
	check(loaded.opening.pantry.count("beans")==4,"loading preserves pantry without double spawn")
	var legacy:Dictionary=loaded._save_data();legacy.erase("opening")
	loaded.queue_free();await process_frame;await process_frame
	SaveGame.pending=legacy
	var old:Node3D=load("res://world/game_world.gd").new();root.add_child(old)
	for frame in 600:
		await process_frame
		if old.hud!=null:break
	freeze(old)
	check(old.opening==null,"save without opening state retains legacy survival")
	old.queue_free();await process_frame;await process_frame
	print("LOOKOUT_OPENING_TEST failures=",failures)
	quit(1 if failures else 0)
