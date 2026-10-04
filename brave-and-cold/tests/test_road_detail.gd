extends SceneTree
## Real planned road: geometry/RNG preservation and imported asset contracts.
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failed+=1
func vertices(road:RoadNet)->PackedVector3Array:
	var arrays=(road.get_node("RoadMesh") as MeshInstance3D).mesh.surface_get_arrays(0)
	var result:=PackedVector3Array()
	if arrays[Mesh.ARRAY_INDEX]==null or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():return arrays[Mesh.ARRAY_VERTEX]
	for i in arrays[Mesh.ARRAY_INDEX]:result.append(arrays[Mesh.ARRAY_VERTEX][i])
	return result
func run()->void:
	var t:=Terrain3D.new();t.assets=load("res://data/terrain/terrain_assets.tres")
	t.data_directory="res://data/terrain/valley_b";root.add_child(t)
	var camera:=Camera3D.new();root.add_child(camera);camera.make_current();t.set_camera(camera)
	await process_frame;await process_frame
	var before:=RoadNet.new();before.detail_enabled=false;root.add_child(before)
	before.plan();seed(20261003);before.build_mesh(t);before.build_props(t);var rng_before:=randi()
	var after:=RoadNet.new();root.add_child(after)
	after.plan();seed(20261003);after.build_mesh(t);after.build_props(t);var rng_after:=randi()
	check(before.points==after.points and before.bridges==after.bridges and before._deck==after._deck,"route, bridges and deck elevations preserved")
	check(vertices(before)==vertices(after),"all rendered road triangle positions preserved")
	check(rng_before==rng_after,"global RNG consumption preserved for later gameplay placement")
	check(before.sign_records.size()==after.sign_records.size(),"sign count and roadside anchor slots preserved")
	var anchors:=true;var facing:=true;var no_stop:=true
	for i in after.sign_records.size():
		var a:Dictionary=after.sign_records[i];var b:Dictionary=before.sign_records[i]
		anchors=anchors and a.position==b.position
		var index:int=a.road_index
		var tangent:Vector2=(after.points[index+1]-after.points[index-1]).normalized()
		var direction:=Vector2(sin(float(a.yaw)),cos(float(a.yaw)))
		facing=facing and direction.dot(tangent*(-1.0 if a.side<0 else 1.0))>.999
		no_stop=no_stop and a.kind!="stop"
	check(anchors,"all sign ground positions preserved")
	check(facing,"each front panel faces approaching traffic on its side")
	check(no_stop,"no arbitrary STOP signs on uninterrupted road")
	var arrays=(after.get_node("RoadMesh") as MeshInstance3D).mesh.surface_get_arrays(0)
	check(not (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty(),"metric UVs and tangent space support road relief")
	var finite_normals:=true
	for n:Vector3 in arrays[Mesh.ARRAY_NORMAL]:finite_normals=finite_normals and n.is_finite() and n.length()>.99
	check(finite_normals,"finite normalized slope-aware road normals")
	for kind in ["speed","deer","bear","icy","curve_left","curve_right"]:
		var model:Node3D=(load("res://assets/road_detail/models/"+kind+".glb") as PackedScene).instantiate()
		var meshes:=model.find_children("*","MeshInstance3D",true,false)
		var triangles:=0;var textured:=false
		for item in meshes:
			var mesh:=item as MeshInstance3D
			for i in mesh.mesh.get_surface_count():
				var a:=mesh.mesh.surface_get_arrays(i)
				triangles+=(a[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
				var material:=mesh.get_active_material(i) as BaseMaterial3D
				textured=textured or material.albedo_texture!=null
		check(triangles<=600 and meshes.size()<=4 and textured,"imported "+kind+" within geometry/draw budget and contains baked graphics")
		model.free()
	var grades:Array[float]=[]
	for i in range(1,after.points.size()):
		var a:Vector2=after.points[i-1];var b:Vector2=after.points[i]
		var ha:float=t.data.get_height(Vector3(a.x,0,a.y));var hb:float=t.data.get_height(Vector3(b.x,0,b.y))
		if not is_nan(ha) and not is_nan(hb):grades.append(absf(hb-ha)/a.distance_to(b)*100.0)
	grades.sort()
	print("ROAD_ANALYSIS max_raw_grade_pct=",grades[-1]," p95_raw_grade_pct=",grades[int(grades.size()*.95)]," rendered_triangles=",vertices(after).size()/3," pole_spacing_m=",RoadNet.POLE_GAP)
	print("ROAD_DETAIL_TEST_COMPLETE failures=",failed," points=",after.points.size()," signs=",after.sign_records.size()," metres=",after.length_m)
	before.free();after.free();t.free();quit(0 if failed==0 else 1)
