extends SceneTree
## Real receiver presentation and tree -> fallen trunk -> fuel -> plank gameplay.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child: Node in node.get_children(): freeze(child)
func build_world() -> Node3D:
	var world: Node3D=load("res://world/game_world.gd").new();root.add_child(world)
	for frame in 600:
		await process_frame
		if world.opening!=null and world.gear!=null:break
	freeze(world);return world
func lit(lens: MeshInstance3D) -> bool:
	return (lens.material_override as StandardMaterial3D).emission_enabled
func aim(w: Node3D, eye: Vector3, target: Vector3) -> void:
	w.player.position=eye;var d:=target-eye
	w.player.yaw=atan2(-d.x,-d.z);w.player.pitch=atan2(d.y,Vector2(d.x,d.z).length())
func log_action(w: Node3D) -> Dictionary:
	w._update_prompt()
	for action: Dictionary in w._cands_cache:
		if String(action.text).begins_with("Split log ("):return action
	return {}
func aim_log(w: Node3D, log: WoodLog, t: float) -> void:
	var at:=log.p0.lerp(log.p1,t)
	var side:=log.dir.cross(Vector3.UP).normalized()
	var eye:=at+side*.8;eye.y=w.terrain.data.get_height(eye)+w.player.eye_h
	aim(w,eye,at+Vector3.UP*log.tree_r*.35)
