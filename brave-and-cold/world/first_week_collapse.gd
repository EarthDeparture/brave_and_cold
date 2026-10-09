class_name FirstWeekCollapse
extends Node3D
## Cohorts are issued once; kills and looted shelves never refill.
var world:Node3D
var clinic:Clinic
var stage:=0
var phase:=-1
var issued:=0
var target_count:=-1
var _triage:Node3D
var _abandoned:Node3D
var _lamp:OmniLight3D
static func plan(w:Node3D,water:Image)->Dictionary:
	if w.store_plan.is_empty():return {}
	var center:=Vector2(w.store_plan.x,w.store_plan.z)
	for radius:float in [28,38,48,58,68,80]:
		for i in 24:
			var q:=center+Vector2.from_angle(i*TAU/24)*radius
			if w.road.is_near(q.x,q.y,12):continue
			var near:Vector2=w._road_edge_toward(q);var yaw:=atan2(near.x-q.x,near.y-q.y);var b:=Basis(Vector3.UP,yaw);var lo:=INF;var hi:=-INF;var ok:=true
			for xx:float in [-5.4,0,5.4]:
				for zz:float in [-4.3,0,4.3]:
					var pt:=Vector3(q.x,0,q.y)+b*Vector3(xx,0,zz);var h:float=w.terrain.data.get_height(pt)
					if is_nan(h) or absf(pt.x)>990 or absf(pt.z)>990:ok=false;continue
					if water.get_pixel(clampi(int(pt.x+1024),0,2047),clampi(int(pt.z+1024),0,2047)).r>.5:ok=false
					lo=minf(lo,h);hi=maxf(hi,h)
			for hs:Dictionary in w.hut_sites:
				if q.distance_to(Vector2(hs.x,hs.z))<22:ok=false
			for hs:Dictionary in w.hamlet_plan:
				if q.distance_to(Vector2(hs.x,hs.z))<22:ok=false
			if ok and hi-lo<.9:return {"x":q.x,"z":q.y,"yaw":rad_to_deg(yaw)}
	push_error("No clear clinic footprint found near town");return {}
func build(w:Node3D,site:Dictionary,saved:Dictionary={})->void:
	world=w
	target_count=int(saved.get("target_count",-1))
	stage=clampi(int(saved.get("stage",4 if w.opening_state.zombies_seeded else 0)),0,4);issued=maxi(0,int(saved.get("issued",0)))
	if site.is_empty():return
	clinic=Clinic.new();w.add_child(clinic)
	if not clinic.setup(w.terrain,site.x,site.z,site.yaw):clinic.queue_free();clinic=null;return
	var spur:=TrailNet.new();add_child(spur);var entry:=clinic.to_global(Vector3(0,0,6.8));spur.add_trail(w._road_edge_toward(Vector2(entry.x,entry.z)),Vector2(entry.x,entry.z),2707);spur.build_mesh(w.terrain);w.player.walk_ribbons.append(spur)
	# Local construction clearing without reseeding the existing forest.
	if w.forest!=null:
		var remove:Array[Vector2]=[]
		for arr:Array in w.forest._trunks.values():
			for v:Vector3 in arr:
				var lp:=clinic.to_local(Vector3(v.x,clinic.position.y,v.y))
				if (absf(lp.x)<9.5 and absf(lp.z)<8.0) or spur.is_near(v.x,v.y,3.0):remove.append(Vector2(v.x,v.y))
		for pt:Vector2 in remove:w.forest.fell(pt.x,pt.y);w.forest.felled.erase(ForestScatter.tree_key(pt.x,pt.y))
	clinic.build_stock(w,saved.get("clinic",{}));w.colliders.append(clinic);w.player.cabins=w.colliders;w.noise_bus.buildings=w.colliders
	for o:Opening in clinic.openings:o.event.connect(w._on_opening_event)
	stage=clampi(int(saved.get("stage",4 if w.opening_state.zombies_seeded else 0)),0,4);issued=maxi(0,int(saved.get("issued",0)))
	_triage=Node3D.new();clinic.add_child(_triage);_abandoned=Node3D.new();clinic.add_child(_abandoned)
	for x:float in [-1.8,1.8]:
		_box(_triage,Vector3(x,.75,5.0),Vector3(.12,.9,.12),Color(.60,.42,.11))
		_box(_triage,Vector3(x,.30,5.0),Vector3(.6,.06,.5),Color(.18,.2,.19))
		_box(_triage,Vector3(x,.95,5.0),Vector3(.5,.06,.015),Color(.62,.44,.12))
	_box(_abandoned,Vector3(-2.1,.37,4.9),Vector3(.70,.14,.6),Color(.31,.39,.31))
	_lamp=OmniLight3D.new();clinic.add_child(_lamp);_lamp.position=Vector3(0,2.3,3.96);_lamp.light_color=Color(1,.65,.30);_lamp.omni_range=4
	update(0)
