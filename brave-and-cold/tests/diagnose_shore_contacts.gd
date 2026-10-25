extends SceneTree
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
 n.set_process(false);n.set_physics_process(false);n.set_process_input(false)
 for child in n.get_children():freeze(child)
func run()->void:
 SaveGame.pending={};seed(20261003);var world:Node3D=load("res://world/game_world.gd").new();root.add_child(world)
 for frame in 600:
  await process_frame
  if world.hud!=null:break
 freeze(world);var p:Player=world.player;p.frozen=false;p.sim_on=true;p.sim_dir=Vector3(-1,0,0);p.reset_jump();p.position=Vector3(-595,400,-72);p.position.y=p.ground_at(-595,-72)+p.eye_h;p._vel=Vector2.ZERO;p._snow_mult=1
 var hits:=0
 for frame in 480:
  var velocity:=p._vel.move_toward(Vector2(-3.2,0),Player.ACCEL/60.0);var candidate:=Vector2(p.position.x,p.position.z)+p._slope_step(velocity/60.0);var original:=candidate
  var next:=p.forest.resolve_trunks(candidate.x,candidate.y,.35)
  if next.distance_to(candidate)>.000001:print("SHORE_CONTACT frame=",frame," forest ",candidate," -> ",next);hits+=1
  candidate=next
  for cabin in p.cabins:
   next=cabin.resolve(candidate.x,candidate.y,.35)
   if next.distance_to(candidate)>.000001:print("SHORE_CONTACT frame=",frame," building ",cabin.get_class()," at ",cabin.position," ",candidate," -> ",next);hits+=1
   candidate=next
  for chest in p.chests:
   next=chest.resolve_at(Vector3(candidate.x,p.position.y-p.eye_h,candidate.y),p.eye_h,.35)
   if next.distance_to(candidate)>.000001:print("SHORE_CONTACT frame=",frame," chest ",chest.position," ",candidate," -> ",next);hits+=1
   candidate=next
  for structure in p.spatial_structures:
   next=structure.resolve_at(Vector3(candidate.x,p.position.y-p.eye_h,candidate.y),Vector3(p.position.x,p.position.y-p.eye_h,p.position.z),.35)
   if next.distance_to(candidate)>.000001:print("SHORE_CONTACT frame=",frame," structure ",structure.position," ",candidate," -> ",next);hits+=1
   candidate=next
  for ribbon in p.walk_ribbons:
   if not ribbon.has_method("resolve_at"):continue
   next=ribbon.resolve_at(Vector3(candidate.x,p.position.y-p.eye_h,candidate.y),Vector3(p.position.x,p.position.y-p.eye_h,p.position.z),.35)
   if next.distance_to(candidate)>.000001:print("SHORE_CONTACT frame=",frame," ribbon ",ribbon.name," ",candidate," -> ",next);hits+=1
   candidate=next
  p._move(1.0/60)
  assert(absf(p.position.z+72)<.0005,"Unobstructed shoreline drifted away from the chosen heading")
 print("SHORE_CONTACT_COMPLETE hits=",hits," end=",p.position);quit(0 if hits==0 else 1)
