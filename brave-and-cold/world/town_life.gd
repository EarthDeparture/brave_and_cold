class_name TownLife
extends Node3D
## Three authored residents, separate from pooled population and finite stock.
var world: Node3D
var store: Store
var history:=TownResidentState.new()
var actors: Dictionary={}
var dialogue: Dictionary={}
var conversation: TownConversation
var ledger: Node3D
var closed_sign: Label3D
var _last_calendar := -1
var _legacy_wait := false
## Daily routine (plan A3): data/resident_schedules.json. Rowan lives in the store; Lin and Sam in hamlet cabins.
var schedules: Dictionary = {}
var homes: Dictionary = {}      # id -> Cabin
const STORE_STOVE := Vector3(-1.87, Store.FLOOR_LOCAL_Y, -0.45)

func build(w: Node3D, saved: Dictionary={}, legacy:=false) -> void:
	world=w
	if w.stores.is_empty():return
	store=w.stores[0];dialogue=JSON.parse_string(FileAccess.get_file_as_string("res://data/town_dialogue.json"))
	history.restore(saved)
	schedules = JSON.parse_string(FileAccess.get_file_as_string("res://data/resident_schedules.json"))
	var hamlet: Array = []
	for cb in w.cabins:
		if cb != w.cabins[0]: hamlet.append(cb)
	if hamlet.size() > 0:
		homes["lin"] = hamlet[1 % hamlet.size()]
		homes["sam"] = hamlet[3 % hamlet.size()]
	conversation=TownConversation.new();conversation.life=self;add_child(conversation)
	ledger=(load("res://assets/town_residents/issue_ledger.glb") as PackedScene).instantiate();store.add_child(ledger);ledger.position=Vector3(1.60,1.407,-1.17);ledger.rotation.y=PI/2
	closed_sign=Label3D.new();store.add_child(closed_sign);closed_sign.text="CLOSED\nCollect marked service cases";closed_sign.font_size=40;closed_sign.pixel_size=.0017
	closed_sign.position=Vector3(.82,1.60,Store.HZ+.14);closed_sign.modulate=Color(.86,.76,.59)
	var backing:=MeshInstance3D.new();backing.mesh=BoxMesh.new();backing.mesh.size=Vector3(.75,.24,.012);closed_sign.add_child(backing);backing.position.z=-.005
	var dark:=StandardMaterial3D.new();dark.albedo_color=Color(.075,.09,.08);backing.material_override=dark
	# Existing-save policy: do not materialize an unseen named infected beside a loaded player.
	_legacy_wait=bool(saved.get("arrival_pending",false)) or (legacy and TownResidentState.calendar_phase("rowan",w.clock.day,w.clock.hour)>=TownResidentState.Phase.INFECTED and _store_distance()<35)
	for id: String in TownResidentState.IDS:
		if id=="rowan" and _legacy_wait:continue
		_spawn(id,true)
	w.player.spatial_structures.append(self);update(0)

func _route(id: String) -> Array[Vector3]:
	var local: Array[Vector3]
	var host: Node3D=store
	if id=="rowan":local=[Vector3(2.52,Store.FLOOR_LOCAL_Y,-.70),Vector3(2.52,Store.FLOOR_LOCAL_Y,.60)]
	elif id=="lin":local=[Vector3(-1.5,0,5.5),Vector3(1.5,0,5.5),Vector3(1.5,0,7.5),Vector3(-1.5,0,7.5)]
	else:
		host=world.collapse.clinic if world.collapse.clinic!=null else store
		local=[Vector3(-1.1,0,7.0),Vector3(1.1,0,7.0)]
	var points: Array[Vector3]=[]
	for p: Vector3 in local:
		var at:=host.to_global(p)
		if id!="rowan":
			at.y=RoadNet.lift(world.terrain.data.get_height(at),at.x,at.z)
			for b in world.colliders:
				var y: float=b.floor_at(at.x,at.z,at.y)
				if not is_nan(y):at.y=y;break
		points.append(at)
	return points

