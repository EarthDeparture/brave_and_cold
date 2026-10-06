class_name Clinic
extends Node3D
## Original additive clinic, two exits, two windows and three finite shelves.
## Same collider API as Cabin/Hut. Local frame: +Z is the door side.

const MODEL := "res://assets/clinic/clinic.glb"
const FLOOR_LOCAL_Y := 0.3
const HX := 5.0
const HZ := 3.8
const WALL_T := 0.12
const DOOR_HALF := 0.7
const RAMP_LEN := 1.4
## Physical stock locations for the three existing searches.
const LOOT_SPOTS := [Vector3(-1.5, 1.53, -1.95), Vector3(1.59, 1.50, -0.92), Vector3(-2.49, 1.11, -0.9)]
const LOOT_NAMES := ["Search shelves", "Search counter", "Search crates"]

var detail_enabled := false
var rear:Node3D
var rear_open:=false
var ramps:Array=[]
var world:Node3D
var stock:Array[StorageChest]=[]
var collapse_phase:=0
var _dressing:Node3D

var floor_y := 0.0
var door_open := true
var door_boards := 0
var door_hp := 90.0
var door_broken := false
var looted := [false, false, false]
var _walls: Array[Rect2] = []
var openings: Array[Opening] = []
var _door_pivot: Node3D
var _exam_fill:OmniLight3D
var _fill: OmniLight3D
var _door_rect := Rect2(-DOOR_HALF, HZ - 0.04, 2 * DOOR_HALF, 0.08)


## Footprint test for planning (half extents incl. porch).
static func footprint() -> Vector2:
	return Vector2(HX + 0.5, HZ + 1.6)


func setup(terrain:Terrain3D,x:float,z:float,yaw_deg:float)->bool:
	var hi:=-INF;var lo:=INF;rotation.y=deg_to_rad(yaw_deg)
	for xx:float in [-5.2,0,5.2]:
		for zz:float in [-4.0,0,4.0]:
			var pt:=Vector3(x,0,z)+basis*Vector3(xx,0,zz);var h:float=terrain.data.get_height(pt)
			if is_nan(h):return false
			hi=maxf(hi,h);lo=minf(lo,h)
	if hi-lo>1.0:return false
	position=Vector3(x,hi-.1,z);floor_y=position.y+.3
	_dressing=(load(MODEL) as PackedScene).instantiate();add_child(_dressing)
	for mi:MeshInstance3D in _dressing.find_children("*","MeshInstance3D",true,false):mi.visibility_range_end=160
	_walls=[Rect2(-5.12,-3.92,1.92,.24),Rect2(-1.8,-3.92,6.92,.24),Rect2(-5.12,3.68,4.42,.24),Rect2(.7,3.68,4.42,.24),Rect2(-5.12,-3.92,.24,7.84),Rect2(4.88,-3.92,.24,7.84),Rect2(.95,-3.7,.10,4.05),Rect2(.95,1.75,.1,1.95),Rect2(-4.9,-.75,1.7,.1),Rect2(-1.8,-.75,2.75,.1),Rect2(-4.85,2.12,2.5,.62),Rect2(-4.45,-.30,2.5,.66),Rect2(2.35,-1.68,2.2,.96),Rect2(2.8,-3.65,1.9,.55),Rect2(-4.78,-2.98,1.2,.62),Rect2(1.9,-2.96,.4,.33)]
	_fill=OmniLight3D.new();_fill.position=Vector3(0,2.8,1);_fill.light_color=Color(.87,.91,.86);_fill.omni_range=5.5;_fill.light_energy=.55;add_child(_fill)
	_exam_fill=OmniLight3D.new();add_child(_exam_fill);_exam_fill.position=Vector3(3.4,2.7,-1.2);_exam_fill.omni_range=4.5;_exam_fill.light_color=Color(.90,.92,.86);_exam_fill.light_energy=.35
	_build_door();_door_rect=Rect2(-.7,3.70,1.4,.20)
	rear=Node3D.new();rear.position=Vector3(-3.2,.3,-3.8);add_child(rear)
	var leaf:=MeshInstance3D.new();var bm:=BoxMesh.new();bm.size=Vector3(1.4,2.04,.07);leaf.mesh=bm;leaf.position=Vector3(.7,1.02,0);leaf.material_override=Opening.wood_material();rear.add_child(leaf)
	openings.append(Opening.make(self,"window",1.4,.8,Vector3(-5,1.8,1.5),-90))
	openings.append(Opening.make(self,"window",1.4,.8,Vector3(5,1.8,0),90))
	for pair:Array in [[0,1],[ -2.5,-1]]:
		var side:float=pair[1];var near:=to_global(Vector3(pair[0],.3,side*4.8));var end:=to_global(Vector3(pair[0],0,side*6.8));end.y=terrain.data.get_height(end)+.02;ramps.append([near,end])
		var mesh:=ArrayMesh.new();var ar:=[];ar.resize(Mesh.ARRAY_MAX);var width:=basis.x*.8;ar[Mesh.ARRAY_VERTEX]=PackedVector3Array([near-width,near+width,end+width,near-width,end+width,end-width]);ar[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP]);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ar);var mi:=MeshInstance3D.new();mi.mesh=mesh;add_child(mi);mi.top_level=true;mi.material_override=Opening.wood_material()
	update_loot_visuals();return true