func _box(parent:Node3D,p:Vector3,size:Vector3,col:Color)->void:
	var mi:=MeshInstance3D.new();var bm:=BoxMesh.new();bm.size=size;mi.mesh=bm;mi.position=p;var m:=StandardMaterial3D.new();m.albedo_color=col;m.roughness=.88;mi.material_override=m;parent.add_child(mi)
func update(gs:float)->void:
	var state:LookoutAssignment=world.opening_state
	if state.enabled:_issue_cohorts(state)
	var day:=clampi(int(floor((state.last_s+state.calendar_origin_s)/86400)),0,4)
	if clinic!=null:
		var ph:=clinic_phase(day,stage)
		clinic.collapse_phase=ph;clinic.set_night(world.sky_rig.gameplay_night_factor)
		for c:StorageChest in clinic.stock:c.tick(gs)
		if ph!=phase:phase=ph;_triage.visible=ph==2;_abandoned.visible=ph>=3
		_lamp.light_energy=.25 if state.grid_alive() else 0
## Notice + props: 0 Mon routine, 1 Tue fever hint, 2 Wed-morning yard triage,
## 3 abandoned once the first local infected exist, 4 final notice from day five.
static func clinic_phase(day:int,stage_issued:int)->int:
	if day<2:return day
	if day==2 and stage_issued==0:return 2
	return 3 if day<4 else 4
func _issue_cohorts(state:LookoutAssignment)->void:
	var cohorts:Array=state.infected_cohorts()
	while stage<cohorts.size() and state.last_s>=float(cohorts[stage].at_s):
		if target_count<0:target_count=world.opening_zombie_count
		var n:=int(target_count*float(cohorts[stage].share))-int(target_count*(float(cohorts[stage-1].share) if stage>0 else 0.0));var rng:=RandomNumberGenerator.new();rng.seed=state.seed_value+1901+stage*719;var placed:=0
		for attempt in n*60:
			if placed>=n:break
			var anchor:=Vector2(clinic.global_position.x,clinic.global_position.z) if clinic!=null else (Vector2(world.stores[0].global_position.x,world.stores[0].global_position.z) if not world.stores.is_empty() else Vector2.ZERO)
			if String(cohorts[stage].anchor)=="roads" and not world.road.points.is_empty():anchor=world.road.points[rng.randi()%world.road.points.size()]
			var close:=anchor.distance_to(Vector2(world.player.position.x,world.player.position.z))<120
			var pt:=anchor+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(140 if close else 15,220 if close else 95)
			if absf(pt.x)>930 or absf(pt.y)>930 or pt.distance_to(Vector2(world.player.position.x,world.player.position.z))<120:continue
			var h:float=world.terrain.data.get_height(Vector3(pt.x,0,pt.y))
			if is_nan(h) or not is_nan(world.ice.ice_at(pt.x,pt.y)):continue
			var pos:=Vector3(pt.x,h,pt.y);var safe:=RefugeBoundary.safe_spawn(pos)
			if safe.distance_squared_to(pos)>.01:continue
			world.pop.add_virtual(pos);placed+=1
		issued+=placed;stage+=1
	state.zombies_seeded=stage>=cohorts.size()
func actions()->Array:return clinic.actions() if clinic!=null else []
func to_dict()->Dictionary:return {"stage":stage,"issued":issued,"target_count":target_count,"clinic":clinic.state_dict() if clinic!=null else {}}
