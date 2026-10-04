extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var s := LookoutAssignment.new(); s.new_run(20261004)
	var other := LookoutAssignment.new(); other.new_run(20261004)
	check(s.grid_fail_s == other.grid_fail_s and s.source_end_s == other.source_end_s, "seed determines both outage windows")
	check(s.grid_fail_s >= 48*3600 and s.grid_fail_s <= 72*3600, "mains fail within 48-72 hours")
	check(s.source_end_s > s.grid_fail_s+35*3600, "broadcast transmitter outlasts town grid")
	check(not s.install() and not s.verify(), "commissioning cannot skip inspection")
	check(s.inspect() and not s.inspect(), "inspection cannot be duplicated")
	check(s.install() and s.verify() and not s.install() and not s.verify(), "each commissioning step is one-way")
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
	check(s.broadcast_at(2*3600-.01).is_empty(),"radio stays silent before dispatch")
	check(s.broadcast_at(2*3600).get("id","")=="dispatch_check","dispatch airs in its live window")
	check(s.broadcast_at(2*3600+1800).is_empty(),"missed dispatch never repeats")
	s.channel="public"
	check(s.broadcast_at(2*3600).is_empty(),"other channel does not play work dispatch")
	check(s.broadcast_at(8*3600).get("id","")=="local_reports","public station has independent schedule")
	s.receiver_on=false
	check(s.broadcast_at(8*3600).is_empty(),"off receiver cannot catch transmission")
	s.receiver_on=true;s.last_s=s.source_end_s;s.backup_on=true
	check(s.broadcast_at(s.source_end_s).is_empty(),"local battery cannot resurrect distant transmitter")
	var automatic:=LookoutAssignment.new();automatic.inspect();automatic.install();automatic.verify();automatic.advance_to(automatic.grid_fail_s+3600)
	check(automatic.backup_on and is_equal_approx(automatic.battery_wh,125),"commissioned automatic transfer powers the home across a slept-through outage")
	automatic.relay_enabled=false;automatic.lamp_on=false;automatic.receiver_on=true;var charge:=automatic.battery_wh;automatic.advance_to(automatic.last_s+3600)
	check(is_equal_approx(charge-automatic.battery_wh,3),"repeater and lamp switches preserve radio-only reserve")
	automatic.channel="work"
	check(automatic.broadcast_at(30*3600).is_empty(),"disabled repeater cannot carry late field dispatch")
	print("LOOKOUT_ASSIGNMENT_TEST failures=",failures)
	quit(1 if failures else 0)
