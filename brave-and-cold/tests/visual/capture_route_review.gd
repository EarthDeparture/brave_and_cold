extends SceneTree
## Deterministic real-world route and 30 FPS motion captures, without saving.
var options:Dictionary={}
var output:String
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false)
 for child in n.get_children():freeze(child)
func shot(id:String)->void:
 for i in 10:await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(id+".png"))
func run()->void:
 for arg in OS.get_cmdline_user_args():
  var pair:=arg.split("=",true,1);options[pair[0].trim_prefix("--")]=pair[1] if pair.size()>1 else "1"
 output=options.get("capture_out","res://shots/locomotion-route/route-final");DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);DisplayServer.window_set_size(Vector2i(1600,900));AudioServer.set_bus_mute(0,true);SaveGame.pending={};seed(20261003)
 var world:Node3D=load("res://world/game_world.gd").new();root.add_child(world)
 for i in 600:
  await process_frame
  if world.hud!=null:break
 if world.hud==null:quit(1);return
 freeze(world);world.hud.hide();world.viewmodel.hide();world.snowfall.hide();world.weather_presentation.hide();world.weather.lock_state(Weather.S.CLOUDY);world.weather.advance(120,0);world.clock.hour=12;world.sky_rig.apply_hour(12)
 var p:Player=world.player;var cam:Camera3D=p.cam;var store:Store=world.stores[0];var tower:FireLookout=world.fire_lookout
 p.position=store.to_global(Vector3(.4,2,6.7));cam.position=Vector3.ZERO;cam.look_at(store.to_global(Vector3(0,2.1,0)));await shot("store-exterior")
 world.sky_rig.apply_shelter(.75);p.position=store.to_global(Vector3(-.3,1.93,1.50));cam.look_at(store.to_global(Vector3(-.30,1.33,-1.9)));await shot("store-stocked")
 if options.has("closeups"):
  var old_fov:=cam.fov;cam.fov=55
  p.position=store.to_global(Vector3(-1.25,2.15,-1.02));cam.look_at(store.to_global(Vector3(-1.25,1.73,-1.98)));await shot("store-food-closeup")
  p.position=store.to_global(Vector3(1.77,2.06,-1.12));cam.look_at(store.to_global(Vector3(1.77,1.96,-2.06)));await shot("store-tools-closeup")
  cam.fov=old_fov
 p.position=store.to_global(Vector3(-.55,1.93,.3));cam.look_at(store.to_global(Vector3(1.59,1.40,-.4)));await shot("store-counter")
 store.looted=[true,true,true];store.update_loot_visuals();p.position=store.to_global(Vector3(-.3,1.93,1.50));cam.look_at(store.to_global(Vector3(-.3,1.33,-1.9)));await shot("store-searched");store.looted=[false,false,false];store.update_loot_visuals()
 p.position=tower.to_global(Vector3(.45,FireLookout.DECK_Y+1.70,-.25));cam.look_at(tower.to_global(Vector3(1.20,FireLookout.DECK_Y+.93,-1.38)));world.sky_rig.apply_shelter(1);await shot("lookout-workbench")
 p.position=tower.to_global(Vector3(.5,FireLookout.DECK_Y+1.60,-.6));cam.look_at(tower.to_global(Vector3(0,FireLookout.DECK_Y+.68,-2.08)));await shot("lookout-relay")
 world.sky_rig.apply_shelter(0)
 for cabin in world.cabins:
  if cabin.find_child("HamletIdentity",true,false)!=null:
   p.position=cabin.to_global(Vector3(0,1.9,7));cam.look_at(cabin.to_global(Vector3(0,1.8,2.5)));await shot("hamlet-identity");break
 if options.has("art_only"):print("ROUTE_REVIEW_COMPLETE");quit();return
 DisplayServer.window_set_size(Vector2i(960,540));cam.fov=70;p.frozen=false;p.sim_on=false
 var tangent:Vector2=(world.road.points[633]-world.road.points[631]).normalized();var q:Vector2=world.road.points[632]+Vector2(-tangent.y,tangent.x)*6.4
 var shore:=Vector2(-595,-72)
 for z in range(-72,-90,-1):
  if world.forest.trunks_on_segment(-595,z,-625,z)==0:shore.y=z;break
 print("MOTION_SHORE_CLEAR_PATH ",shore)
 var clips:Array=[{"id":"bank-walk","start":q,"dir":Vector2(-1,-1).normalized()},{"id":"shore-walk","start":shore,"dir":Vector2(-1,0)}]
 var key:=InputEventKey.new();key.keycode=KEY_W;key.physical_keycode=KEY_W;key.pressed=true;Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
 var manifest:Array=[]
 for clip in clips:
  var folder:=output.path_join(clip.id);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));p.reset_jump();p.position=Vector3(clip.start.x,400,clip.start.y);p.position.y=p.ground_at(p.position.x,p.position.z)+p.eye_h;p._vel=Vector2.ZERO;p._snow_mult=1;p.yaw=atan2(-clip.dir.x,-clip.dir.y);p.pitch=-.06;cam.rotation=Vector3(p.pitch,p.yaw,0);cam.position=Vector3.ZERO
  var trace:Array=[];var last:=cam.global_position;var old_step:=Vector3.ZERO;var max_change:=Vector3.ZERO
  for frame in 480:
   p._move(1.0/60);p._footsteps(1.0/60)
   var eye:=cam.global_position;var step:=eye-last;var change:=step-old_step;if frame>20:max_change=max_change.max(change.abs())
   last=eye;old_step=step;await process_frame;await RenderingServer.frame_post_draw
   if frame%2==0:
    root.get_texture().get_image().save_png(folder.path_join("%04d.png"%frame));trace.append({"frame":frame,"eye":[eye.x,eye.y,eye.z]})
  manifest.append({"id":clip.id,"fps":30,"frames":trace,"camera_step_change":[max_change.x,max_change.y,max_change.z],"distance_m":Vector2(p.position.x,p.position.z).distance_to(clip.start)})
 key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
 var f:=FileAccess.open(output.path_join("motion.json"),FileAccess.WRITE);f.store_string(JSON.stringify(manifest,"\t"));f.close();print("MOTION_REVIEW_COMPLETE ",JSON.stringify(manifest.map(func(c):return {"id":c.id,"distance_m":c.distance_m,"jerk":c.camera_step_change})));quit()
