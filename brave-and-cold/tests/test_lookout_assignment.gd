extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var s := LookoutAssignment.new(); s.new_run(20261004)
	var other := LookoutAssignment.new(); other.new_run(20261004)
	check(s.grid_fail_s == other.grid_fail_s and s.source_end_s == other.source_end_s, "seeded mains and fixed station end are repeatable")
	check(s.grid_fail_s >= s.calendar_s(3,22)-.01 and s.grid_fail_s <= s.calendar_s(4,1)+.01, "mains fail on the turn night, never during the quiet work days")
	var cohorts:=s.infected_cohorts()
	check(cohorts.size()==4 and float(cohorts[0].at_s)>=s.calendar_s(3,6) and float(cohorts[0].at_s)<s.calendar_s(3,12), "two full quiet work days: first local infected on day three morning")
	var ordered:=true
	for i in range(1,cohorts.size()): ordered=ordered and float(cohorts[i].at_s)>float(cohorts[i-1].at_s) and float(cohorts[i].share)>float(cohorts[i-1].share)
	check(ordered and is_equal_approx(float(cohorts[-1].share),1.0) and float(cohorts[-1].at_s)-float(cohorts[0].at_s)<=20*3600, "turn is fast: whole population within twenty hours of the first local case")
	check(float(cohorts[0].at_s)<s.grid_fail_s and float(cohorts[-1].at_s)>s.grid_fail_s, "infected arrive before the mains fail; town is full by the next dawn")
	var by_id:={}
	for e:Dictionary in s.broadcasts: by_id[e.id]=s.entry_start(e)
	check(by_id.public_d2_24<=s.calendar_s(3,0) and by_id.public_d3_06<float(cohorts[0].at_s) and by_id.dispatch_d3_08<float(cohorts[0].at_s), "pre-turn radio precedes any local infected")
	check(by_id.public_d3_12>float(cohorts[0].at_s) and by_id.dispatch_d3_14>float(cohorts[0].at_s) and by_id.public_d3_17<float(cohorts[2].at_s), "radio reports local attacks only after they exist, and warns before the road wave")
	check(by_id.dispatch_d3_20<s.calendar_s(3,22) and by_id.public_d3_24>=s.calendar_s(3,22)-1800, "power warnings bracket the outage window")
	var late:=LookoutAssignment.new();late.new_run(20261004);late.align_calendar(1,9,0,true)
	check(is_equal_approx(late.grid_fail_s-s.grid_fail_s,-3.5*3600) and is_equal_approx(float(late.infected_cohorts()[0].at_s)-float(cohorts[0].at_s),-3.5*3600), "story beats follow the calendar, not the debug start hour")
	check(s.phase()=="Assignment", "arrival is the ordinary assignment phase")
	check(s.source_end_s > s.grid_fail_s+35*3600, "broadcast transmitter outlasts town grid")
	check(not s.install() and not s.verify(), "commissioning cannot skip inspection")
	check(s.inspect() and not s.inspect(), "inspection cannot be duplicated")
	check(s.install() and s.verify() and not s.install() and not s.verify(), "each commissioning step is one-way")
	s.solar.enabled=false # Isolate original mains/battery accounting below.
	s.walkie_carried = true # isolate home load from charger in this regression
	s.auto_transfer_on = false
	s.battery_wh = 0; s.advance_to(3600)
	check(is_equal_approx(s.battery_wh,24), "mains charge integrates in world hours")
	s.advance_to(s.grid_fail_s)
	check(not s.grid_alive() and not s.powered(), "outage cuts local mains at exact boundary")
	s.backup_on = true; s.receiver_on = true
	var before := s.battery_wh; s.advance_to(s.last_s+3600)
	check(is_equal_approx(before-s.battery_wh,22), "lamp, receiver and commissioned relay draw 22 W")
	before=s.battery_wh; s.advance_to(s.last_s)
	check(s.battery_wh == before,"same timestamp cannot drain battery twice")
	s.advance_to(s.last_s-3600)
	check(s.battery_wh == before,"backward time cannot refund charge")
	s.advance_to(s.last_s+10*3600)
	check(s.battery_wh == 0 and not s.powered(),"backup is finite through a sleep-sized time jump")
	var restored := LookoutAssignment.new(); restored.restore(s.to_dict())
	check(restored.to_dict() == s.to_dict(),"power, dates and job state survive dictionary round trip")
	s=LookoutAssignment.new();s.receiver_on=true
	check(s.public_broadcast_at(1800-.01).is_empty(),"morning stays silent until 06:00")
	check(s.public_broadcast_at(1800).get("id","")=="public_d1_06","first morning bulletin is ordinary weather and services")
	check(s.public_broadcast_at(3600).is_empty(),"morning bulletin cannot replay after its window")
	check(s.public_broadcast_at(6.5*3600).get("id","")=="public_d1_12","noon recap follows the same calendar day")
	check(s.public_broadcast_at(11.5*3600).get("id","")=="public_d1_17","first 17:00 bulletin introduces distant incidents")
	check(s.public_broadcast_at(18.5*3600).get("id","")=="public_d1_24","midnight closes the first lived day")
	check(s.public_broadcast_at(24.5*3600).get("id","")=="public_d2_06","next morning advances the story")
	s.receiver_on=false
	check(s.public_broadcast_at(1800).is_empty(),"desk off cannot catch a public transmission")
	check(s.dispatch_at(2.5*3600).get("id","")=="dispatch_d1_08","carried dispatch needs no desk switch")
	check(s.dispatch_at(3*3600).is_empty(),"expired dispatch never repeats")
	s.receiver_on=true;s.last_s=s.source_end_s;s.backup_on=true
	check(s.public_broadcast_at(s.source_end_s).is_empty(),"local battery cannot resurrect distant transmitter")
	var automatic:=LookoutAssignment.new();automatic.inspect();automatic.install();automatic.verify();automatic.advance_to(automatic.grid_fail_s+3600)
	check(automatic.backup_on and is_equal_approx(automatic.battery_wh,125),"commissioned automatic transfer powers the home across a slept-through outage")
	automatic.relay_enabled=false;automatic.lamp_on=false;automatic.receiver_on=true;var charge:=automatic.battery_wh;automatic.advance_to(automatic.last_s+3600)
	check(is_equal_approx(charge-automatic.battery_wh,3),"repeater and lamp switches preserve radio-only reserve")
	check(automatic.dispatch_at(74.5*3600).get("id","")=="dispatch_d4_08","personal dispatch is independent of disabled local repeater")
	print("LOOKOUT_ASSIGNMENT_TEST failures=",failures)
	quit(1 if failures else 0)
