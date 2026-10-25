extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func close(a:float,b:float)->bool:return absf(a-b)<.00001
func reserve(carried:bool,handset:float,home:float)->LookoutAssignment:
	var s:=LookoutAssignment.new();s.grid_fail_s=0;s.backup_on=true;s.lamp_on=true;s.receiver_on=true
	s.walkie_carried=carried;s.walkie_wh=handset;s.battery_wh=home;return s
func run()->void:
	var s:=LookoutAssignment.new();s.new_run(20261004)
	check(not s.walkie_carried and s.walkie_wh==12,"fresh game has one fully charged handset on desk")
	s.walkie_carried=true;s.advance_to(12*3600)
	check(close(s.walkie_wh,6),"carried monitor lasts 24 game hours at full charge")
	s.advance_to(24*3600);check(s.walkie_wh==0 and not s.walkie_ready(),"carried handset cannot receive at empty battery")
	s.walkie_carried=false;s.advance_to(25*3600)
	check(close(s.walkie_wh,4.3),"powered cradle charges from empty while sustaining receiver")
	s.advance_to(28*3600);check(s.walkie_wh==12,"charger stops at capacity through long time jump")
	s=reserve(false,12,144);s.advance_to(3600)
	check(close(s.battery_wh,133.375) and s.walkie_wh==12,"full docked monitor uses home maintenance power, not 6 W indefinitely")
	s=reserve(false,0,144);s.advance_to(3*3600)
	var full_at:=12/4.3
	check(close(s.battery_wh,144-16*full_at-10.625*(3-full_at)) and s.walkie_wh==12,"backup integration splits exactly when charging completes")
	s=reserve(false,0,1);s.advance_to(1800)
	check(s.battery_wh==0 and close(s.walkie_wh,.05),"docked phone switches to own reserve when home battery fails mid-sleep")
	s=reserve(true,12,144);s.advance_to(3600)
	check(close(s.battery_wh,134) and close(s.walkie_wh,11.5),"carried handset does not load home charger")
	s=reserve(false,4,144);s.backup_on=false;s.advance_to(3600)
	check(s.battery_wh==144 and close(s.walkie_wh,3.5),"unpowered desk never charges handset")
	s.walkie_wh=.001;check(s.walkie_percent()==1,"remaining usable charge never misleadingly displays zero percent")
	s.walkie_wh=0;check(s.walkie_percent()==0,"empty charge displays zero percent")
	s=reserve(false,0,144)
	check(s.walkie_ready(),"empty docked handset can operate directly from powered cradle")
	s.backup_on=false;check(not s.walkie_ready(),"empty handset cannot operate from unpowered cradle")
	# Integration consistency across real frame updates, sleep skips, grid failure,
	# handset full, home empty and auto-transfer. Independent absolute outcomes above.
	for carried:bool in [true,false]:
		for phone:float in [0.0,.25,6.0,12.0]:
			for home:float in [0.0,1.0,144.0]:
				for grid:float in [0.0,2.25*3600]:
					var bulk:=reserve(carried,phone,home);bulk.grid_fail_s=grid
					bulk.repair_stage=3;bulk.auto_transfer_on=true
					var stepped:=LookoutAssignment.new();stepped.restore(bulk.to_dict())
					bulk.advance_to(12*3600)
					for i in range(1,101):stepped.advance_to(i*432.0)
					check(close(bulk.walkie_wh,stepped.walkie_wh) and close(bulk.battery_wh,stepped.battery_wh) and bulk.backup_on==stepped.backup_on,"frame/sleep integration agrees carried=%s phone=%.2f home=%.0f grid=%.0f"%[carried,phone,home,grid])
	s=reserve(false,3.7,55);s.last_s=100
	var saved:Dictionary=JSON.parse_string(JSON.stringify(s.to_dict()));var loaded:=LookoutAssignment.new();loaded.restore(saved)
	check(loaded.to_dict()==s.to_dict(),"schema 3 preserves dock, exact portable charge and home reserve")
	saved.erase("walkie_carried");saved.erase("walkie_wh");saved.schema=2;loaded.restore(saved)
	check(loaded.walkie_carried and loaded.walkie_wh==12 and loaded.battery_wh==55 and loaded.last_s==100,"older saves get carried full handset without refilling home or changing clock")
	saved.walkie_wh=-5;loaded.restore(saved);check(loaded.walkie_wh==0,"invalid negative charge is clamped")
	saved.walkie_wh=900;loaded.restore(saved);check(loaded.walkie_wh==12,"invalid excess charge is clamped")
	print("WALKIE_CHARGE_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
