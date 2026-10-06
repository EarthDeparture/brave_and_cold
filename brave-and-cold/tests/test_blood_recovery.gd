extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func run()->void:
	var p:=Player.new();var i:=p.injury;i.player=p
	var n:=Needs.new();var inv:=Inventory.new(BodyTemperature.new());inv.needs=n;Inventory.injury=i
	p.health=80;i.wound(1,0);i.update(48,1)
	check(is_equal_approx(p.health,79.65) and i.bleeding(),"deep bleeding drains blood before treatment")
	check(i.recover(3600,n,37)==0 and p.health<80,"active bleeding cannot be offset by recovery")
	inv.add("bandage",2);var hp:=p.health
	check(inv.use("bandage")=="Bandaged: bleeding stopped" and inv.count("bandage")==1 and not i.bleeding(),"one bandage stops bleeding and consumes exactly one")
	check(p.health==hp,"bandaging does not instantly replace lost blood")
	check(inv.use("bandage")=="Not bleeding" and inv.count("bandage")==1,"unneeded bandage is not consumed")
	inv.remove("bandage");i.wound(.5,0)
	check(inv.use("bandage")=="None left" and i.bleeding(),"missing bandage cannot stop a wound")
	inv.add("bandage");inv.use("bandage");p.health=50
	check(is_equal_approx(i.recover(3600,n,37),1) and p.health==51,"fed hydrated player recovers 120 blood per game hour awake")
	n.calories=900
	check(i.recover(3600,n,37)==0 and i.recovery_status(n,37).contains("900"),"recovery pauses at exact calorie threshold with clear reason")
	n.calories=901;n.water=45
	check(i.recover(3600,n,37)==0 and i.recovery_status(n,37).contains("45%"),"recovery pauses at exact hydration threshold with clear reason")
	n.water=45.01;check(i.recover(3600,n,37)==1,"recovery resumes above both thresholds")
	n.calories=0;n.water=0;check(i.recover(3600,n,37,3)==0,"sleep cannot bypass starvation or dehydration gating")
	n.calories=2000;n.water=85;p.health=60
	check(i.recover(2*3600,n,37,3)==6 and p.health==66,"warm fed sleep recovers three times faster through same clock")
	check(i.recover(3600,n,36,1.5)==1.5,"reduced sleep quality scales recovery without extra healing pass")
	check(i.recover(3600,n,34.9,3)==0,"hypothermia pauses recovery despite supplies")
	i.inf_t=Injury.INCUBATION_S
	check(i.recover(3600,n,37,3)==0 and i.recovery_status(n,37).contains("fever"),"symptomatic infection blocks recovery")
	i.bleed=.5;inv.add("bandage");inv.use("bandage")
	check(i.inf_t==Injury.INCUBATION_S and not i.bleeding(),"bandage stops blood loss without curing infection")
	i.inf_t=100;check(i.recover(3600,n,37)==1,"incubating infection remains hidden while ordinary recovery works")
	i.inf_t=-1;p.health=99.9
	check(is_equal_approx(i.recover(3600,n,37,3),.1) and p.health==100,"recovery cannot exceed full blood")
	check(i.recover(3600,n,37)==0 and i.recovery_status(n,37)=="Blood replenished","full blood does not continue accumulating")
	p.dead=true;p.health=0
	check(i.recover(3600,n,37,3)==0 and p.health==0,"recovery cannot revive a dead player")
	p.dead=false;p.health=50
	check(i.recover(0,n,37)==0 and i.recover(-3600,n,37)==0 and p.health==50,"zero/backward time cannot heal")
	check(i.recover(3600,n,37,-1)==0,"negative rest multiplier cannot remove blood")
	i.bleed=.02;inv.add("bandage")
	check(i.bleeding() and inv.use("bandage")=="Bandaged: bleeding stopped","lowest damaging bleed rate is consistently treatable")
	i.bleed=.01;hp=p.health;i.update(1,1)
	check(not i.bleeding() and p.health==hp,"subclinical clotting residue is not treated as blood loss")
	i.wound(.7,0);var saved:Dictionary=JSON.parse_string(JSON.stringify(i.to_dict()));var restored:=Injury.new();restored.from_dict(saved)
	check(restored.to_dict()==i.to_dict(),"wound state retains bleeding and infection clock through save")
	# Repeated small updates and a sleep-sized update must agree for stable needs.
	i.bandage();i.inf_t=-1;p.health=50;i.recover(8*3600,n,37,3);var bulk:=p.health;p.health=50
	for frame in 480:i.recover(60,n,37,3)
	check(is_equal_approx(p.health,bulk) and is_equal_approx(bulk,74),"continuous and skipped-time recovery agree without double-healing")
	Inventory.injury=null;p.free();print("BLOOD_RECOVERY_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
