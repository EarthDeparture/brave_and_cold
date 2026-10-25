class_name RouteDressing
extends Node3D
## Deterministic shoulder detail; never changes route, terrain, trees or loot.
static var instances:Array=[]
func _enter_tree()->void:instances.append(self)
func _exit_tree()->void:instances.erase(self)
var records:Array[Dictionary]=[]
var runoff_points:Array[Vector3]=[]
var world:Node3D
func build(w:Node3D)->void:
 world=w
 var path:Array=w.fire_lookout.site.path.points_world_xyz
 for index:int in [12,72,132,191,238]:
  place_near(path,index,"service_marker",1.75,1.0,150.0)
 # Sparse stones and fallen twigs, below boot height and outside the lane.
 for index in range(9,path.size()-9,11):
  place_near(path,index,"shoulder_debris",1.70,-1.0 if index%2==0 else 1.0,65.0)
 # A runoff outlet at the lower maintenance shoulder, rather than a fake
 # culvert crossing a road that has never been excavated.
 var drain_placed:=false
 for index:int in [35,60,92,118,156,182,215]:
  for sign_v:float in [-1.0,1.0]:
   var before:=records.size();place_near(path,index,"drain_headwall",2.6,sign_v,120.0)
   if records.size()>before:drain_placed=true;break
  if drain_placed:break
 var road:Array=world.road.points
 for index in range(24,road.size()-24,47):
  var samples:Array=[]
  for i in range(maxi(0,index-3),mini(index+4,road.size())):samples.append([road[i].x,0,road[i].y])
  place_near(samples,3,"shoulder_debris",5.35,-1.0 if index%2==0 else 1.0,65.0)
 print("ROUTE_DRESSING instances=",records.size())
func place_near(path:Array,index:int,id:String,offset:float,sign_v:float,range_m:float)->void:
 for shift:int in [0,1,-1,2,-2,3,-3,4,-4,6,-6,8,-8,10,-10,12,-12]:
  var i:=clampi(index+shift,1,path.size()-2)
  var p:Vector2=Vector2(path[i][0],path[i][2]);var a:Array=path[i-1];var b:Array=path[i+1]
  var forward:=Vector2(b[0]-a[0],b[2]-a[2]).normalized();var side:=Vector2(-forward.y,forward.x)
  var q:=p+side*offset*sign_v
  var radius:=.70 if id=="drain_headwall" else (.45 if id=="shoulder_debris" else .30)
  if world.forest.resolve_trunks(q.x,q.y,2.1 if id in ["service_marker","drain_headwall"] else radius+.18).distance_to(q)>.01:continue
  var h:float=world.terrain.data.get_height(Vector3(q.x,0,q.y))
  if not is_finite(h):continue
  var clear:=true
  for stop:Vector3 in world.first_week.points:
   if Vector2(stop.x,stop.z).distance_to(q)<3.5:clear=false
  if not clear:continue
  var hx:float=world.terrain.data.get_height(Vector3(q.x+.25,0,q.y))
  var hz:float=world.terrain.data.get_height(Vector3(q.x,0,q.y+.25))
  if not is_finite(hx) or not is_finite(hz):continue
  var normal:=Vector3(-(hx-h)/.25,1,-(hz-h)/.25).normalized()
  if normal.y<.93:continue
  var downhill:=Vector2(normal.x,normal.z)
  if id=="drain_headwall" and (downhill.length()<.035 or downhill.normalized().dot(side*sign_v)<.2):continue
  var model:Node3D=(load("res://assets/route_detail/"+id+".glb") as PackedScene).instantiate();add_child(model)
  model.position=Vector3(q.x,h-.015,q.y)
  var facing:=Vector3(forward.x,0,forward.y)
  if id=="drain_headwall":facing=Vector3(-downhill.normalized().x,0,-downhill.normalized().y)
  if id=="shoulder_debris":facing=Vector3(cos(index*2.41),0,sin(index*2.41))
  model.basis=Basis.looking_at(facing,normal if id=="shoulder_debris" else Vector3.UP)
  for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
   mesh.visibility_range_end=range_m;mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF;mesh.visibility_range_end_margin=range_m*.15
   if id=="shoulder_debris":mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  records.append({"id":id,"position":model.position,"lateral":offset,"radius":radius,"node":model})
  if id=="drain_headwall":build_runoff(model)
  return

