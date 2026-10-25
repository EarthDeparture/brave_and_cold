extends SceneTree
## Real input, all-direction surface audit; walls/trunks removed only for this isolation.
var options:Dictionary={}
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false)
 for child in n.get_children():freeze(child)
func has_bridge_barrier(id:String)->bool:
 return id.begins_with("road-292-") or id.begins_with("road-298-") or id.begins_with("road-304-")
func run()->void:
 for arg in OS.get_cmdline_user_args():
  var pair:=arg.split("=",true,1);options[pair[0].trim_prefix("--")]=pair[1] if pair.size()>1 else "1"
 seed(20261003);SaveGame.pending={}
 var world:Node3D=load("res://world/game_world.gd").new();root.add_child(world)
 for frame in 600:
  await process_frame
  if world.hud!=null:break
 if world.hud==null:quit(1);return
 freeze(world)
 var p:Player=world.player;p.frozen=false;p.sim_on=false;p.forest=null;p.cabins=[];p.chests=[]
 var points:Array=[]
 for index in [8,100,180,292,298,304,360,520,632,650,800,1016]:
  var q:Vector2=world.road.points[index];var tangent:Vector2=(world.road.points[mini(index+1,1023)]-world.road.points[maxi(index-1,0)]).normalized()
  for side in [-6.55,-6.4,0.0,6.4,6.55]:points.append({"id":"road-%d-%.2f"%[index,side],"point":q+Vector2(-tangent.y,tangent.x)*side})
 for q in [Vector2(-618,-72),Vector2(-600,-72),Vector2(-580,-75),Vector2(-1,803),Vector2(-689,190),Vector2(0,0),Vector2(110,-100),Vector2(340,-250)]:points.append({"id":"terrain-%d"%points.size(),"point":q})
 var key:=InputEventKey.new();key.keycode=KEY_W;key.physical_keycode=KEY_W;key.pressed=true;Input.parse_input_event(key);Input.flush_buffered_events();await process_frame
 print("INPUT_W_PRESSED ",Input.is_key_pressed(KEY_W))
 var rows:Array=[]
 var fps:float=float(options.get("fps",60))
 for item in points:
  for direction in 8:
   var q:Vector2=item.point;var d:=Vector2(cos(direction*TAU/8),sin(direction*TAU/8))
   p.reset_jump();p.position=Vector3(q.x,400,q.y);p.eye_h=Player.EYE;p.position.y=p.ground_at(q.x,q.y)+p.eye_h
   if is_nan(p.position.y):continue
   p.cam.position=Vector3.ZERO;p._vel=Vector2.ZERO;p._snow_mult=1;p._bob_amp=0;p._bob_t=0;p.dbg_blocks=0;p.stamina=100;p.yaw=atan2(-d.x,-d.y);p.pitch=0;p.cam.rotation=Vector3(0,p.yaw,0)
   var last_eye:Vector3=p.cam.global_position;var last_step:=Vector3.ZERO;var max_change:=Vector3.ZERO;var turns:=0;var max_turn:=0.0;var old_velocity:=Vector2.ZERO;var trace:Array=[]
   for frame in int(5*fps):
    var old:=p.position;p._move(1.0/fps)
    var move:=Vector2(p.position.x-old.x,p.position.z-old.z);var eye:=p.cam.global_position;var step:=eye-last_eye;var change:=step-last_step
    if frame>int(fps*.35):max_change=max_change.max(change.abs())
    last_eye=eye;last_step=step
    if frame>20 and move.length()>.001 and old_velocity.length()>.001:
     var turn:=absf(move.angle_to(old_velocity));max_turn=maxf(max_turn,turn)
     if turn>deg_to_rad(8):turns+=1
    old_velocity=move
    if frame%5==0:trace.append({"frame":frame,"body":[p.position.x,p.position.y,p.position.z],"eye":[eye.x,eye.y,eye.z]})
   var end:=Vector2(p.position.x,p.position.z)-q
   rows.append({"id":item.id,"direction":direction,"start":[q.x,q.y],"end":[p.position.x,p.position.z],"turns":turns,"max_turn_deg":rad_to_deg(max_turn),"blocked_frames":p.dbg_blocks,"lateral_m":absf(end.cross(d)),"progress_m":end.dot(d),"camera_step_change":[max_change.x,max_change.y,max_change.z],"trace":trace})
  if rows.size()%80==0:print("DIRECTION_PROGRESS cases=",rows.size())
 key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
 var path:String=options.get("report","res://shots/locomotion-route/directions-current.json");DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
 var free_cases:=0;var unexpected:=0
 for row in rows:
  if has_bridge_barrier(row.id):continue
  free_cases+=1
  if row.turns>0 or row.max_turn_deg>1:unexpected+=1
 print("DIRECTION_AUDIT_COMPLETE cases=",rows.size()," free_cases=",free_cases," unexpected_steering=",unexpected," report=",path)
 quit(0 if unexpected==0 else 1)