func _spawn(id: String, restoring: bool) -> void:
	var r:=history.record(id)
	if bool(r.departed) or bool(r.get("corpse_cleared",false)):return
	var phase:=history.phase(id,world.clock.day,world.clock.hour)
	if id!="rowan" and phase==TownResidentState.Phase.DEPARTED and not bool(r.get("leaving",false)):r.departed=true;return
	var a:=TownResident.new();add_child(a);a.initialize(self,id,_route(id),r);actors[id]=a
	a.tree_exiting.connect(func() -> void:history.record(id).merge(a.snapshot(),true);actors.erase(id))
	a.set_phase(phase,restoring)
	if a.infected and not world.zombies.has(a):world.zombies.append(a)

func update(_gs: float) -> void:
	if store==null:return
	if _legacy_wait and _store_distance()>40:
		_legacy_wait=false;_spawn("rowan",true)
	var stamp: int=world.clock.day*1440+int(world.clock.hour*60)
	if stamp==_last_calendar:return
	_last_calendar=stamp
	for id: String in actors:
		var a: TownResident=actors[id]
		if not is_instance_valid(a):continue
		var next:=history.phase(id,world.clock.day,world.clock.hour)
		if a.phase!=next:
			if conversation.actor==a:conversation.close()
			if a.mode!="work":_apply(a,id,"work")   # they were at work when the day turned; leave / sicken from there
			a.set_phase(next)
			if a.infected and not world.zombies.has(a):world.zombies.append(a)
	_routine()
	var off_shift:=String(block_for("rowan",world.clock.day,world.clock.hour)[2])!="work"
	closed_sign.visible=TownResidentState.calendar_phase("rowan",world.clock.day,world.clock.hour)>=TownResidentState.Phase.ILL or bool(history.record("rowan").dead) or off_shift

# ------------------------------------------------------------------ daily routine
func block_for(id: String, day: int, hour: float) -> Array:
	var s: Dictionary = schedules.get(id, {})
	var list: Array = s.get("worried" if day >= 2 else "ordinary", [])
	for b in list:
		if hour >= float(b[0]) and hour < float(b[1]): return b
	return [0.0, 24.0, "work"]


func _routine() -> void:
	var day: int = world.clock.day
	var hour: float = world.clock.hour
	for id: String in actors:
		var a: TownResident = actors[id]
		if not is_instance_valid(a): continue
		var b := block_for(id, day, hour)
		var act: String = b[2]
		var eligible := a.phase <= TownResidentState.Phase.WORRIED and not a.leaving and not a.infected and not a.is_dead()
		if not eligible:
			if a.mode != "work": _apply(a, id, "work")
			continue
		_maintain(id, act, day)
		if a.activity == act: continue
		var late := hour - float(b[0]) > 0.3
		# never vanish, appear or jump in front of the player: wait until neither end is watched (18 game min at most)
		if not late and a.mode != "away" and a.visible and observed(a): continue
		if not late and act != "commute" and not (act == "sleep" and id == "rowan") and _point_observed(_anchor_for(a, id, act)): continue
		_apply(a, id, act)


func _ground_pt(at: Vector3) -> Vector3:
	at.y = RoadNet.lift(world.terrain.data.get_height(at), at.x, at.z)
	for c in world.colliders:
		var y: float = c.floor_at(at.x, at.z, at.y)
		if not is_nan(y): at.y = y; break
	return at


## Where an activity puts the resident (world position), INF = out of sight.
func _anchor_for(a: TownResident, id: String, act: String) -> Vector3:
	match act:
		"work": return a.route[clampi(a.route_index, 0, a.route.size() - 1)] if a.route.size() > 0 else a.global_position
		"stove": return store.to_global(Vector3(-1.15, Store.FLOOR_LOCAL_Y, -0.10))
		"lunch": return store.to_global(Vector3(-1.30, Store.FLOOR_LOCAL_Y, 0.45))
		"smoke":
			var host: Node3D = world.collapse.clinic if world.collapse != null and world.collapse.clinic != null else store
			return _ground_pt(host.to_global(Vector3(2.2, 0, (Clinic.HZ if host is Clinic else Store.HZ) + 1.4)))
		"home":
			var cb: Cabin = homes.get(id)
			if cb == null: return Vector3.INF
			var p := cb.to_global(Vector3(-1.70, 0, -1.00)); p.y = cb.floor_y; return p
		"sleep":
			var cb: Cabin = homes.get(id)
			if cb == null or id == "rowan": return Vector3.INF
			var p := cb.to_global(Vector3(1.15, 0, -1.65)); p.y = cb.floor_y + 0.46; return p
	return Vector3.INF


