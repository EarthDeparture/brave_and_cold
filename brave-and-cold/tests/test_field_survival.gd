extends SceneTree
var checks:=0
var failures:=0
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
 for f in 600:
  await process_frame
  if w.opening!=null and w.gear!=null:break
 freeze(w);w.out_path="test-no-autosave";return w
func run()->void:
 create_timer(160).timeout.connect(func()->void:quit(2))
 var n:=Needs.new();n.update(3600,0,37)
 check(is_equal_approx(n.fatigue,3),"fatigue accumulates in game hours, independently of frame time")
 n.update(3600,2,37);check(is_equal_approx(n.fatigue,11),"exertion increases fatigue")
 n.update(0,2,37);check(n.fatigue==11,"paused game time cannot change fatigue")
 n.resting=true;n.rest_quality=.5;n.update(3600,0,37);check(n.fatigue==6,"poor rest restores proportionally less fatigue")
 n.rest_quality=1;n.update(3600,0,37);check(n.fatigue==0,"good rest restores fatigue without going negative")
 n.fatigue=100;check(is_equal_approx(n.stamina_capacity(),45) and is_equal_approx(n.travel_mult(),.82),"exhaustion is bounded; movement and short-term stamina remain usable")
 var inv:=Inventory.new(BodyTemperature.new());inv.add("axe");inv.cond.axe=.4
 check(FieldMaintenance.reason(inv,"axe").contains("whetstone"),"tool work requires finite repair equipment")
 inv.add("whetstone");inv.add("rag",3)
 check(FieldMaintenance.complete(inv,"axe").contains("65%") and inv.count("rag")==2 and is_equal_approx(inv.condition("whetstone"),.92),"tool repair spends exactly one rag and stone wear, restoring 25 percent")
 inv.cond.axe=1;var rags:=inv.count("rag");FieldMaintenance.complete(inv,"axe")
 check(inv.count("rag")==rags,"pristine tool never spends resources")
 inv.add("parka");inv.use("parka");var insulation:float=inv.body.warmth
 inv.cond.parka=.3;inv._recompute();check(inv.body.warmth<insulation,"damaged worn clothing loses effective insulation")
 inv.add("sewing_kit");inv.add("cordage");FieldMaintenance.complete(inv,"parka")
 check(is_equal_approx(inv.condition("parka"),.55) and inv.count("rag")==0 and inv.count("cordage")==0,"clothing repair spends cloth and cordage and updates condition")
 var worn:float=inv.condition("parka");inv.wear_clothing(3600,1,1)
 check(inv.condition("parka")<worn and inv.body.warmth<insulation,"moving through weather wears actual equipped clothing")
 var w:Node3D=await build();var op:LookoutOpening=w.opening;var p:Player=w.player
 check(op.pantry.count("whetstone")==1 and op.pantry.count("sewing_kit")==1,"fresh lookout has finite upkeep equipment")
 p.position=op.home_point(Vector3(.95,.88,-1.35));p.airborne=false;p.struggling=false
 w.inv.add("whetstone");w.inv.add("rag",3);w.inv.cond.axe=.4
 w.gear.open();w.gear_maintain("axe");w._act_update(1,false)
 check(not w.gear.is_open and not w._act.is_empty() and w.inv.count("rag")==3,"inventory repair runs without E and spends nothing before completion")
 p.position.x+=1;w._act_update(.1,false)
 check(w._act.is_empty() and w.inv.condition("axe")==.4 and w.inv.count("rag")==3,"moving cancels work with no material loss")
 p.position=op.home_point(Vector3(.95,.88,-1.35));w.gear_maintain("axe");w._act_update(3.1,false)
 check(w._act.is_empty() and is_equal_approx(w.inv.condition("axe"),.65) and w.inv.count("rag")==2,"actual world action completes repair once")
 w.gear_maintain("axe");w.inv.remove("whetstone");w._act_update(3.1,false)
 check(w.inv.count("rag")==2 and is_equal_approx(w.inv.condition("axe"),.65),"completion rechecks missing equipment and cannot spend partial costs")
 w.needs.fatigue=80;w.body.wetness=1;w.needs.calories=2000;w.needs.water=85;w.body.core=37
 check(is_equal_approx(w._sleep_quality(),.6),"wet clothing reduces real sleep quality")
 p.injury.wound(.4,1,true);p.injury.bandage();w.inv.add("antibiotics");Inventory.injury=p.injury
 var meds:int=w.inv.count("antibiotics");w.gear_use("antibiotics")
 check(p.injury.outbreak_t==0 and w.inv.count("antibiotics")==meds,"ordinary antibiotics neither consume nor cure outbreak exposure")
 p.injury.wound(.2,1);w.gear_use("antibiotics")
 check(p.injury.inf_t<0 and p.injury.outbreak_t==0,"ordinary infection can be treated while outbreak clock stays independent")
 var old:=Injury.new();old.from_dict({"inf":100,"bleed":0,"age":100})
 check(old.antibiotics() and old.outbreak_t<0,"legacy infections keep their original treatment meaning")
 p.injury.outbreak_t=Injury.INCUBATION_S-1;p.injury.update(2,0)
 check(p.injury.symptomatic(),"outbreak symptoms arrive on the game-time incubation clock")
 w.clock.hour=15.25;w.viewmodel.watch_override=true;w.viewmodel._process(.5)
 check(w.viewmodel.watch.visible and is_equal_approx(w.viewmodel.watch_minute.rotation.y,-PI/2),"physical watch face displays the same live minutes as inventory and radio")
 w.gear.open();w.viewmodel._process(.5);check(not w.viewmodel.watch.visible,"inventory hides the held watch and keeps existing UI time")
 w.gear.close();w.viewmodel.watch_override=false;w.viewmodel._process(.5)
 check(not w.viewmodel.watch.visible,"releasing watch returns normal equipment presentation")
 w.inv.add("bandage");p.injury.wound(.4,0);w.gear.open();var before:int=w.inv.count("bandage");w.gear_use("bandage");w.viewmodel._process(.1)
 check(w.inv.count("bandage")==before-1 and not p.injury.bleeding() and w.viewmodel.treatment_pending=="treat","treatment stops bleeding immediately and queues one visual behind inventory")
 w.gear.close();w.viewmodel._process(.1)
 check(w.viewmodel.work_kind=="treat" and w.viewmodel._cosmetic,"closing inventory starts reusable treatment presentation")
 before=w.inv.count("bandage");w.viewmodel._process(2)
 check(w.viewmodel.work_kind=="" and w.inv.count("bandage")==before,"presentation completion never consumes medicine twice")
 w.inv.add("clean_water");w.needs.water=60;w.gear_use("clean_water");w.viewmodel._process(.1)
 check(w.viewmodel.work_kind=="drink" and w.viewmodel._bottle.visible,"actual water use plays an uncapped flask handling pose")
 w.viewmodel.swing(true);w.viewmodel._process(.1)
 check(w.viewmodel.work_kind=="" and not w.viewmodel._bottle.visible,"combat interrupts cosmetic handling without delaying attack")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));w.queue_free();await process_frame;await process_frame
 w=await build(saved)
 check(w.needs.fatigue==80 and w.player.injury.outbreak_exposed and w.player.injury.outbreak_t>=Injury.INCUBATION_S,"fatigue and separate outbreak risk survive fresh world restoration")
 check(is_equal_approx(w.inv.condition("axe"),.65) and w.inv.count("rag")==2,"repair costs and condition persist through reload")
 w.queue_free();await process_frame;await process_frame;SaveGame.pending={}
 print("FIELD_SURVIVAL_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