func update_loot_visuals()->void:
	if _dressing==null:return
	for i in stock.size():
		var node:Node3D=_dressing.find_child(["MedicalStock","TreatmentStock","MaintenanceStock"][i],true,false)
		if node!=null:node.visible=not stock[i].is_empty()
	if stock.size()==3:
		for i in 5:
			var n:=_dressing.find_child("DressingUnit"+str(i),true,false) as Node3D
			if n!=null:n.visible=i<stock[0].count("bandage")
		for i in 2:
			var n:=_dressing.find_child("AntisepticUnit"+str(i),true,false) as Node3D
			if n!=null:n.visible=i<stock[1].count("antiseptic")
		var medicine:=_dressing.find_child("AntibioticUnit",true,false) as Node3D
		if medicine!=null:medicine.visible=stock[1].count("antibiotics")>0

func build_stock(w:Node3D,saved:Dictionary={})->void:
	world=w
	for i in 3:
		var c:=StorageChest.new();c.visual_enabled=false;add_child(c);stock.append(c)
		if saved.get("stock",[]).size()==3:c.load_dict(saved.stock[i])
		else:
			for pair:Array in [[["bandage",5],["rag",4]],[["antiseptic",2],["antibiotics",1]],[["matches",4],["empty_bottle",2],["clean_water",2],["whetstone",1],["sewing_kit",1]]][i]:c.put(pair[0],pair[1],1,0)
	restore_state(saved);update_loot_visuals()

func actions()->Array:
	if world.opening==null:return []
	var op:LookoutOpening=world.opening;var out:Array=[]
	for pair:Array in [[to_global(Vector3(0,1.2,HZ)),"Close clinic door" if door_open else "Open clinic door",toggle_door],[to_global(Vector3(-2.5,1.2,-HZ)),"Close rear exit" if rear_open else "Open rear exit",toggle_rear],[to_global(Vector3(-1.1,1.75,3.97)),"Read clinic notice",read_notice]]:out.append(op._action(pair[0],pair[1],pair[2]))
	for i in 3:
		var c:StorageChest=stock[i];out.append(op._action(to_global(Vector3(-4.15,[1.05,1.64,.62][i],-2.4)),["Open dressing shelf","Open treatment shelf","Open field reserve"][i],func()->void:world.gear.open_chest(c),0,.03+i*.01))
	return out
func toggle_rear()->void:
	rear_open=not rear_open;create_tween().tween_property(rear,"rotation:y",deg_to_rad(-105) if rear_open else 0.0,.45)