func floor_at_world(_foot:Vector3,_ground:float=NAN)->float:return NAN
func is_sheltered_at(_point:Vector3)->bool:return false
func resolve_at(candidate:Vector3,previous:Vector3,radius:float)->Vector2:
 var p:=candidate
 for record:Dictionary in records:
  if record.id=="shoulder_debris":continue # Five-centimetre grit is stepped over.
  var model:Node3D=record.node
  if Vector2(p.x,p.z).distance_squared_to(Vector2(model.position.x,model.position.z))>4:continue
  var old:Vector3=model.to_local(previous);var next:Vector3=model.to_local(p)
  if old.y> (.62 if record.id=="drain_headwall" else 1.55) or old.y<-.5:continue
  var half:=Vector2(.56,.17) if record.id=="drain_headwall" else Vector2(.06,.06)
  var corners:Array[Vector2]=[Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]
  var q:=Vector2(next.x,next.z)
  for i in 4:q=RoadNet._rail_contact(Vector2(old.x,old.z),q,corners[i],corners[(i+1)%4],radius)
  var at:Vector3=model.to_global(Vector3(q.x,next.y,q.y));p.x=at.x;p.z=at.z
 return Vector2(p.x,p.z)
static func resolve_actor(candidate:Vector3,previous:Vector3,radius:float)->Vector2:
 var p:=candidate
 for detail:RouteDressing in instances:
  var q:=detail.resolve_at(p,previous,radius);p.x=q.x;p.z=q.y
 return Vector2(p.x,p.z)

func build_runoff(model:Node3D)->void:
 var rows:Array=[];var d:Vector3=model.basis.z;var side:Vector3=model.basis.x
 var begin:Vector3=model.to_global(Vector3(0,0,.19));var previous_h:float=world.terrain.data.get_height(begin)
 for i in 9:
  var center:Vector3=begin+d*(float(i)*.4)
  var nearest:=INF
  var trail:Array=world.fire_lookout.site.path.points_world_xyz
  for j in range(trail.size()-1):
   var a:=Vector2(trail[j][0],trail[j][2]);var b:=Vector2(trail[j+1][0],trail[j+1][2])
   nearest=minf(nearest,Vector2(center.x,center.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(center.x,center.z),a,b)))
  if nearest<1.7:break
  var h:float=world.terrain.data.get_height(center)
  if not is_finite(h) or h>previous_h+.015:break
  previous_h=h;center.y=h+.008;runoff_points.append(center)
  var row:Array=[]
  for offset:float in [-.33,0,.33]:
   var at:=center+side*offset;at.y=world.terrain.data.get_height(at)+.008
   row.append(at)
  rows.append(row)
 if rows.size()<2:return
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(rows.size()-1):
  for j in 2:
   for pair:Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i,j+1),Vector2i(i,j+1),Vector2i(i+1,j),Vector2i(i+1,j+1)]:
    st.set_uv(Vector2(float(pair.y-1)*.33,float(pair.x)*.4));st.add_vertex(rows[pair.x][pair.y])
 st.index();st.generate_normals();st.generate_tangents()
 var mesh:=MeshInstance3D.new();mesh.name="ShoulderRunoffBed";mesh.mesh=st.commit();add_child(mesh)
 var material:=WinterPathMaterial.create(.33,float(rows.size()-1)*.4)
 material.set_shader_parameter("runoff_mode",true);mesh.material_override=material
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.visibility_range_end=120
