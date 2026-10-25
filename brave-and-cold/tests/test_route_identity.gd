extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
 print(("PASS " if ok else "FAIL ")+text)
 if not ok:failures+=1
func run()->void:
 SaveGame.pending={};seed(20261003)
 var world:Node3D=load("res://world/game_world.gd").new();root.add_child(world)
 for i in 600:
  await process_frame
  if world.hud!=null:break
 if world.hud==null:quit(1);return
 world.set_process(false);world.player.set_process(false)
 world.inv=Inventory.new(world.body);world.inv.needs=world.needs
 if OS.get_cmdline_user_args().has("route_detail=baseline"):
  check(not world.stores[0].detail_enabled and world.stores[0]._dressing==null,"baseline keeps original store model")
  check(world.fire_lookout.detail_enabled and not world.fire_lookout.route_dressing_enabled,"baseline retains previous electrical-panel detail")
  check(world.fire_lookout.find_child("TechnicianWorkbench",true,false)==null,"baseline removes new workbench dressing")
  check(world.find_child("LookoutServiceWayfinding",true,false)==null,"baseline removes service route sign")
  print("ROUTE_BASELINE_TEST failures=",failures);quit(0 if failures==0 else 1);return
 var store:Store=world.stores[0]
 check(world.find_child("LookoutServiceWayfinding",true,false)!=null,"service trail has authored wayfinding")
 check(store.detail_enabled and store._dressing!=null,"authored store dressing loaded")
 # The material factor must keep its palette even when importing COLOR_0.
 # An unsupported Blender MixRGB export previously washed these props white.
 var palette:Dictionary={"painted_steel":Color(.06,.12,.10),"aged_steel":Color(.24,.27,.24),"rubber":Color(.017,.021,.02),"paper":Color(.64,.58,.40),"canvas":Color(.24,.25,.14),"red_lead":Color(.25,.032,.017),"cream":Color(.58,.52,.36)}
 var seen:Dictionary={}
 for node:MeshInstance3D in store._dressing.find_children("*","MeshInstance3D",true,false):
  for surface in node.mesh.get_surface_count():
   var mat:=node.get_active_material(surface) as BaseMaterial3D
   if mat==null or not palette.has(mat.resource_name):continue
   var actual:=mat.albedo_color.srgb_to_linear();var expected:Color=palette[mat.resource_name]
   seen[mat.resource_name]=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))<.002 and seen.get(mat.resource_name,true)
 for name in palette:check(seen.get(name,false),"import retains authored prop palette "+name)
 var groups:=["ShelfStock","CounterStock","CrateStock"]
 for i in 3:
  var item:Node3D=store._dressing.find_child(groups[i],true,false)
  check(item!=null and item.visible,"stock visible before search "+groups[i])
  world._loot_store(store,i)
  check(not item.visible,"existing search removes physical stock "+groups[i])
 var saved:=store.state_dict();store.looted=[false,false,false];store.update_loot_visuals();store.restore_state(saved)
 check(store.looted==[true,true,true] and not store._dressing.find_child("ShelfStock",true,false).visible,"search state restores through existing save format")
 store.looted=[false,false,false];store.update_loot_visuals()
 var clear:=true;var radius:=.35
 # The central entrance and search aisles remain clear with real fixtures.
 for x in [-1.2,-.8,0,.8]:
  for z in [-1.20,-.6,0,1,1.6]:
   var point:Vector3=store.to_global(Vector3(x,0,z));var resolved:=store.resolve(point.x,point.z,radius)
   clear=clear and resolved.distance_to(Vector2(point.x,point.z))<.001
 for z in [1.8,2.3,3.1,4.1]:
  var point:Vector3=store.to_global(Vector3(0,0,z));var resolved:=store.resolve(point.x,point.z,radius)
  clear=clear and resolved.distance_to(Vector2(point.x,point.z))<.001
 check(clear,"central store entrance and search aisles remain clear")
 var blocked:Vector3=store.to_global(Vector3(1.25,0,0));var resolved:=store.resolve(blocked.x,blocked.z,.35)
 check(resolved.distance_to(Vector2(blocked.x,blocked.z))>.30,"counter is solid while the aisle remains open")
 for i in 3:
  var stand:Vector3=store.to_global([Vector3(-1.5,1.7,-.9),Vector3(.8,1.7,-.4),Vector3(-1.55,1.7,-.5)][i])
  check(stand.distance_to(store.loot_world_pos(i))<1.7,"physical loot target reachable "+groups[i])
 check(world.fire_lookout.find_child("TechnicianWorkbench",true,false)!=null,"lookout has electrical equipment and service paperwork")
 var identities:=0
 for cabin in world.cabins:
  if cabin.find_child("HamletIdentity",true,false)!=null:identities+=1
 check(identities==world.hamlet_n,"every town home has an authored role plaque")
 # Finite rail contact: tangential travel and contact from either side.
 for side in [-1.0,1.0]:
  var old:=Vector2(3,.41*side);var step:=Vector2(.08,-.05*side)
  var q:=RoadNet._rail_contact(old,old+step,Vector2(0,0),Vector2(10,0),.41)
  check(absf(q.x-(old.x+step.x))<.00001 and absf(q.y-.41*side)<.00001,"rail slide preserves tangent from side %s"%side)
 var br:Array=world.road.bridges[0];var index:int=br[0]+4;var center:Vector2=world.road.points[index]
 var tangent:Vector2=(world.road.points[index+1]-world.road.points[index-1]).normalized();var normal:=Vector2(-tangent.y,tangent.x)
 var height:float=world.road.walk_surface.height_at(center.x,center.y);var edge:Vector2=center+normal*3.4
 var guard:Vector2=world.road.resolve_at(Vector3(edge.x,height,edge.y),Vector3(center.x,height,center.y),.35)
 print("BRIDGE_GUARD_CORRECTION ",guard-center," length=",guard.distance_to(center)," floor=",height," guardedfloor=",world.road.walk_surface.height_at(center.x,center.y,height)," index=",index)
 check(guard.distance_to(center)<3.0,"real bridge rail stops a crossing at a segment join")
 var untouched:Vector2=world.fire_lookout.resolve_at(Vector3(-595,8.77,-72),Vector3(-595.1,8.77,-72),.35)
 check(untouched==Vector2(-595,-72),"remote lookout returns unchanged world coordinates without rounding drift")
 var swept:=RoadNet._rail_contact(Vector2(3,3.2),Vector2(3,-.5),Vector2(0,0),Vector2(10,0),.41)
 check(absf(swept.y-.41)<.00001,"long crossing cannot tunnel through a rail")
 var overlap:=RoadNet._rail_contact(Vector2(3,.2),Vector2(3.04,.18),Vector2(0,0),Vector2(10,0),.41)
 check(overlap.distance_to(Vector2(3,.2))<=.045 and absf(overlap.y-.2)<.00001,"slightly overlapping start is clipped without a teleport")
 print("ROUTE_IDENTITY_TEST failures=",failures);quit(0 if failures==0 else 1)