func read_notice()->void:
	var entries:=["Monday / Routine hours. Nurse Sam Roy is covering house calls. Check in at reception; leave a note if the desk is unattended. Return unused dressings to the supply room. Rear exit leads to the service yard.","Tuesday / Additional respiratory cases reported. Waiting room separated from treatment. Deliveries delayed. Keep the rear exit clear.","Wednesday / No staff on site. District transfer cancelled. First-aid reserve remains in supply room; take only what you can carry. Do not bring fever cases into the waiting room.","Thursday / Evacuation transport did not return. Mara brought the town crew through the service yard. We left on foot towards the logging junction. Keep the last dressings dry. Do not wait here for a vehicle. — Sam Roy","Friday / The district line has gone silent. This is the last written notice. There is no replenishment scheduled."]
	world.reading.open("North Ridge • clinic shift board",entries[clampi(collapse_phase,0,4)]+"\n\nBandages stop bleeding; food, water and warmth support gradual recovery. Antibiotics treat ordinary wound infection. An infected attack carries a separate outbreak risk.",world.player,world.hud)
func _build_door() -> void:
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-DOOR_HALF, FLOOR_LOCAL_Y, HZ)
	add_child(_door_pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2 * DOOR_HALF, 2.0, 0.07)
	mi.mesh = bm
	mi.position = Vector3(DOOR_HALF, 1.0, 0.0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.20, 0.15, 0.11)
	dm.roughness = 0.95
	mi.material_override = dm
	_door_pivot.add_child(mi)
	_door_pivot.rotation.y = deg_to_rad(105.0)


func set_night(f: float) -> void:
	if _fill != null:
		_fill.light_energy = .55 * clampf(1.0 - f, 0.0, 1.0)*(1-.45*world.weather.precip if world!=null else 1.0)
		_exam_fill.light_energy=.35*clampf(1-f,0,1)*(1-.45*world.weather.precip if world!=null else 1.0)


func toggle_door() -> void:
	if door_broken:
		return
	door_open = not door_open
	var tw := create_tween()
	tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(105.0) if door_open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func state_dict() -> Dictionary:
	return {'stock':stock.map(func(c:StorageChest)->Dictionary:return c.to_dict()),'rear_open':rear_open,'open': door_open, 'broken': door_broken, 'hp': door_hp,'windows':openings.map(func(o:Opening)->Dictionary:return o.to_dict())}


func restore_state(d: Dictionary) -> void:
	var lv: Array = d.get('looted', [])
	for i in range(mini(lv.size(), looted.size())):
		looted[i] = bool(lv[i])
	door_broken = bool(d.get('broken', false))
	door_open = bool(d.get('open', true)) or door_broken
	door_hp = float(d.get('hp', 90.0))
	if _door_pivot != null:
		_door_pivot.rotation.y = deg_to_rad(120.0 if door_broken else (105.0 if door_open else 0.0))

	rear_open=bool(d.get("rear_open",false));rear.rotation.y=deg_to_rad(-105) if rear_open else 0
	for i in mini(openings.size(),d.get("windows",[]).size()):openings[i].from_dict(d.windows[i])
	update_loot_visuals()


func loot_world_pos(i: int) -> Vector3:
	var s: Vector3 = LOOT_SPOTS[i]
	return to_global(Vector3(s.x, FLOOR_LOCAL_Y + s.y, s.z))


func noise_leak() -> float:
	return 1.0 if door_open or rear_open else 0.45


func sight_line_open(a: Vector3, b: Vector3) -> bool:
	var la := to_local(a)
	var lb := to_local(b)
	if door_open and (la.z > HZ) != (lb.z > HZ):
		var t := (HZ - la.z) / (lb.z - la.z)
		var p := la + (lb - la) * t
		if absf(p.x) < DOOR_HALF and p.y > FLOOR_LOCAL_Y and p.y < 2.3:
			return true
	if rear_open and (la.z < -HZ)!=(lb.z < -HZ):
		var k:float=(-HZ-la.z)/(lb.z-la.z);var q:Vector3=la.lerp(lb,k)
		if absf(q.x+2.5)<.7 and q.y>.3 and q.y<2.35:return true
	for o in openings:
		if o.open_fraction() >= 0.5 and o.segment_through(a, b):
			return true
	return false


