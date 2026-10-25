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
  if w.collapse!=null and w.gear!=null:break
 freeze(w);w.out_path="test-no-autosave";return w
func run()->void:
 create_timer(170).timeout.connect(func()->void:quit(2))
 var b:=BodyTemperature.new();b.wetness=1
 for i in 60:b.update(60,-5,0,true,150,0,0,false)
 check(is_equal_approx(b.wetness,.5),"saturated clothing takes two game hours to dry near useful heat")
 b.wetness=1
 for i in 60:b.update(60,5,0,true,0,0,0,false)
 check(is_equal_approx(b.wetness,5.0/6),"warm ambient drying is slower than stove heat")
 var w:Node3D=await build();var op:LookoutOpening=w.opening;var c:Clinic=w.collapse.clinic
 check(op.city_letter!=null and FirstWeekStory.CITY_LETTER.contains("Elise"),"optional original city letter is physically present")
 op.read_city_letter();check(w.reading.is_open and w.player.ui_open,"city letter uses the readable closeable modal");w.reading.close()
 w.player.position=w.fire_lookout.to_global(op.stove_point(Vector3(0,1,.25)))
 check(w._near_fire(),"lit tower stove is a real fire crafting station")
 op.fuel_s=0;check(not w._near_fire(),"unlit tower stove cannot satisfy heat-based crafting")
 w.chest_take(c.stock[0],"bandage",2);c.update_loot_visuals()
 var displayed:=0
 for i in 5:
  if (c._dressing.find_child("DressingUnit"+str(i),true,false) as Node3D).visible:displayed+=1
 check(displayed==3,"clinic medical display follows exact remaining dressing count")
 w.chest_take(c.stock[1],"antiseptic",1);c.update_loot_visuals()
 check(not (c._dressing.find_child("AntisepticUnit1",true,false) as Node3D).visible,"individual medical containers disappear when looted")
 var s:LookoutAssignment=op.state;var deadlines:=[s.grid_fail_s,s.source_end_s];var stock:Dictionary=c.stock[0].to_dict();var route_stock:Dictionary=w.first_week.cache.to_dict();w.opening_zombie_count=40
 var mid_save:Dictionary={}
 # Temporal integration, ignoring all optional assignments; survival pacing is tested separately.
 for half_hour in 7*48:
  var gs:float=w.clock.advance(1800/w.clock.time_scale);op.advance(gs);w.first_week.update(gs);w.collapse.update(gs)
  if half_hour==111:mid_save=JSON.parse_string(JSON.stringify(w._save_data()))
  if half_hour%48==47:
   check(c.collapse_phase==[0,0,1,2,3,4,4,4,4][w.clock.day],"physical clinic phase agrees with story day "+str(w.clock.day))
   check(c.stock[0].to_dict()==stock and w.first_week.cache.to_dict()==route_stock,"ignored optional work never replenishes loot on day "+str(w.clock.day))
   check(s.dispatch_at(s.last_s).is_empty() and s.public_signal_at(s.last_s).is_empty(),"missed scheduled speech is not replayed on day "+str(w.clock.day))
 check(w.collapse.stage==4 and w.pop.count_alive()==40,"all one-time threat waves occur without completing the assignment")
 check(not s.grid_alive() and op.fuel_s==0 and not s.powered(),"ignored repairs and fuel leave a genuinely cold unpowered refuge")
 check(not s.public_signal_at(s.source_end_s+86400).size() and not s.dispatch_at(s.source_end_s+86400).size(),"public and work sources end independently of optional tasks")
 check(s.grid_fail_s==deadlines[0] and s.source_end_s==deadlines[1],"seven-day advances never reroll or extend shutdown deadlines")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));w.queue_free();await process_frame;await process_frame;w=await build(mid_save)
 check(w.collapse.stage==1 and w.collapse.target_count==40,"partial outbreak save retains its original configured population budget")
 var gs:float=w.clock.advance(68*3600/w.clock.time_scale);w.opening.advance(gs);w.collapse.update(0)
 check(w.collapse.stage==4 and w.pop.count_alive()==40,"continuing a partial save issues remaining cohorts exactly once despite changed launch options")
 w.queue_free();await process_frame;await process_frame;w=await build(saved)
 check(w.clock.day==8 and w.collapse.stage==4 and w.pop.count_alive()==40,"fresh restoration retains the complete first-week timeline and population")
 check(w.collapse.clinic.stock[0].count("bandage")==3 and w.first_week.cache.to_dict()==route_stock,"full-week save cannot restore consumed finite stock")
 # Missing/disabled optional art must not disable the survival threat state.
 var fallback:=FirstWeekCollapse.new();w.add_child(fallback);w.opening_state.zombies_seeded=false;w.opening_zombie_count=40;fallback.build(w,{})
 w.opening_state.last_s=float(w.opening_state.infected_cohorts()[0].at_s)+60;var before:int=w.pop.count_alive();fallback.update(0)
 check(fallback.stage==1 and w.pop.count_alive()==before+2,"staged outbreak still works without a clinic site")
 fallback.queue_free();w.queue_free();await process_frame;await process_frame;SaveGame.pending={}
 print("FIRST_WEEK_STORY_TEST checks=",checks," failures=",failures);quit(1 if failures else 0)