func _apply(a: TownResident, id: String, act: String) -> void:
	a.activity = act
	if conversation.actor == a and act != "work": conversation.close()
	a.talking = false
	var p := _anchor_for(a, id, act)
	a.pose = ""
	a.face_at = Vector3.INF
	if id == "rowan":
		var shut := act != "work"   # the shop door is shut whenever the counter is closed
		if store.door_open == shut and not store.door_broken and store.door_boards == 0 and not store.contains_xz(world.player.position.x, world.player.position.z):
			store.toggle_door()   # the shop opens at 05:30 and is shut at night
	if p == Vector3.INF:
		a.mode = "away"; a.visible = false
		if act == "home" or act == "sleep" or act == "commute": _leave_cabin_shut(id)
		return
	a.global_position = p
	a._target = p
	a.speed_now = 0.0
	a.visible = true
	match act:
		"work":
			a.mode = "work"
		"stove", "lunch":
			a.mode = "at"; a.pose = "warm"; a.face_at = store.to_global(STORE_STOVE)
		"smoke":
			a.mode = "at"; a.pose = "smoke"
			var host: Node3D = world.collapse.clinic if world.collapse != null and world.collapse.clinic != null else store
			a.face_at = _ground_pt(host.to_global(Vector3(2.2, 0, 12.0)))
		"home":
			var cb: Cabin = homes[id]
			a.mode = "at"; a.pose = "warm"; a.face_at = cb.stove_world_pos()
			_leave_cabin_shut(id)
		"sleep":
			var cb: Cabin = homes[id]
			a.mode = "sleep"; a.rotation.y = cb.rotation.y


func _leave_cabin_shut(id: String) -> void:
	var cb: Cabin = homes.get(id)
	if cb == null or not cb.door_open or cb.door_broken: return
	if Vector2(world.player.position.x - cb.global_position.x, world.player.position.z - cb.global_position.z).length() < 8.0: return
	cb.toggle_door()


## Fires follow the people: Rowan keeps the shop stove going while up; a home stove is lit while its owner is home
## and awake, and left to burn down to embers overnight.
func _maintain(id: String, act: String, day: int) -> void:
	if id == "rowan" and store.stove != null and act in ["stove", "work"]:
		if store.stove.fire.fuel_s < 1800.0: store.stove.fire.set_fuel(7200.0)
	var cb: Cabin = homes.get(id)
	if cb == null: return
	var in_home := act == "home" or act == "sleep"
	cb.cue_suppressed = in_home and day < 3
	if act == "home" and cb.fire.fuel_s < 1800.0:
		cb.fire.set_fuel(5400.0)


func _point_observed(p: Vector3) -> bool:
	if p == Vector3.INF: return false
	var point := p + Vector3.UP * 1.2
	if not world.player.cam.is_position_in_frustum(point): return false
	var start: Vector3 = world.player.cam.global_position; var d := point - start
	if d.length() > 120.0: return false
	return HitZones.building_block(world._building_list(), start, d.normalized(), d.length()) >= d.length() - .15


func _store_distance() -> float:
	# Player.place holds Y at 400 until its first physics grounding pass.
	# Migration safety therefore measures proximity on the map plane.
	return Vector2(world.player.position.x-store.global_position.x,world.player.position.z-store.global_position.z).length()

func departure_route(a: TownResident) -> Array[Vector3]:
	var host: Node3D=world.collapse.clinic if a.resident_id=="sam" and world.collapse.clinic!=null else store
	var half_z: float=Clinic.HZ if host is Clinic else Store.HZ
	var floor_y: float=Clinic.FLOOR_LOCAL_Y if host is Clinic else Store.FLOOR_LOCAL_Y
	var out: Array[Vector3]=[host.to_global(Vector3(0,floor_y,half_z+2.1)),host.to_global(Vector3(0,floor_y,half_z+.7)),host.to_global(Vector3(0,floor_y,.5))]
	return out

func observed(a: TownResident) -> bool:
	var point:=a.global_position+Vector3.UP*1.2
	if not world.player.cam.is_position_in_frustum(point):return false
	var start: Vector3=world.player.cam.global_position;var d:=point-start
	return HitZones.building_block(world._building_list(),start,d.normalized(),d.length())>=d.length()-.15