func door_world_pos() -> Vector3:
	return to_global(Vector3(0.0, 0.0, HZ + 0.7))


func bash_door(dmg: float) -> void:
	if door_broken or door_open:
		return
	door_hp -= dmg
	_door_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.06) * 0.03
	if door_hp <= 0.0:
		door_broken = true
		door_open = true
		var tw := create_tween()
		tw.tween_property(_door_pivot, "rotation:y", deg_to_rad(120.0), 0.25)


func to_local_xz(x: float, z: float) -> Vector2:
	var l := to_local(Vector3(x, position.y, z))
	return Vector2(l.x, l.z)


func contains_xz(x: float, z: float) -> bool:
	var l := to_local_xz(x, z)
	return absf(l.x) < HX - 0.2 and absf(l.y) < HZ - 0.2


func resolve(x: float, z: float, r: float) -> Vector2:
	var l := to_local_xz(x, z)
	var moved := false
	var rects := _walls.duplicate()
	if detail_enabled:
		rects.append_array([Rect2(1.25,-1.3,.70,2.6),Rect2(-2.90,-1.20,.80,.60),Rect2(-2.88,.12,.56,.56),Rect2(-2.28,.62,.56,.56),Rect2(-2.70,-2.22,3.40,.36)])
	if not door_open:
		rects.append(_door_rect)
	if not rear_open:rects.append(Rect2(-3.2,-3.9,1.4,.2))
	for w in rects:
		var cx := clampf(l.x, w.position.x, w.end.x)
		var cz := clampf(l.y, w.position.y, w.end.y)
		var d := l - Vector2(cx, cz)
		var dl := d.length()
		if dl < r:
			moved = true
			if dl > 0.0001:
				l = Vector2(cx, cz) + d / dl * r
			else:
				var edges:=[l.x-w.position.x,w.end.x-l.x,l.y-w.position.y,w.end.y-l.y]
				var side:int=edges.find(edges.min())
				if side==0:l.x=w.position.x-r
				elif side==1:l.x=w.end.x+r
				elif side==2:l.y=w.position.y-r
				else:l.y=w.end.y+r
	if not moved:
		return Vector2(x, z)
	var wv := to_global(Vector3(l.x, 0.0, l.y))
	return Vector2(wv.x, wv.z)


func floor_at(x:float,z:float,terrain_h:float)->float:
	var l:=to_local_xz(x,z)
	if absf(l.x)<HX and absf(l.y)<HZ:return floor_y
	if absf(l.x)<1.5 and l.y>=HZ and l.y<=4.8:return floor_y
	if absf(l.x+2.5)<1 and l.y<=-HZ and l.y>=-4.8:return floor_y
	for ramp:Array in ramps:
		var a:Vector3=ramp[0];var b:Vector3=ramp[1];var d:=Vector2(b.x-a.x,b.z-a.z);var p:=Vector2(x-a.x,z-a.z);var t:=p.dot(d)/d.length_squared()
		if t>=0 and t<=1 and absf(p.cross(d.normalized()))<.8:return lerpf(a.y,b.y,t)
	return NAN

## Head clearance for the custom controller; does not affect the walking floor.
func ceiling_at_world(eye: Vector3) -> float:
	var p := to_local(eye)
	if absf(p.x) < DOOR_HALF + 0.20 and absf(p.z - HZ) < 0.30:
		return global_position.y + 2.30
	if absf(p.x) > HX or p.z < -HZ or p.z > HZ + 1.5: return INF
	if p.z > HZ: return global_position.y + 2.70
	return global_position.y+3.35