func run() -> void:
	create_timer(120).timeout.connect(func()->void:print("FAIL diagnostic timeout");quit(2))
	SaveGame.pending={};seed(20261004)
	var w: Node3D=await build_world();var op: LookoutOpening=w.opening;var s: LookoutAssignment=op.state
	check(not lit(op._receiver_power) and not lit(op._receiver_channel),"receiver starts with both LEDs dark")
	op.toggle_receiver()
	check(lit(op._receiver_power) and lit(op._receiver_channel),"receiver switch lights both LEDs immediately")
	check((op._receiver_power.material_override as StandardMaterial3D).emission.g>.9,"powered receiver is green")
	check((op._receiver_channel.material_override as StandardMaterial3D).emission.b>.9 and op._channel_label.text=="PUBLIC","public is blue and labeled immediately")
	s.last_s=10*3600;op._radio_update();op.update_presentation()
	check(s.broadcast_at(s.last_s).is_empty() and lit(op._receiver_power),"broadcast silence does not imply receiver off")
	op.toggle_receiver();check(not lit(op._receiver_power) and not lit(op._receiver_channel),"receiver off extinguishes both LEDs immediately")
	op.toggle_receiver();s.last_s=s.grid_fail_s+1;s.backup_on=false;op.update_presentation()
	check(not lit(op._receiver_power) and not lit(op._receiver_channel),"mains outage extinguishes LEDs despite selected on switch")
	s.battery_wh=1;op.toggle_backup();check(lit(op._receiver_power),"backup restores receiver indicators immediately")
	w.clock.total_game_s=s.last_s+3600;op.advance(3600)
	check(s.battery_wh==0 and not lit(op._receiver_power) and not lit(op._receiver_channel),"battery exhaustion extinguishes both receiver LEDs")
	s.last_s=s.source_end_s+1;s.battery_wh=144;s.recovery_lock=false;s.backup_on=true;op.update_presentation() # scripted recharged battery: the exhaustion lock (4292c60) clears once recovered
	check(lit(op._receiver_power) and s.broadcast_at(s.last_s).is_empty(),"local power indicator survives distant transmitter shutdown")
	s.last_s=0;s.backup_on=false;w.clock.total_game_s=0;op.update_presentation()
	# Fell a real forest tree just outside the lookout fence, through chop and fall callbacks.
	var tree:=Vector3.ZERO;var nearest:=INF
	for trunks: Array in w.forest._trunks.values():
		for tr: Vector3 in trunks:
			var point:=Vector3(tr.x,w.terrain.data.get_height(Vector3(tr.x,0,tr.y)),tr.y)
			var local: Vector3=w.fire_lookout.to_local(point)
			var distance:=Vector2(local.x,local.z).length()
			if distance>15 and distance<nearest and not RefugeBoundary.BOUNDS.grow(2).has_point(Vector2(local.x,local.z)):
				tree=tr;nearest=distance
	check(nearest<60,"test uses an actual tree outside the lookout fence")
	var ground: float=w.terrain.data.get_height(Vector3(tree.x,0,tree.y))
	w.player.position=Vector3(tree.x-.9,ground+w.player.eye_h,tree.y)
	var key:=ForestScatter.tree_key(tree.x,tree.y)
	for hit in 80:
		if w.forest.felled.has(key):break
		w._chop_hit({"x":tree.x,"z":tree.y,"h":ForestScatter.tree_height_from_r(tree.z)})
	check(w.forest.felled.has(key),"hatchet chopping actually fells the outside tree")
	for child: Node in w.get_children():
		if child is FallingTree:child._process(10)
	var logs:=get_nodes_in_group("logs").filter(func(n:Node)->bool:return not n.has_meta("authored_stop"))
	check(logs.size()==1,"fall animation completion creates one harvestable log")
	if logs.size()!=1:w.queue_free();quit(1);return
	var log: WoodLog=logs[0]
	check(log.global_position.distance_to(log.center())<.001,"log node now has its actual world location")
	for t: float in [0,.5,1]:
		aim_log(w,log,t);check(not log_action(w).is_empty(),"visible trunk can be targeted at fraction %.1f"%t)
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	w.queue_free();await process_frame;await process_frame
	SaveGame.pending=snapshot;w=await build_world();op=w.opening
	check(op.state.receiver_on and op.walkie.get_parent()==w.player and lit(op._receiver_power) and op._channel_label.text=="PUBLIC","fresh save load restores public desk, personal walkie and actual LEDs")
	logs=get_nodes_in_group("logs").filter(func(n:Node)->bool:return not n.has_meta("authored_stop"));check(logs.size()==1,"fresh load restores unsplit log without duplicating it")
	log=logs[0] as WoodLog;aim_log(w,log,1)
	var action:=log_action(w);check(not action.is_empty(),"restored log remains targetable at far end")
	w._act_begin(action);w._act_update(.5,false)
	check(not log.is_queued_for_deletion(),"cancelled splitting leaves the trunk intact")
	var axe_condition: float=w.inv.condition("axe");w.inv.remove("axe");w._split_log(log)
	check(not log.is_queued_for_deletion(),"missing hatchet at completion cannot harvest trunk")
	w._update_prompt();check("Log (needs a hatchet equipped)" in w.hud.actions,"unequipped log explains tool requirement")
	w.inv.add("axe");w.inv.cond["axe"]=axe_condition;aim_log(w,log,.5);action=log_action(w)
	var wood: int=w.inv.count("wood");var sticks: int=w.inv.count("stick");var fw: int=log.firewood;var sk: int=log.sticks
	w._act_begin(action);check(is_equal_approx(w._act_hold,2.5),"log work retains halved 2.5 second action")
	w._act_update(2.51,true)
	check(log.is_queued_for_deletion() and w.inv.count("wood")==wood+fw and w.inv.count("stick")==sticks+sk,"completed trunk harvest yields existing fuel and sticks once")
	w._split_log(log);check(w.inv.count("wood")==wood+fw,"duplicate completion cannot duplicate wood")
	var before: int=w.inv.count("wood");var planks: int=w.inv.count("plank")
	check(w.craft_start("plank_split")=="","restored firewood enables existing plank recipe")
	w._craft_update(10.01)
	check(w.inv.count("wood")==before-1 and w.inv.count("plank")==planks+2,"plank crafting consumes one wood and makes two planks")
	# A full pack must drop finite yields rather than destroy the harvested wood.
	w._land_tree(tree.x,tree.y,Vector3.FORWARD,20,.3)
	log=get_nodes_in_group("logs").filter(func(n:Node)->bool:return not n.has_meta("authored_stop")).filter(func(n:Node)->bool:return not n.is_queued_for_deletion())[0] as WoodLog
	w.inv.counts["wood"]=100
	var dropped_before:=get_nodes_in_group("pickups").size();w._split_log(log)
	var dropped:=0
	for pickup: ItemPickup in get_nodes_in_group("pickups").slice(dropped_before):
		if pickup.id=="wood":dropped+=pickup.n
	check(dropped==log.firewood,"full backpack leaves harvested firewood on the ground")
	w.queue_free();await process_frame;await process_frame
	print("RADIO_LOG_TEST failures=",failures);quit(1 if failures else 0)
