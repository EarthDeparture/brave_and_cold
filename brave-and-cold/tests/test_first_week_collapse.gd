extends SceneTree
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL "+why)
 else:print("PASS "+why)
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false)
 for c:Node in n.get_children():freeze(c)
func build(saved:Dictionary={})->Node3D:
 SaveGame.pending=saved;var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
 for f in 800:
  await process_frame
  if w.collapse!=null and w.reading!=null:break
 freeze(w);w.out_path="test-no-autosave";return w
func run()->void:
 create_timer(160).timeout.connect(func()->void:quit(2));var w:Node3D=await build();var c:Clinic=w.collapse.clinic
 check(c!=null,"survey finds a buildable clinic near the existing town")
 if c==null:quit(1);return
 check(c.global_position.distance_to(w.stores[0].global_position)<100,"clinic is a connected town destination")
 check(w.player.cabins.has(c) and w._building_list().has(c),"clinic participates in walking, sight and projectile collision")
 check(c.stock.size()==3 and c.stock[0].count("bandage")==5,"three rooms have actual finite supply inventories")
 var scene_count:int=w.forest.felled.size();check(scene_count==0,"construction clearing does not impersonate player-felled trees")
 for side:Array in [[0,1],[-2.5,-1]]:
  var prior:=NAN
  for k in 81:
   var lp:=Vector3(side[0],.3,side[1]*(2.8+k*.05));var p:=c.to_global(lp);var h:float=w.player.ground_at(p.x,p.z)
   if not is_nan(prior):check(absf(h-prior)<.12,"entrance floor has no ledge along five-centimetre travel steps")
   prior=h
 c.door_open=true;c.rear_open=true
 for lp:Vector3 in [Vector3(0,0,3.8),Vector3(-2.5,0,-3.8),Vector3(1,0,1.05),Vector3(-2.5,0,-.7)]:
  var pt:=c.to_global(lp);check(c.resolve(pt.x,pt.z,.25).distance_to(Vector2(pt.x,pt.z))<.001,"exit and partition circulation remain unobstructed")
 var n:=c.stock[0].count("bandage");w.chest_take(c.stock[0],"bandage",2);check(c.stock[0].count("bandage")==n-2,"medical supplies are withdrawn exactly once")
 w.opening_zombie_count=40;check(w.pop.count_alive()==0,"normal assignment begins without infected")
 w.opening_state.last_s=28*3600;w.collapse.update(0);check(w.pop.count_alive()==2 and w.collapse.stage==1,"first cohort is sparse instead of full map population")
 w.collapse.update(0);check(w.pop.count_alive()==2,"repeated updates do not refill issued cohort")
 for entry:Dictionary in w.pop.all_alive():check(Vector2(entry.x,entry.z).distance_to(Vector2(w.player.position.x,w.player.position.z))>=120,"arrival is outside player observation distance")
 w.opening_state.last_s=96*3600;w.collapse.update(0);check(w.pop.count_alive()==40 and w.collapse.stage==4,"four cohorts issue the exact configured total")
 check(w.collapse.clinic.collapse_phase==4 and not w.collapse._triage.visible and w.collapse._abandoned.visible,"clinic phase follows calendar rather than load time")
 var save:Dictionary=JSON.parse_string(JSON.stringify(w._save_data()));var loc:Vector3=c.position;w.queue_free();await process_frame;await process_frame
 w=await build(save);c=w.collapse.clinic
 check(c.position==loc and c.stock[0].count("bandage")==n-2,"clinic identity and withdrawals survive a full fresh-world reload")
 var count:int=w.pop.count_alive();w.collapse.update(0);check(w.collapse.stage==4 and w.pop.count_alive()==count,"restored issued cohorts cannot respawn kills")
 check(c.rear_open,"rear exit state survives reload")
 var pos:Vector3=w._ground(c.global_position.x+10,c.global_position.z+8);var z:Zombie=w._add_zombie(pos,71);z.set_process(false)
 check(z._knees.size()==2 and z._knees[0]!=null and z._elbows[0]!=null,"new infected has editable nested knee and elbow joints")
 z._animate(.1);z._attack_windup=.2;z.activate(pos,72);check(z._attack_windup<0 and z._arms[0].rotation==Vector3.ZERO,"pool activation clears old attack and articulation state")
 z.set_process(false);z.state=Zombie.State.CHASE;z.rotation.y=0;w.player.position=pos+Vector3(0,1.6,-.65);var hp:float=w.player.health
 z._process(.1);check(w.player.health==hp and z._attack_windup>0,"attack begins with visible preparation rather than immediate damage")
 z._process(.3);check(w.player.health==hp-Zombie.DAMAGE and z.grabs==1,"damage lands once at the end of the attack wind-up")
 z._cd=0;z._process(.1);hp=w.player.health;w.player.position=pos+Vector3(0,1.6,-4);z._process(.3);check(w.player.health==hp,"moving beyond reach during the wind-up avoids the hit")
 print("FIRST_WEEK_COLLAPSE_TEST checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