func line_for(a: TownResident, topic: String) -> String:
	var entry: Dictionary=dialogue[a.resident_id]
	var key: String="ill" if a.phase==TownResidentState.Phase.ILL else ("worried" if a.phase==TownResidentState.Phase.WORRIED else "ordinary")
	if a.resident_id=="rowan" and topic=="delivery" and world.clock.day>=2 and world.clock.hour>=14:
		return "The depot says the driver called in sick. The truck is held there. Your reserved equipment is already here; don't wait beside the road."
	if a.resident_id=="rowan" and a.phase==TownResidentState.Phase.WORRIED and world.clock.day>=3 and topic in ["delivery","greeting"]:
		return "The truck never came. Cars from the city arrived overnight. My brother still has that fever. The marked cases stay here for you."
	if a.resident_id=="sam" and world.clock.day==1 and world.clock.hour<11:
		return "I'm between house calls. The clinic is open, but check in before entering the treatment room."
	if a.resident_id=="sam" and world.clock.day==3:
		return "The yard is full. Please keep the entrance clear. If you need reserve dressings, take them and go; we can't offer shelter here."
	if topic=="greeting":return String(entry.get(key,entry.ordinary))
	for item: Dictionary in entry.topics:
		if String(item.id)==topic:return String(item.get(key,item.ordinary))
	return String(entry.ordinary)

func actions() -> Array:
	var out: Array=[]
	for id: String in actors:
		var a: TownResident=actors[id]
		if is_instance_valid(a) and a.visible and a.mode!="sleep" and not a.is_dead() and a.phase<TownResidentState.Phase.UNRESPONSIVE:
			out.append({"pos":a.global_position+Vector3.UP*1.4,"r":2.8,"tol":.60,"text":"Talk to "+String(dialogue[id].name),"act":func() -> void:conversation.open(a)})
	if ledger!=null:out.append({"pos":ledger.global_position,"r":1.9,"tol":.5,"text":"Read Rowan's issue ledger","act":read_ledger})
	return out

func read_ledger() -> void:
	var text: String="NORTH RIDGE SUPPLY — RESERVED ISSUE\n\nKestrel 07: transfer relay, marked case. Winter controller held separately; crew packet and tested spur lead required. Reserved equipment may be collected without counter service. No new stock issued by this ledger.\n\nMonday: relay counted and set aside. Delivery booked for Tuesday afternoon. — R. Bell"
	if world.clock.day>=2 and (world.clock.day>2 or world.clock.hour>=14):text+="\n\nTuesday: truck held at depot. Driver off sick. Do not promise replenishment."
	if world.clock.day>=3 and (world.clock.day>3 or world.clock.hour>=11):text+="\n\nWednesday: shaking, can't get warm. Stayed with my brother on Sunday before opening this week. Sam says close counter and keep clear of people. Cases remain for the technician. — Rowan"
	world.reading.open("Rowan's issue ledger",text,world.player,world.hud)

func to_dict() -> Dictionary:
	for id: String in actors:
		var a: TownResident=actors[id]
		if is_instance_valid(a):history.record(id).merge(a.snapshot(),true)
	var saved:=history.to_dict();saved.arrival_pending=_legacy_wait;return saved

func floor_at_world(_p: Vector3, _h: float) -> float:return NAN
func is_sheltered_at(_p: Vector3) -> bool:return false
func ceiling_at_world(_p: Vector3) -> float:return INF
func resolve_at(p: Vector3, previous: Vector3, radius: float) -> Vector2:
	var q:=Vector2(p.x,p.z)
	for a: TownResident in actors.values():
		if not is_instance_valid(a) or not a.visible or a.is_dead() or p.y>a.global_position.y+1.8 or p.y+world.player.eye_h<a.global_position.y+.05:continue
		var center:=Vector2(a.global_position.x,a.global_position.z);var offset:=q-center;var reach:=radius+.25
		if offset.length_squared()<reach*reach:
			if offset.length_squared()<.00001:offset=Vector2(previous.x,previous.z)-center
			if offset.length_squared()<.00001:offset=Vector2.RIGHT
			q=center+offset.normalized()*reach
	return q
