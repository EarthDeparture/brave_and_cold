extends SceneTree
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false)
 for c:Node in n.get_children():freeze(c)
func sample(name:String,eye:Vector3,target:Vector3)->Dictionary:
 w.player.position=eye;w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(target);w.player.cam.make_current()
 for i in 180:w.pop.tick(1.0/60);await process_frame
 var samples:Array[float]=[];var start:=Time.get_ticks_usec();var previous:=start;var active_max:=0;var proxy_max:=0
 for i in 300:
  w.pop.tick(1.0/60);await process_frame
  var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now;active_max=maxi(active_max,w.pop.active.size());proxy_max=maxi(proxy_max,w.pop.proxy_n)
 var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0;samples.sort()
 return {"camera":name,"frames":300,"avg_fps":300/elapsed,"p95_ms":samples[284],"p99_ms":samples[296],"max_active":active_max,"max_proxy":proxy_max,"alive":w.pop.count_alive()}
func run()->void:
 create_timer(180).timeout.connect(func()->void:quit(2));root.size=Vector2i(1600,900);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
 for f in 600:
  await process_frame
  if w.collapse!=null and w.gear!=null:break
 freeze(w);w.out_path="test-no-autosave";w.player.god=true;w.player.noclip=true;w.viewmodel.hide();w.hud.hide();w.clock.hour=11;w.sky_rig.apply_hour(11);w.opening_zombie_count=250;w.opening_state.last_s=96*3600;w.collapse.update(0)
 var samples:Array=[];var c:Clinic=w.collapse.clinic
 samples.append(await sample("lookout",w.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+1.6,2)),w.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y,12))))
 samples.append(await sample("town_exterior",c.to_global(Vector3(5,1.7,12)),c.to_global(Vector3(0,1.7,2))))
 w.sky_rig.apply_shelter(1);samples.append(await sample("clinic_interior",c.to_global(Vector3(1.5,1.9,2.3)),c.to_global(Vector3(3.5,1.2,-1.2))))
 var label:="candidate"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("profile_label="):label=arg.trim_prefix("profile_label=")
 var receipt:={"renderer":"Forward+ D3D12","gpu":RenderingServer.get_video_adapter_name(),"resolution":[1600,900],"population":250,"seed":20261004,"samples":samples,"limitations":"Stationary route-camera samples with active AI/proxies, bounded deterministic pool ticks; world survival and weather updates frozen. Not a complete gameplay benchmark."}
 var f:=FileAccess.open("res://shots/first-week/profile_"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  "));print("FIRST_WEEK_PROFILE ",JSON.stringify(receipt));quit()
