extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func empty_site(hour:float=12) -> LookoutAssignment:
	var s:=LookoutAssignment.new();s.new_run(20261004)
	s.grid_fail_s=0;s.last_s=0;s.calendar_origin_s=hour*3600
	s.battery_wh=0;s.walkie_carried=true;s.backup_on=false
	return s
func freeze(n:Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func run() -> void:
	create_timer(180).timeout.connect(func()->void:quit(2))
	var s:=empty_site()
	check(s.inspect() and s.install() and s.verify(),"empty reserve after mains loss cannot deadlock commissioning")
	check(s.battery_wh==0 and not s.powered() and s.backup_on and s.recovery_lock,"commissioning arms output without fabricating charge")
	s.advance_to(60,0)
	check(s.battery_wh>1 and s.battery_wh<2 and s.recovery_lock and not s.powered(),"cold-start charger accumulates daylight with output held off")
	s.advance_to(1800,0)
	check(s.battery_wh>12 and s.powered() and not s.recovery_lock,"reserve threshold restores home output automatically")
	var before:float=s.battery_wh;s.advance_to(s.last_s,0);s.advance_to(s.last_s-100,0)
	check(is_equal_approx(before,s.battery_wh),"same or backward time cannot recharge twice")
	var isolated:=empty_site();isolated.inspect();isolated.install();isolated.verify();isolated.backup_on=false;isolated.relay_enabled=false
	isolated.advance_to(3600,0)
	check(isolated.battery_wh>90 and not isolated.powered(),"output and repeater switches off preserve independent solar charging")
	var dark:=empty_site(0);dark.inspect();dark.install();dark.verify();dark.advance_to(5*3600,0)
	check(dark.battery_wh==0 and not dark.powered(),"night provides no fictitious generation")
	dark.advance_to(9*3600,.55)
	check(dark.battery_wh>12 and dark.powered(),"a slept-through dawn recovers a flat commissioned site")
	var unready:=empty_site();unready.advance_to(3600,0)
	check(unready.battery_wh==0,"unrepaired transfer circuit keeps solar isolated")
	var pv:=SolarSupply.new();pv.enabled=true
	check(pv.watts(12*3600,0)>pv.watts(12*3600,1) and pv.watts(0,0)==0,"cloud and daylight inputs are distinct from grid availability")
	var clear_wh:float=pv.energy_wh(0,86400,0,0)
	check(absf(clear_wh-24/PI*SolarSupply.RATED_W*SolarSupply.EFFICIENCY)<.001,"full-day energy integrates sunrise and sunset analytically")
	pv.snow_cover=1
	check(pv.energy_wh(0,86400,0,0)==0,"covered cells provide no energy")
	pv.clear_snow();check(pv.energy_wh(0,86400,0,0)>0,"brushing restores cell exposure")
	pv.controller_ok=false;check(pv.watts(12*3600,0)==0,"a saved controller fault stops generation")
	var jumps:=empty_site(0);jumps.inspect();jumps.install();jumps.verify();jumps.backup_on=false
	var steps:=LookoutAssignment.new();steps.restore(jumps.to_dict())
	jumps.advance_to(48*3600,.55,.3)
	for i in range(1,577):steps.advance_to(i*300,.55,.3)
	check(absf(jumps.battery_wh-steps.battery_wh)<.001 and absf(jumps.solar.snow_cover-steps.solar.snow_cover)<.00001 and jumps.walkie_wh==steps.walkie_wh,"long calendar skip matches bounded solar and snow integration")
	check(jumps.battery_wh<=LookoutAssignment.BATTERY_CAP_WH and jumps.walkie_wh>=0,"solar skips respect both battery capacities")
	var saved:=s.to_dict();saved.solar.snow_cover=.4
	var restored:=LookoutAssignment.new();restored.restore(saved)
	check(restored.to_dict()==saved,"solar, recovery gate, reserve and deadlines survive restore")
	saved.erase("solar");saved.erase("recovery_lock");saved.schema=3;saved.battery_wh=0
	restored.restore(saved)
	check(restored.battery_wh==0 and restored.solar.enabled and restored.recovery_lock and restored.grid_fail_s==saved.grid_fail_s,"legacy empty save gains physical source without charge or deadline gifts")
	restored.advance_to(restored.last_s+3600,0)
	check(restored.battery_wh>12 and restored.powered(),"restored legacy zero-charge home actually recovers")
	SaveGame.pending={};var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null and w.gear!=null:break
	freeze(w);w.out_path="test-no-autosave";w._frames=100
	var op:LookoutOpening=w.opening;s=op.state
	check(op.solar_site!=null and op.solar_site.snow_surfaces.size()==2,"original physical array and separate snow surfaces import")
	s.grid_fail_s=0;s.battery_wh=0;s.recovery_lock=true;s.repair_stage=1;s.parts_claimed=true
	w.clock.hour=12;w.clock.total_game_s=6.5*3600;s.last_s=w.clock.total_game_s
	w.inv.add("power_relay");op.install_relay();op.verify_relay()
	check(s.repair_stage==3 and w.inv.count("power_relay")==0 and s.battery_wh==0,"actual install and verify callbacks accept empty tower reserve")
	w.clock.advance(60);op.advance(1800)
	check(s.battery_wh>12 and s.powered() and op.power_status()=="SOLAR CHARGING" and op._power_label.text.contains("SOLAR CHARGING") and w.fire_lookout.get_node("LookoutDeskLamp").light_energy>0,"actual world advance charges the recovered tower and restores physical lamp/status")
	s.solar.snow_cover=.7
	w.player.position=op.solar_site.to_global(Vector3(0,w.player.eye_h,1.1))
	var brush:Dictionary={}
	for entry:Dictionary in op.solar_site.actions():
		if String(entry.text).begins_with("Brush snow"):brush=entry
	w._act_begin(brush);w._act_update(.5,true);w.player.position.x+=1;w._act_update(.1,true)
	check(w._act.is_empty() and s.solar.snow_cover==.7,"interrupted brushing leaves cover unchanged")
	w._act_begin(brush);w._act_update(2,true)
	check(s.solar.snow_cover==0,"completed maintenance uses accepted halved wait and clears saved snow")
	op.read_power_status()
	check(w.reading._body.text.contains("12 Wh") and w.reading._body.text.contains("town grid") and w.reading._body.text.contains("switch off"),"power modal explains recovery and independent grid")
	w.reading.close()
	var footprint:=Rect2(LookoutSolar.LOCAL.x-1.28,LookoutSolar.LOCAL.y-.54,2.56,1.14)
	check(RefugeBoundary.BOUNDS.encloses(footprint) and not footprint.grow(.35).has_point(Vector2(-5,4)) and not footprint.grow(.35).has_point(Vector2(1.9,6)),"array footprint remains inside refuge and clear of compound route")
	var clear_approach:=true
	for step in 101:
		if footprint.grow(.35).has_point(Vector2(-9,-4.65).lerp(Vector2(-5,4),step/100.0)):clear_approach=false
	check(clear_approach,"full cabinet-to-yard corridor clears the rack with player tolerance")
	var snapshot:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()))
	snapshot.opening.state.erase("solar");snapshot.opening.state.erase("recovery_lock")
	snapshot.opening.state.schema=3;snapshot.opening.state.battery_wh=0
	snapshot.clock.erase("base_time_scale");snapshot.clock.erase("pace_schema")
	var deadline:float=s.grid_fail_s
	w.queue_free();await process_frame;await process_frame
	SaveGame.pending=snapshot;w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null and w.gear!=null:break
	freeze(w);w.out_path="test-no-autosave";w._frames=100;s=w.opening_state
	var load_elapsed:float=w.clock.total_game_s-float(snapshot.clock.total)
	check(w.clock.base_time_scale==48 and s.solar.enabled and s.battery_wh<=SolarSupply.RATED_W*SolarSupply.EFFICIENCY*load_elapsed/3600+.001 and s.grid_fail_s==deadline,"actual legacy world reload retains pace and only earns elapsed daylight charge")
	var gs:float=w.clock.advance(60);w.opening.advance(gs)
	check(s.battery_wh>12 and s.powered(),"actual reloaded zero-charge tower resumes power")
	w.queue_free();await process_frame;SaveGame.pending={}
	print("SOLAR_RECOVERY_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
