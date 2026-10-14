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
		if w.first_week!=null and w.opening!=null and w.opening.electrical!=null and w.reading!=null and w.gear!=null:break
	freeze(w);w.out_path="test-no-autosave";w._frames=100;return w
func act(w:Node3D,prefix:String) -> Dictionary:
	for a:Dictionary in w.opening.electrical.actions():
		if String(a.text).begins_with(prefix):return a
	return {}
func fit_parts(inv:Inventory) -> void:
	for id:String in ["service_kit","winter_controller","sealed_connector","dc_cable"]:
		if inv.count(id)==0:inv.add(id)
func run() -> void:
	create_timer(180).timeout.connect(func()->void:print("FAIL timeout");quit(2))
	Inventory.infinite=false
	var inv:=Inventory.new();var service:=ElectricalService.new();var pv:=SolarSupply.new();pv.enabled=true
	inv.add("rifle");inv.add("axe");inv.add("wood",32);inv.add("plank",2)
	var before:Dictionary=inv.counts.duplicate()
	check(inv.can_add("dc_fuse") and not service.claim_packet(inv) and inv.counts==before and not service.packet_claimed,"combined packet rejects weight overflow without spending or partial issue")
	inv.counts={"knife":23};before=inv.counts.duplicate()
	check(inv.can_add("dc_fuse") and not service.claim_packet(inv) and inv.counts==before,"combined packet rejects second-item slot overflow atomically")
	inv.counts={}
	check(service.claim_packet(inv) and inv.count("dc_fuse")==1 and inv.count("sealed_connector")==1,"finite sealed packet delivers one correct fuse and connector pair")
	check(not service.claim_packet(inv) and inv.count("dc_fuse")==1,"duplicate packet claim grants nothing")
	check(not service.recover_cable(inv,false) and not service.cable_claimed,"live crew feeder cannot yield a cable")
	check(not service.recover_cable(inv,true),"isolated cable still requires an insulated service kit")
	inv.add("service_kit");inv.add("wood",100)
	check(not service.recover_cable(inv,true) and not service.claim_controller(inv) and not service.cable_claimed and not service.controller_claimed,"full pack leaves both finite field parts at their destinations")
	inv.remove("wood",100)
	check(service.recover_cable(inv,true) and service.claim_controller(inv),"isolated tested cable and depot controller are independently issued")
	check(not service.recover_cable(inv,true) and not service.claim_controller(inv),"repeating recovery and controller issue cannot refill stock")
	before=inv.counts.duplicate()
	check(not service.fit_controller(inv,pv,false) and inv.counts==before,"optional refit cannot bypass transfer relay commissioning")
	inv.remove("sealed_connector");before=inv.counts.duplicate()
	check(not service.fit_controller(inv,pv,true) and inv.counts==before,"missing refit ingredient consumes none of the remaining parts")
	inv.add("sealed_connector");pv.controller_ok=false
	check(service.fit_controller(inv,pv,true) and pv.controller_ok and pv.winter_controller and inv.count("winter_controller")==0 and inv.count("dc_cable")==0 and inv.count("sealed_connector")==0 and inv.count("dc_fuse")==1 and inv.count("service_kit")==1,"exact refit consumes its three parts once and restores controller while retaining fuse and kit")
	check(absf(pv.watts(12*3600,0)-103.2)<.001 and pv.watts(0,0)==0,"winter conversion improves noon input but never generates at night")
	before=inv.counts.duplicate();check(not service.fit_controller(inv,pv,true) and inv.counts==before,"installed refit cannot consume a second set")
	check(not service.repair(inv,pv,"fuse",true) and inv.count("dc_fuse")==1,"healthy fuse is not needlessly consumed")
	pv.fuse_ok=false
	check(pv.fault()=="DC FUSE OPEN" and pv.watts(12*3600,0)==0 and service.repair(inv,pv,"fuse",true) and pv.fuse_ok and inv.count("dc_fuse")==0,"open fuse diagnosis blocks generation until exact spare is fitted")
	pv.cable_ok=false;inv.add("dc_cable");inv.add("dc_fuse")
	check(pv.fault()=="DC CABLE FAULT" and not service.repair(inv,pv,"fuse",true) and service.repair(inv,pv,"cable",true) and pv.cable_ok and inv.count("dc_fuse")==1,"wrong part cannot repair a cable fault; correct lead restores it")
	var damaged:=SolarSupply.new();damaged.enabled=true;damaged.controller_ok=false;damaged.cable_ok=false
	var repair_inv:=Inventory.new();fit_parts(repair_inv)
	check(service.repair(repair_inv,damaged,"cable",true) and repair_inv.count("dc_cable")==0 and damaged.tested_lead_installed and service.fit_controller(repair_inv,damaged,true) and damaged.controller_ok and damaged.cable_ok and repair_inv.count("dc_cable")==0,"cable-first repair then refit reuses installed lead without requiring or refunding a second cable")
	damaged=SolarSupply.new();damaged.enabled=true;damaged.controller_ok=false;damaged.cable_ok=false;repair_inv=Inventory.new();fit_parts(repair_inv)
	check(service.fit_controller(repair_inv,damaged,true) and damaged.fault().is_empty() and repair_inv.count("dc_cable")==0,"direct matched refit replaces both failed controller and cable with one finite lead")
	pv.snow_cover=1
	check(pv.fault().is_empty() and pv.watts(12*3600,0)==0,"snow obstruction is distinguishable from failed hardware")
	var solar_saved:=pv.to_dict();var restored_pv:=SolarSupply.new();restored_pv.restore(solar_saved)
	var restored:=ElectricalService.new();restored.restore(service.to_dict())
	check(restored.to_dict()==service.to_dict() and restored_pv.to_dict()==solar_saved,"every issue flag, circuit check, snow and controller fit survives restore")
	restored.restore({});restored_pv.restore({"enabled":true,"controller_ok":false,"snow_cover":.3})
	check(not restored.packet_claimed and restored_pv.fuse_ok and restored_pv.cable_ok and not restored_pv.winter_controller and not restored_pv.controller_ok and restored_pv.snow_cover==.3,"legacy hardware retains known faults and snow without silently installing upgrade")
	var w:Node3D=await build();var op:LookoutOpening=w.opening;var field:ElectricalFieldwork=op.electrical;var s:LookoutAssignment=op.state
	check(field.packet!=null and field.cable!=null and field.controller_stock!=null and field.slate!=null,"original packet, cable, fitted controller case and live delivery slate import into existing stops")
	check(field.packet.visible and field.controller_stock.visible and field.cable.visible,"new game starts with finite prepared stock visible")
	var road_clear:=INF
	for row:Array in w.fire_lookout.site.path.points_world_xyz:road_clear=minf(road_clear,Vector2(field.cable.global_position.x,field.cable.global_position.z).distance_to(Vector2(row[0],row[2])))
	check(road_clear>1.85 and field.packet.get_parent()==w.first_week._lid and field.packet.position.x+.116<.08 and absf(ElectricalFieldwork.DEPOT_LOCAL.z-LookoutOpening.CASE_LOCAL.z)>.34 and is_equal_approx(ElectricalFieldwork.DEPOT_LOCAL.x,1.60),"cable stays off walking lane, packet follows crate lid and supported depot stock clears reserved relay along the counter")
	field.read_record()
	check(w.reading._body.text.contains("optional") and w.reading._body.text.contains("78%") and w.reading._body.text.contains("June"),"readable field record explains optional refit and named crew continuity")
	w.reading.close()
	var packet_action:=act(w,"Collect sealed fuse")
	w._act_begin(packet_action);w._act_update(.4,true);w.first_week.update(0);w.first_week._process(.4)
	check(w.first_week.cache.want_open and w.first_week.cache.lid_k>.99 and field.packet.visible and not field.service.packet_claimed,"actual collection work opens the existing lid with its retained packet before committing issue")
	w._act_update(.01,false);w.first_week.update(0);w.first_week._process(.4)
	check(not w.first_week.cache.want_open and w.first_week.cache.lid_k==0 and field.packet.visible and not field.service.packet_claimed,"cancelled packet work closes lid and leaves the issue untouched")
	w._act_begin(packet_action);w._act_update(1.5,true);field.claim_controller()
	w.drop_item("winter_controller",1)
	var dropped:ItemPickup=null
	for node:Node in get_nodes_in_group("pickups"):
		if node is ItemPickup and node.id=="winter_controller":dropped=node
	check(dropped!=null and dropped.get_child(0) is Node3D and w.inv.count("winter_controller")==0 and field.service.controller_claimed and not field.controller_stock.visible,"actual drop uses original component mesh while keeping depot stock depleted")
	w.take_pickup(dropped);await process_frame
	check(w.inv.count("winter_controller")==1 and field.service.controller_claimed and s.depot_visited,"existing pickup transaction recovers dropped component without reissuing depot stock")
	var cable_action:=act(w,"Spur cable")
	w._act_begin(cable_action);w._act_update(3,true)
	check(not field.service.cable_claimed and w.inv.count("dc_cable")==0,"actual non-isolated action never recovers a live lead")
	w.first_week.isolate();w.reading.close()
	check(w.first_week.feeder_isolated and s.field_load_w==0,"existing isolation removes actual branch load before cable recovery")
	cable_action=act(w,"Test and recover")
	w._act_begin(cable_action);w._act_update(.8,true);w.player.position.x+=.8;w._act_update(.1,true)
	check(w._act.is_empty() and not field.service.cable_claimed and field.cable.visible,"moving cancels actual cable recovery without taking stock")
	w._act_begin(cable_action);w._act_update(3,true)
	check(field.service.cable_claimed and not field.cable.visible and w.inv.count("dc_cable")==1,"completed recovery uses the existing halved wait and removes physical lead")
	# Zero-charge commissioning remains independent of the optional outing.
	s.grid_fail_s=0;s.repair_stage=1;s.battery_wh=0;s.backup_on=false;s.recovery_lock=true
	w.inv.add("power_relay");op.install_relay();op.verify_relay()
	check(s.repair_stage==3 and s.battery_wh==0 and s.backup_on,"original transfer relay still commissions at zero before optional refit")
	w.clock.hour=12;w.clock.total_game_s=6.5*3600;s.last_s=w.clock.total_game_s
	w.weather.lock_state(Weather.S.CLEAR);s.solar_overcast=0;s.solar.snow_cover=0
	var fit:=act(w,"Fit winter controller")
	before=w.inv.counts.duplicate();w._act_begin(fit);w._act_update(1,true);w.player.health-=1;w._act_update(.1,true)
	check(w._act.is_empty() and w.inv.counts==before and not s.solar.winter_controller,"damage interrupts fitting without consuming materials or upgrading")
	w._act_begin(fit);w._act_update(1,true);w.inv.remove("sealed_connector");before=w.inv.counts.duplicate();w._act_update(3,true)
	check(not s.solar.winter_controller and w.inv.counts==before,"completion rechecks lost ingredients before touching any remaining part")
	w.inv.add("sealed_connector");s.solar.controller_ok=false
	op.read_power_status();check(w.reading._body.text.contains("self-test failed") and op.power_status()=="CHARGER FAULT","actual fault modal names failed controller and recovery destination")
	w.reading.close();var energy:float=s.battery_wh;var deadline:float=s.grid_fail_s;var source_deadline:float=s.source_end_s
	w.clock.advance(20)
	w._act_begin(fit);w._act_update(4,true)
	check(s.solar.winter_controller and s.solar.controller_ok and s.battery_wh==energy and s.last_s==w.clock.total_game_s and s.grid_fail_s==deadline and s.source_end_s==source_deadline,"actual refit settles preceding failed-controller time before changing hardware without charge or external-outage gifts")
	check(w.inv.count("dc_fuse")==1 and w.inv.count("winter_controller")==0 and not field.controller_stock.visible and not field.packet.visible,"parts consumption and depleted physical stock agree")
	w.clock.advance(60);op.advance(1800)
	check(s.battery_wh>12 and s.powered() and op.solar_site.display.text.contains("WINTER REG"),"real world advance recovers flat pack with fitted regulator and physical status")
	s.solar.fuse_ok=false;op.read_power_status()
	check(w.reading._body.text.contains("fuse continuity") and op.power_status()=="DC FUSE OPEN","fuse continuity gets its own destination diagnosis")
	w.reading.close();var repair_action:=act(w,"Replace diagnosed open DC fuse")
	w._act_begin(repair_action);s.solar.fuse_ok=true;w._act_update(2,true)
	check(w.inv.count("dc_fuse")==1,"stale completed action cannot waste fuse after fault is already repaired")
	s.solar.fuse_ok=false;w._act_begin(repair_action);w._act_update(2,true)
	check(s.solar.fuse_ok and w.inv.count("dc_fuse")==0,"actual field repair consumes exactly one matched spare")
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	var old_position:Vector3=w.first_week.points[2];var old_energy:float=s.battery_wh
	w.queue_free();await process_frame;await process_frame
	w=await build(snapshot);s=w.opening_state;field=w.opening.electrical
	check(field.service.packet_claimed and field.service.controller_claimed and field.service.cable_claimed and s.solar.winter_controller,"actual world reload persists completed issue and fitted hardware")
	check(not field.packet.visible and not field.controller_stock.visible and not field.cable.visible and w.first_week.points[2].is_equal_approx(old_position) and w.first_week.feeder_isolated,"actual reload preserves depleted visuals and original route positions/isolation")
	w.opening.advance(0)
	var load_elapsed:float=w.clock.total_game_s-float(snapshot.clock.total)
	check(s.battery_wh<=old_energy+SolarSupply.RATED_W*.86*load_elapsed/3600+.001,"reload earns at most the elapsed daylight input, never a battery refill")
	before=w.inv.counts.duplicate();energy=s.battery_wh
	field.claim_packet();field.claim_controller();field.recover_cable();field.fit_controller()
	check(w.inv.counts==before and is_equal_approx(s.battery_wh,energy),"reloaded duplicate callbacks give no replacement stock or battery gift")
	w.clock.day=2;s.last_s=20*3600;field.update_presentation();field.read_record()
	check(field.issue_label.text.contains("UNCONFIRMED") and w.reading._body.text.contains("no confirmed departure"),"day-two depot record reflects disruption without replaying missed radio")
	w.reading.close();w.queue_free();await process_frame;SaveGame.pending={}
	print("ELECTRICAL_FIELDWORK_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
