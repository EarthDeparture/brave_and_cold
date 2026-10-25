extends SceneTree
var failures:=0
var actor_rows:Array=[]
var max_jerk:=0.0
var max_error:=0.0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures+=1
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false)
 for c:Node in n.get_children():freeze(c)
func run()->void:
 create_timer(180).timeout.connect(func()->void:quit(2))
 SaveGame.pending={};seed(20261004)
 var w:Node3D=load("res://world/game_world.gd").new();root.add_child(w)
 for i in 600:
  await process_frame
  if w.opening!=null and w.gear!=null:break
 freeze(w);w.out_path="test-no-autosave"
 var gate:RefugeBoundary=w.opening.boundary
 gate.actor_provider=func()->Array:return actor_rows
 gate.gate_open=false;gate.sync_gate();gate.toggle_gate()
 check(gate.gate_k==0 and gate.gate_moving and not gate.is_latched(),"gate request does not snap or claim refuge before latching")
 gate.advance_gate(.625)
 check(absf(gate.gate_k-.5)<.00001 and absf(gate._gate.rotation.y+PI*.25)<.00001,"leaf and collision occupy the actual half-open angle")
 var midpoint:Vector2=Vector2(.4,7).lerp(gate.leaf_end(gate.gate_k),.6)
 var tangent:Vector2=(gate.leaf_end(gate.gate_k)-Vector2(.4,7)).normalized();var normal:=Vector2(-tangent.y,tangent.x)
 var previous:Vector3=gate.to_global(Vector3(midpoint.x-normal.x*.8,1,midpoint.y-normal.y*.8))
 var candidate:Vector3=gate.to_global(Vector3(midpoint.x+normal.x*.8,1,midpoint.y+normal.y*.8))
 var clipped:=gate.resolve_at(candidate,previous,.3)
 check(clipped.distance_to(Vector2(candidate.x,candidate.z))>.5,"half-open collision blocks a capsule crossing the moving leaf")
 var fraction:=gate.gate_k;gate.toggle_gate()
 check(gate.gate_k==fraction,"mid-swing reversal keeps continuous leaf position")
 gate.advance_gate(.7);check(gate.is_latched() and gate.gate_k==0,"reverse swing returns to a latched refuge")
 actor_rows=[{"pos":gate.to_global(Vector3(2.2,1,8.2)),"radius":.30}]
 gate.toggle_gate();gate.advance_gate(2)
 check(gate.gate_blocked and gate.gate_k>0 and gate.gate_k<1,"occupied sweep pauses before pushing the actor")
 var blocked:=gate.gate_k;gate.advance_gate(4)
 check(gate.gate_k==blocked,"blocked leaf holds its exact angle")
 actor_rows.clear();gate.advance_gate(2)
 check(gate.gate_k==1 and not gate.gate_moving,"vacated sweep resumes and finishes opening")
 gate.toggle_gate();gate.advance_gate(.3);var state:=gate.gate_state();gate.restore_gate(state)
 check(absf(gate.gate_k-float(state.fraction))<.00001 and not gate.gate_open and gate.gate_moving,"mid-swing save restores angle and closing target")
 gate.advance_gate(2);check(gate.is_latched(),"restored closing gate reaches correct endpoint")
 actor_rows=[{"pos":gate.to_global(Vector3(2.2,10,8.2)),"radius":.3}]
 gate.toggle_gate();gate.advance_gate(2)
 check(gate.gate_k==1,"upstairs actors do not obstruct the ground gate")
 actor_rows.clear()
 for name:String in ["gate_latch","gate_hinge","gate_stop"]:
  check(Sfx.get_stream(name)!=null,"original positional gate foley loads: "+name)
 var a:=RoadNet.new();var b:=RoadNet.new()
 a.update_weather(1,7200)
 for i in 720:b.update_weather(1,10)
 check(absf(a.snow_cover-b.snow_cover)<.00001 and a.snow_cover>.6,"weather surface relaxation is invariant to game-time subdivision")
 var old:=a.snow_cover;a.update_weather(0,1)
 check(a.snow_cover>old-.001,"clearing weather does not instantly strip settled snow")
 w.road.snow_cover=.63;var sv:Dictionary=w._save_data();w.road.snow_cover=0
 w._apply_save(sv)
 check(absf(w.road.snow_cover-.63)<.00001,"route snow presentation survives actual world save/load")
 a.free();b.free()
 var track:MeshInstance3D=w.fire_lookout.get_node("LookoutAccessTrack")
 var arrays:Array=track.mesh.surface_get_arrays(0)
 var valid:=true
 for n:Vector3 in arrays[Mesh.ARRAY_NORMAL]:valid=valid and n.is_finite() and n.length()>.99
 check(valid and not (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty(),"trail has finite slope normals and texture tangents")
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var max_v:=0.0
 for v:Vector2 in uv:max_v=maxf(max_v,v.y)
 check(max_v>568 and max_v<570,"trail textures use surveyed metres rather than stretched endpoint UVs")
 var rendered_match:=true;var surface_errors:=0;var surface_max:=0.0
 var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for j in range(0,indices.size(),3):
  var local:Vector3=(verts[indices[j]]+verts[indices[j+1]]+verts[indices[j+2]])/3
  var at:Vector3=w.fire_lookout.to_global(local);var h:float=w.fire_lookout.access_ribbon.walk_surface.height_at(at.x,at.z,at.y+.2)
  if not is_finite(h) or absf(h-at.y)>.003:
   surface_errors+=1
   if surface_errors<8:print("SURFACE_DIAG ",at," h=",h," difference=",h-at.y)
  if is_finite(h):surface_max=maxf(surface_max,absf(h-at.y))
  rendered_match=rendered_match and is_finite(h) and absf(h-at.y)<.003
 print("SURFACE_DIAG count=",surface_errors," max=",surface_max)
 check(rendered_match,"rendered trail and walk support agree at every triangle centroid")
 var shoulder_clear:=true;var markers:=0;var drain:=0
 for r:Dictionary in w.route_dressing.records:
  shoulder_clear=shoulder_clear and float(r.lateral)-float(r.radius)>=1.15
  if r.id=="service_marker":markers+=1
  if r.id=="drain_headwall":drain+=1
 check(shoulder_clear and markers==5 and drain==1,"five wayfinding markers and runoff outlet stay clear of walking lanes")
 check(w.route_dressing.runoff_points.size()>=4,"runoff outlet has a terrain-following downhill bed")
 var solids:=true
 for r:Dictionary in w.route_dressing.records:
  if r.id=="shoulder_debris":continue
  var model:Node3D=r.node;var solid_old:Vector3=model.to_global(Vector3(0,.1,1));var next:Vector3=model.to_global(Vector3(0,.1,-1))
  var solid_clip:Vector2=w.route_dressing.resolve_at(next,solid_old,.35)
  solids=solids and solid_clip.distance_to(Vector2(next.x,next.z))>.4
 check(solids,"marker stems and drain wall use shared swept actor collision")
 var path:Array=w.fire_lookout.site.path.points_world_xyz
 var player:Player=w.player;player.sim_on=true;player.frozen=false
 for fps:int in ([] if OS.get_cmdline_user_args().has("skip_walk=1") else [30,60,120]):
  for reverse:bool in [false,true]:
   var start:int=path.size()-1 if reverse else 0;var finish:int=0 if reverse else path.size()-1;var step:int=-1 if reverse else 1
   player.reset_jump();player.cam.position=Vector3.ZERO;player._vel=Vector2.ZERO;player._snow_mult=1;player._ready_ground=true
   player.position=Vector3(path[start][0],400,path[start][2]);player.position.y=player.ground_at(player.position.x,player.position.z)+player.eye_h
   var reached:=true;var previous_dy:=0.0
   for i in range(start+step,finish+step,step):
    var q:=Vector2(path[i][0],path[i][2]);var arrived:=false
    for frame in 12*fps:
     var delta:=q-Vector2(player.position.x,player.position.z)
     if delta.length()<.16:arrived=true;break
     delta=delta.normalized();player.sim_dir=Vector3(delta.x,0,delta.y)
     var before_y:float=player.position.y+player.cam.position.y;player._move(1.0/fps)
     var dy:float=player.position.y+player.cam.position.y-before_y
     max_jerk=maxf(max_jerk,absf(dy-previous_dy));previous_dy=dy
     max_error=maxf(max_error,absf(player.position.y-player.eye_h-player.ground_at(player.position.x,player.position.z)))
    if not arrived:reached=false;break
   check(reached,"full 570m trail traversal %d FPS reverse=%s"%[fps,reverse])
 check(max_error<.04,"walk support contact error remains below 4cm")
 check(max_jerk<.06,"camera vertical frame acceleration stays below 6cm")
 print("ROUTE_METRICS contact_m=",max_error," jerk_m=",max_jerk)
 print("ROUTE_POLISH_TEST failures=",failures)
 w.queue_free();await process_frame;SaveGame.pending={};quit(1 if failures else 0)
