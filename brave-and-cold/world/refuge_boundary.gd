class_name RefugeBoundary
extends Node3D
## Terrain-following perimeter, shared by player and all road-aware creatures.
static var instances:Array=[]
const BOUNDS:=Rect2(-12,-10,20,17)
var gate_open:=false
var terrain:Terrain3D
var _gate:Node3D
var segments:Array=[]
var obstacle_rects:Array[Rect2]=[]
var obstacle_posts:Array[Vector2]=[]
func _enter_tree()->void:instances.append(self)
func _exit_tree()->void:instances.erase(self)
func ground_local(x:float,z:float)->Vector3:
	var w:=to_global(Vector3(x,0,z));w.y=terrain.data.get_height(w)+.10;return to_local(w)
func build(t:Terrain3D)->void:
	terrain=t
	segments=[[Vector2(-12,-10),Vector2(8,-10)],[Vector2(-12,-10),Vector2(-12,7)],[Vector2(8,-10),Vector2(8,7)],[Vector2(-12,7),Vector2(.4,7)],[Vector2(3.4,7),Vector2(8,7)]]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post:=CylinderMesh.new();post.top_radius=.038;post.bottom_radius=.046;post.height=1.8;post.radial_segments=8
	var bar:=BoxMesh.new()
	for segment:Array in segments:
		var a:Vector2=segment[0];var b:Vector2=segment[1];var steps:=int(ceil(a.distance_to(b)/2))
		for i in range(steps+1):
			var p:=a.lerp(b,float(i)/steps);var local:=ground_local(p.x,p.y)
			st.append_from(post,0,Transform3D(Basis.IDENTITY,local+Vector3.UP*.78))
		for i in steps:
			var p:=a.lerp(b,float(i)/steps);var q:=a.lerp(b,float(i+1)/steps)
			var u:=ground_local(p.x,p.y);var v:=ground_local(q.x,q.y);var delta:=v-u
			bar.size=Vector3(.045,.045,delta.length());var basis:=Basis.looking_at(delta,Vector3.UP)
			for h in [.14,1.65]:st.append_from(bar,0,Transform3D(basis,(u+v)*.5+Vector3.UP*h))
			# Clipped diagonal wire rows form actual diamonds, rather than tall zigzags.
			var span:=u.distance_to(v);var infill_h:=1.48
			for slope in [-1.0,1.0]:
				for k in range(-9,18):
					var x0:=float(k)*.20
					var low:=maxf(0,-x0/slope) if slope>0 else maxf(0,(x0-span)/-slope)
					var high:=minf(infill_h,(span-x0)/slope) if slope>0 else minf(infill_h,x0/-slope)
					if high<=low:continue
					var start:=u.lerp(v,(x0+slope*low)/span)+Vector3.UP*(.14+low)
					var end:=u.lerp(v,(x0+slope*high)/span)+Vector3.UP*(.14+high)
					bar.size=Vector3(.0035,.0035,start.distance_to(end));st.append_from(bar,0,Transform3D(Basis.looking_at(end-start,Vector3.FORWARD),(start+end)*.5))
	var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.30,.36,.37);mat.metallic=.65;mat.roughness=.72;mesh.material_override=mat;mesh.visibility_range_end=160;add_child(mesh)
	_gate=Node3D.new();_gate.position=ground_local(.4,7);add_child(_gate)
	var gate_mesh:Node3D=(load("res://assets/lookout_opening/refuge_gate.glb") as PackedScene).instantiate();_gate.add_child(gate_mesh)
func toggle_gate()->void:
	gate_open=not gate_open;sync_gate()
func sync_gate()->void:
	_gate.rotation.y=-PI*.5 if gate_open else 0
func gate_point()->Vector3:return to_global(ground_local(1.9,7)+Vector3.UP)
func contains_ground(point:Vector3)->bool:
	var p:=to_local(point);return BOUNDS.grow(-.5).has_point(Vector2(p.x,p.z)) and p.y<5
func floor_at_world(_p:Vector3,_h:float=NAN)->float:return NAN
func ceiling_at_world(_p:Vector3)->float:return INF
func is_sheltered_at(_p:Vector3)->bool:return false
func resolve_at(candidate:Vector3,previous:Vector3,radius:float)->Vector2:
	if to_local(previous).y>5:return Vector2(candidate.x,candidate.z)
	var old:=to_local(previous);var p:=to_local(candidate);var q:=Vector2(p.x,p.z);var original:=q
	var walls:=segments.duplicate()
	if not gate_open:walls.append([Vector2(.4,7),Vector2(3.4,7)])
	else:walls.append([Vector2(.4,7),Vector2(.4,10)])
	for wall:Array in walls:
		var clipped:=RoadNet._rail_contact(Vector2(old.x,old.z),q,wall[0],wall[1],radius+.07)
		if clipped.distance_squared_to(q)>.0000000001:q=clipped+(clipped-q).normalized()*.001
	for box:Rect2 in obstacle_rects:q=get_parent()._push_rect(q,box.grow(radius),Vector2(old.x,old.z))
	for post:Vector2 in obstacle_posts:
		var d:=q-post;var rr:=radius+.20
		if d.length_squared()<rr*rr:q=post+(d.normalized() if d.length_squared()>.000001 else Vector2.RIGHT)*rr
	if q==original:return Vector2(candidate.x,candidate.z)
	var w:=to_global(Vector3(q.x,p.y,q.y));return Vector2(w.x,w.z)
static func resolve_actor(candidate:Vector3,previous:Vector3,radius:float)->Vector2:
	var p:=candidate
	for boundary:RefugeBoundary in instances:
		if not is_instance_valid(boundary):continue
		var q:=boundary.resolve_at(p,previous,radius);p.x=q.x;p.z=q.y
	return Vector2(p.x,p.z)
static func safe_spawn(point:Vector3)->Vector3:
	for boundary:RefugeBoundary in instances:
		if not is_instance_valid(boundary) or boundary.gate_open or not boundary.contains_ground(point):continue
		var p:=boundary.to_local(point)
		var distances:=[p.x-BOUNDS.position.x,BOUNDS.end.x-p.x,p.z-BOUNDS.position.y,BOUNDS.end.y-p.z]
		match distances.find(distances.min()):
			0:p.x=BOUNDS.position.x-.65
			1:p.x=BOUNDS.end.x+.65
			2:p.z=BOUNDS.position.y-.65
			3:p.z=BOUNDS.end.y+.65
		point=boundary.to_global(p);point.y=boundary.terrain.data.get_height(point)
	return point
