class_name LookoutOpening
extends Node3D
## Additive opening. Existing saves without this block retain their original start.
var world: Node3D
var state: LookoutAssignment
var boundary: RefugeBoundary
var pantry: StorageChest
var home_model: Node3D
var relay: Node3D
var case_model: Node3D
var speaker: AudioStreamPlayer3D
var walkie: AudioStreamPlayer
var _walkie_token := ""
var dock_speaker: AudioStreamPlayer3D
var _dock_token := ""
var charger_model: Node3D
var dock_handset: Node3D
var charger_lens: MeshInstance3D
var _warned_walkie_low := false
const CHARGER_LOCAL := Vector3(2.13,.855,-1.09)
var _audio_captions: Dictionary = {}
var fire_bounce: OmniLight3D
var fire_loop: AudioStreamPlayer3D
var fire_light: OmniLight3D
var stove_smoke: GPUParticles3D
var ember: MeshInstance3D
## Stove rules: the shared FireSource "wood_stove". This stove top fits one pan beside the kettle.
var fire := FireSource.new("wood_stove", {"cook_slots": 1})
const LIGHT_LEAK := 0.3  # glazed room 25 m up: firelight shows, mostly above eye level
var fuel_s: float:
	get: return fire.fuel_s
	set(v): fire.set_fuel(v)
const STARTING_WOOD := 6
const VISIBLE_WOOD_CAP := 12
var wood_left: int:
	get: return maxi(pantry.count("wood"),0) if pantry!=null else 0
var water: PreparedWater:
	get: return fire.water
var water_label:Label3D
var kettle_steam:GPUParticles3D
var city_letter:Node3D
var repair_stock:Node3D
var bottle_stock:Node3D
var cooking: CookBatch:
	get: return fire.cooking
var preservation: FoodPreservation:
	get: return fire.rack
var drying_rack:Node3D
var cook_display:CookDisplay
var _stock: Node3D
var _stock_label: Label3D
var _stock_signature := ""
var _token := ""
var _last_grid := true
var _receiver_power: MeshInstance3D
var _receiver_channel: MeshInstance3D
var _channel_label: Label3D
var _indicator: MeshInstance3D
var solar_site: LookoutSolar
var electrical: ElectricalFieldwork
var shift: ShiftWork
var _power_label: Label3D
const RELAY_LOCAL := Vector3(-9, 0, -6)
const CASE_LOCAL := Vector3(1.60, 1.402, 1.11)

func stove_point(offset: Vector3) -> Vector3:
	return FireLookout.STOVE_CENTER+Vector3.UP*FireLookout.DECK_Y+Basis(Vector3.UP,FireLookout.STOVE_YAW)*offset
func home_point(p: Vector3) -> Vector3:
	return world.fire_lookout.to_global(p + Vector3.UP * FireLookout.DECK_Y)
func build(w: Node3D, assignment: LookoutAssignment, saved: Dictionary = {}) -> void:
	world = w; state = assignment
	state.solar_overcast=world.weather.overcast
	_audio_captions=state.audio_clips
	var tower: FireLookout = world.fire_lookout
	boundary = RefugeBoundary.new(); tower.add_child(boundary); boundary.build(world.terrain)
	boundary.gate_open = bool(saved.get("gate_open", false)); boundary.sync_gate()
	if saved.has("gate_state"):boundary.restore_gate(saved.gate_state)
	boundary.actor_provider=func()->Array:
		var actors:Array=[{"pos":world.player.global_position,"radius":.35}]
		for group:String in ["hostile","prey"]:
			for actor:Node3D in get_tree().get_nodes_in_group(group):
				if actor.has_method("is_dead") and actor.call("is_dead"):continue
				if actor.global_position.distance_squared_to(boundary.gate_point())<36:
					actors.append({"pos":actor.global_position,"radius":.50})
		return actors
	boundary.gate_sound.connect(func(id:String,at:Vector3)->void:world.audio.play_at(id,at,-10,1,3,22))
	world.player.spatial_structures.append(boundary)
	relay = Node3D.new(); tower.add_child(relay)
	relay.position = boundary.ground_local(RELAY_LOCAL.x, RELAY_LOCAL.z)
	_asset(relay, "relay_station")
	# Cabinet and mast remain solid; no invisible pad or surface grading.
	boundary.obstacle_rects.append(Rect2(-10.15,-6.65,1.8,1.12))
	boundary.obstacle_posts.assign([Vector2(-10.04,-7.10),Vector2(-7.96,-7.10),Vector2(-9,-8.15)])
	_relay_foundations()
	solar_site=LookoutSolar.new();solar_site.build(world,boundary)
	_power_label=Label3D.new();_power_label.position=Vector3(0,FireLookout.DECK_Y+.91,-2.065);_power_label.font_size=28;_power_label.pixel_size=.001;_power_label.outline_size=0;_power_label.shaded=true;tower.add_child(_power_label)
	_indicator = MeshInstance3D.new(); var bulb := SphereMesh.new(); bulb.radius = .035; bulb.height = .07
	_indicator.mesh = bulb; _indicator.position = Vector3(.43, 1.45, .48); relay.add_child(_indicator)
	var mat := StandardMaterial3D.new(); mat.emission_enabled = true; _indicator.material_override = mat
	home_model = _asset(tower, "lookout_home_detail"); home_model.position.y = FireLookout.DECK_Y
	pantry = StorageChest.new(); pantry.visual_enabled = false; tower.add_child(pantry)
	pantry.spoilage_rate=1.0 # an indoor provisions shelf is not a snow-cooled outdoor chest
	pantry.position = Vector3(1.90, FireLookout.DECK_Y + .40, 1.62)
	if saved.is_empty():
		fuel_s = 7200.0; pantry.put("beans", 4, 1, 0); pantry.put("jerky", 2, 1, 0); pantry.put("matches", 4, 1, 0); pantry.put("bandage", 2, 1, 0); pantry.put("wood",STARTING_WOOD,1,0)
	else:
		pantry.load_dict(saved.get("storage", {}))
		if saved.has("fire"):
			fire.restore(saved.fire)
		else:  # pre-standard save: separate fuel / single pan / kettle / rack keys
			var pan: Dictionary = saved.get("cooking", {})
			fire.restore({"fuel_s": float(saved.get("fuel_s", 0)), "cooking": {"portions": [pan] if not pan.is_empty() else []}, "water": saved.get("prepared_water", {}), "rack": saved.get("preservation", {})})
		# Older saves had a separate loose rack and collected wood in storage.
		# Merge both exactly once; schema-two storage is already authoritative.
		if int(saved.get("schema",1))<2:
			var loose:=maxi(int(saved.get("wood_left",0)),0)
			if loose>0:pantry.put("wood",loose,1,0)
	drying_rack=(load("res://assets/food_preservation/stove_drying_rack.glb") as PackedScene).instantiate()
	tower.add_child(drying_rack);drying_rack.position=Vector3(-2.12,FireLookout.DECK_Y+.25,.35);drying_rack.rotation.y=PI/2
	cook_display=CookDisplay.new();tower.add_child(cook_display);cook_display.build(1)
	cook_display.position=stove_point(Vector3(-.162,.758,.17));cook_display.rotation.y=FireLookout.STOVE_YAW
	# Wall mounted: no floor pad, stair or new walking collider.

	if saved.is_empty():
		for pair:Array in [["clean_water",2],["empty_bottle",2],["whetstone",1],["sewing_kit",1],["rag",4],["cordage",2]]:pantry.put(pair[0],pair[1],1,0)
	city_letter=(load("res://assets/city_letter/city_letter.glb") as PackedScene).instantiate();tower.add_child(city_letter);city_letter.position=Vector3(.55,FireLookout.DECK_Y+.907,-1.28);city_letter.rotation.y=-.15
	repair_stock=Node3D.new();tower.add_child(repair_stock);repair_stock.position=Vector3(1.9,FireLookout.DECK_Y+.70,1.43)
	for id:String in ["whetstone","sewing_kit"]:
		var n:Node3D=(load("res://assets/maintenance/"+id+".glb") as PackedScene).instantiate();n.name=id;repair_stock.add_child(n);n.position.x=-.13 if id=="whetstone" else .12
	bottle_stock=Node3D.new();tower.add_child(bottle_stock);bottle_stock.position=Vector3(1.9,FireLookout.DECK_Y+.70,1.7)
	water_label=Label3D.new();tower.add_child(water_label);water_label.position=stove_point(Vector3(0,1.1,.5));water_label.rotation.y=FireLookout.STOVE_YAW;water_label.pixel_size=.0017;water_label.font_size=28;water_label.visible=false
	kettle_steam=GPUParticles3D.new();tower.add_child(kettle_steam);kettle_steam.position=stove_point(Vector3(.23,.95,0));kettle_steam.amount=14;kettle_steam.lifetime=1.5;kettle_steam.emitting=false;kettle_steam.visibility_aabb=AABB(Vector3(-.4,-.1,-.4),Vector3(.8,1,.8))
	var steam_process:=ParticleProcessMaterial.new();steam_process.direction=Vector3.UP;steam_process.spread=14;steam_process.gravity=Vector3(0,.06,0);steam_process.initial_velocity_min=.10;steam_process.initial_velocity_max=.16;steam_process.scale_min=.05;steam_process.scale_max=.12;kettle_steam.process_material=steam_process
	var steam_mesh:=QuadMesh.new();steam_mesh.size=Vector2.ONE;var steam_mat:=ShaderMaterial.new();steam_mat.shader=preload("res://world/shaders/winter_vapour.gdshader");steam_mat.set_shader_parameter("opacity",.11);steam_mesh.material=steam_mat;kettle_steam.draw_pass_1=steam_mesh
	_build_stock(tower)
	pantry.contents_changed.connect(_update_stock)
	if not world.stores.is_empty():
		case_model = _asset(world.stores[0], "depot_reserved_case"); case_model.position = CASE_LOCAL
		case_model.visible = not state.parts_claimed
	speaker = AudioStreamPlayer3D.new(); tower.add_child(speaker); speaker.position = Vector3(1.78, FireLookout.DECK_Y + 1.05, -1.17)
	walkie=AudioStreamPlayer.new(); walkie.name="PersonalWalkie"; world.player.add_child(walkie)
	walkie.volume_db=-6
	charger_model=(load("res://assets/field_walkie/field_walkie.glb") as PackedScene).instantiate() as Node3D
	tower.add_child(charger_model);charger_model.position=CHARGER_LOCAL+Vector3.UP*FireLookout.DECK_Y
	dock_handset=charger_model.find_child("Handset",true,false) as Node3D
	dock_speaker=AudioStreamPlayer3D.new();tower.add_child(dock_speaker);dock_speaker.position=charger_model.position+Vector3.UP*.13
	dock_speaker.unit_size=2;dock_speaker.max_distance=12;dock_speaker.volume_db=-6
	charger_lens=MeshInstance3D.new();var lens:=SphereMesh.new();lens.radius=.0035;lens.height=.007;lens.radial_segments=10;lens.rings=5
	charger_lens.mesh=lens;charger_lens.position=Vector3(.032,.026,.035);charger_model.add_child(charger_lens)
	var lens_mat:=StandardMaterial3D.new();lens_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;charger_lens.material_override=lens_mat
	_build_receiver_indicators(tower)
	speaker.unit_size = 2; speaker.max_distance = 12; speaker.volume_db = -5
	fire_light = OmniLight3D.new(); tower.add_child(fire_light); fire_light.position = stove_point(Vector3(0,.48,.62))
	fire_light.light_color = Color(1,.55,.24); fire_light.omni_range = 4.8; fire_light.shadow_enabled = true
	fire_bounce = OmniLight3D.new(); tower.add_child(fire_bounce); fire_bounce.position = Vector3(-.6,FireLookout.DECK_Y+1.15,1.0)
	fire_bounce.light_color = Color(1,.67,.40); fire_bounce.omni_range = 4.2; fire_bounce.shadow_enabled = false
	ember = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(.22,.17); ember.mesh = q
	var em := ShaderMaterial.new(); em.shader = preload("res://world/shaders/stove_embers.gdshader")
	ember.material_override = em; ember.position = stove_point(Vector3(0,.42,.301)); ember.rotation.y=FireLookout.STOVE_YAW; tower.add_child(ember)
	fire_loop = AudioStreamPlayer3D.new(); tower.add_child(fire_loop); fire_loop.position = Vector3(-1.65,FireLookout.DECK_Y+.4,1.65)
	fire_loop.stream = Sfx.get_stream("fire"); fire_loop.volume_db = -18; fire_loop.unit_size = 1.2; fire_loop.max_distance = 8
	_build_smoke(tower)
	_last_grid = state.grid_alive(); world.hud.show_monitor = false
	shift = ShiftWork.new(); shift.build(self, saved.get("shift", {}))
	update_presentation()
func _asset(parent: Node3D, id: String) -> Node3D:
	var node := (load("res://assets/lookout_opening/" + id + ".glb") as PackedScene).instantiate() as Node3D
	node.name = id; parent.add_child(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false): mesh.visibility_range_end = 180 if id == "relay_station" else 75
	return node
func _process(delta:float) -> void:
	if drying_rack==null:return
	var door:=drying_rack.find_child("RackDoor",true,false) as Node3D
	if door==null:return
	var label:=String(world._act.get("text",""))
	var handling:=label.begins_with("Load cooked meat") or label.begins_with("Collect rack food")
	door.rotation.y=move_toward(door.rotation.y,-1.55 if handling else 0,delta*3.8)
func starting_gear(baseline_pace := false) -> void:
	# The departing crew left a working fire. Stored logs remain finite and unchanged.
	fuel_s = (2.0 if baseline_pace else 8.0) * 3600.0
	world.inv = Inventory.new(world.body); world.inv.needs = world.needs
	for pair: Array in [["clean_water",2],["empty_bottle",2],["axe",1],["knife",1],["service_kit",1],["matches",2],["wood",2],["beans",1],["bandage",1],["parka",1],["sweater",1],["toque",1],["hide_mitts",1],["hide_boots",1],["hide_leggings",1]]:
		world.inv.add(pair[0], pair[1])
	for item: String in ["parka","sweater","toque","hide_mitts","hide_boots","hide_leggings"]: world.inv.use(item)
	world._say("Your work order is in the service binder on the desk. Start with the morning weather readings.")
	world._say("Your charged walkie is on the desk. Take it to hear dispatch and public news outside.")
	update_presentation()
func advance(game_s: float) -> void:
	state.advance_to(world.clock.total_game_s,world.weather.overcast,world.weather.precip)
	fire.advance(game_s)
	pantry.tick(game_s)
	if _last_grid and not state.grid_alive(): world._say("The mains have gone silent. " + ("Local backup is supplying the site." if state.backup_on else "Enable local backup at the desk panel."))
	_last_grid = state.grid_alive()
	if state.walkie_carried and state.walkie_wh<=LookoutAssignment.WALKIE_CAP_WH*.15 and not _warned_walkie_low:
		world._say("Walkie battery low. Return it to the desk charger.");_warned_walkie_low=true
	if state.walkie_wh>LookoutAssignment.WALKIE_CAP_WH*.20:_warned_walkie_low=false
	if shift != null: shift.update()
	update_presentation(); _radio_update()
func update_presentation() -> void:
	if cook_display!=null:cook_display.sync(cooking.portions)
	if drying_rack!=null:FoodPreservation.sync_model(drying_rack,preservation)
	if solar_site!=null:solar_site.update_presentation()
	if electrical!=null:electrical.update_presentation()
	if _power_label!=null:
		_power_label.text="%.0f%% • %s"%[state.battery_wh/LookoutAssignment.BATTERY_CAP_WH*100,power_status()]
		_power_label.modulate=Color(.60,.84,.61) if state.powered() else Color(.91,.73,.40)
	if kettle_steam!=null:kettle_steam.emitting=water.batch>0 and fuel_s>0
	_update_receiver_indicators()
	if dock_handset!=null:
		dock_handset.visible=not state.walkie_carried
		var display:=dock_handset.find_child("Display",true,false) as Node3D
		if display!=null:display.visible=state.walkie_ready()
	if charger_lens!=null:
		var cm:=charger_lens.material_override as StandardMaterial3D
		var active:=not state.walkie_carried and state.powered()
		var color:=Color(.15,1,.25) if state.walkie_wh>=LookoutAssignment.WALKIE_CAP_WH-.01 else Color(1,.62,.10)
		cm.albedo_color=color if active else Color(.025,.03,.025);cm.emission_enabled=active;cm.emission=color if active else Color.BLACK
	var lamp := world.fire_lookout.get_node_or_null("LookoutDeskLamp") as OmniLight3D
	if lamp != null: lamp.light_energy = .65 if state.powered() and state.lamp_on else 0
	var glow := fire.glow()
	fire_light.light_energy = (0.80 + .05 * sin(state.last_s * .19)) * glow
	fire_bounce.light_energy = .18 * glow
	ember.visible = glow > 0
	(ember.material_override as ShaderMaterial).set_shader_parameter("intensity", minf(1.0, glow))
	FireVisual.set_smoke(stove_smoke, fire, world.weather.wind_dir)
	if fuel_s > 0 and not fire_loop.playing: fire_loop.play()
	elif fuel_s <= 0 and fire_loop.playing: fire_loop.stop()
	var m := _indicator.material_override as StandardMaterial3D
	m.albedo_color = Color(.10,.65,.29) if state.repair_stage == 3 and state.relay_enabled and state.powered() else Color(.78,.22,.035)
	m.emission = m.albedo_color * .65
	if case_model != null: case_model.visible = not state.parts_claimed
	var food := home_model.get_node_or_null("PantryFood") as Node3D
	if food != null: food.visible = false
	var wood := home_model.get_node_or_null("HomeWood") as Node3D
	if wood != null: wood.visible = false
	_update_stock()
## Two front-panel lenses belong to the existing receiver. No room-sized light
## or transmission claim: these report local power and public reception, even in silence.
func _build_receiver_indicators(tower: FireLookout) -> void:
	_receiver_power = _receiver_lens(tower,"ReceiverPower",1.127)
	_receiver_channel = _receiver_lens(tower,"ReceiverChannel",1.022)
	_receiver_label(tower,"POWER",1.127)
	_channel_label = _receiver_label(tower,"PUBLIC",1.022)
func _receiver_lens(tower: FireLookout, id: String, y: float) -> MeshInstance3D:
	var rim := MeshInstance3D.new(); rim.name=id+"Bezel"
	var cylinder := CylinderMesh.new(); cylinder.top_radius=.011; cylinder.bottom_radius=.011; cylinder.height=.006; cylinder.radial_segments=12
	rim.mesh=cylinder; rim.rotation.x=PI*.5; rim.position=Vector3(1.807,FireLookout.DECK_Y+y,-1.155)
	var metal := StandardMaterial3D.new(); metal.albedo_color=Color(.13,.15,.14); metal.metallic=.6; metal.roughness=.38
	rim.material_override=metal; rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; tower.add_child(rim)
	var lens := MeshInstance3D.new(); lens.name=id
	var bulb := SphereMesh.new(); bulb.radius=.008; bulb.height=.016; bulb.radial_segments=12; bulb.rings=6
	lens.mesh=bulb; lens.position=Vector3(1.807,FireLookout.DECK_Y+y,-1.150); lens.scale.z=.45
	var mat := StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.emission_energy_multiplier=1.6
	lens.material_override=mat; lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; tower.add_child(lens)
	return lens
func _receiver_label(tower: FireLookout, text: String, y: float) -> Label3D:
	var label := Label3D.new(); label.text=text; label.font_size=32; label.pixel_size=.00048; label.outline_size=0; label.shaded=true
	label.position=Vector3(1.878,FireLookout.DECK_Y+y,-1.151); label.modulate=Color(.79,.81,.72); label.no_depth_test=false
	tower.add_child(label); return label
func _update_receiver_indicators() -> void:
	if _receiver_power == null: return
	var on := state.receiver_on and state.powered()
	var colors: Array[Color] = [Color(.13,1,.28),Color(.15,.48,1)]
	var lenses: Array[MeshInstance3D] = [_receiver_power,_receiver_channel]
	for i in lenses.size():
		var mat := lenses[i].material_override as StandardMaterial3D
		mat.albedo_color=colors[i] if on else Color(.025,.030,.026)
		mat.emission_enabled=on; mat.emission=colors[i] if on else Color.BLACK
	_channel_label.text="PUBLIC"

## One live timeline, two devices. No queues or replay on return/load.
func _play_live(output: Node, entry: Dictionary, token: String) -> String:
	if entry.is_empty():
		output.stop(); return ""
	var offset := (state.last_s-float(entry.start_s))/state.audio_clock_rate
	var clip := load(String(entry.audio)) as AudioStream
	if clip==null or offset>=clip.get_length():
		output.stop(); return String(entry.id)
	if token!=String(entry.id) or not output.playing:
		output.stream=clip; output.play(offset)
	elif absf(output.get_playback_position()-offset)>1.5: output.seek(offset)
	return String(entry.id)
## Captions follow the current spoken chunk; earlier lines are not recovered.
func _live_caption(entry: Dictionary) -> String:
	var offset := (state.last_s-float(entry.start_s))/state.audio_clock_rate
	var filename := String(entry.audio).get_file()
	for cue: Dictionary in _audio_captions.get(filename,{}).get("captions",[]):
		if offset>=float(cue.start_s) and offset<float(cue.end_s): return String(cue.text)
	return ""
func dispatch_for_player(now: float) -> Dictionary:
	if not state.walkie_ready():return {}
	if not state.walkie_carried and world.player.position.distance_to(dock_speaker.global_position)>=12:return {}
	return state.dispatch_at(now)
func next_dispatch_wake(after: float, through: float) -> float:
	if not state.walkie_carried and world.player.position.distance_to(dock_speaker.global_position)>=12:return INF
	var call_at:=state.next_dispatch_start(after,through)
	if not is_finite(call_at):return INF
	if state.walkie_carried or not state.powered():
		var needed:=maxf(0,call_at-state.last_s)/3600*LookoutAssignment.WALKIE_MONITOR_W
		if state.walkie_wh<=needed+.0001:return INF
	return call_at
func _radio_update() -> void:
	world.hud.radio_heading="";world.hud.radio_text="";world.hud.radio_device=""
	if world.player.dead:
		walkie.stop();speaker.stop();dock_speaker.stop();return
	var sleeping:bool=world._sl_on and int(world._sl.get("phase",0))!=2
	var dispatch:=state.dispatch_at(state.last_s) if not sleeping and state.walkie_ready() else {}
	var public_signal:=state.public_signal_at(state.last_s) if not sleeping else {}
	var desk:=state.public_broadcast_at(state.last_s) if not sleeping else {}
	var desk_near:bool=world.player.position.distance_to(speaker.global_position)<12
	# Dispatch has priority, though the station reservation normally makes it
	# impossible for both signals to be live. A working nearby desk owns public
	# playback; carrying/docking never starts a second copy beside it.
	var handset:=dispatch
	if handset.is_empty() and state.walkie_ready() and not (desk_near and not desk.is_empty()):handset=public_signal
	_walkie_token=_play_live(walkie,handset if state.walkie_carried else {},_walkie_token)
	_dock_token=_play_live(dock_speaker,handset if not state.walkie_carried else {},_dock_token)
	_token=_play_live(speaker,desk,_token)
	var heard:Dictionary={};var origin:=""
	if walkie.playing and not handset.is_empty():heard=handset;origin="PERSONAL WALKIE"
	elif dock_speaker.playing and not handset.is_empty() and world.player.position.distance_to(dock_speaker.global_position)<12:heard=handset;origin="DESK WALKIE"
	elif speaker.playing and not desk.is_empty() and desk_near:heard=desk;origin="DESK RADIO"
	if not heard.is_empty():
		world.hud.radio_device=String(heard.device)
		world.hud.radio_heading=origin+" • "+("FIELD DISPATCH" if heard.device=="dispatch" else "NORTH RIDGE")+" • "+String(heard.title)
		world.hud.radio_text=_live_caption(heard)
func toggle_walkie_dock() -> void:
	if world.player.position.distance_to(charger_model.global_position)>2.5:
		world._say("Return to the desk to collect or charge your walkie.");return
	state.walkie_carried=not state.walkie_carried
	update_presentation();_radio_update()
	world._say("Walkie taken • dispatch and public monitoring • %d%% battery"%state.walkie_percent() if state.walkie_carried else "Walkie placed in charger. It needs local mains or backup power to recharge.")
func _action(pos: Vector3, text: String, act: Callable, hold: float = 0, bias: float = 0, work: String = "reach") -> Dictionary:
	return {"pos":pos,"r":2.1,"tol":.8,"text":text,"hold":hold,"dbias":bias,"act":act,"work":work}
func actions() -> Array:
	var out: Array = []
	var desk := home_point(Vector3(.95,.88,-1.35))
	out.append(_action(desk, "Read service log", read_log))
	out.append(_action(city_letter.global_position,"Read Elise’s city letter",read_city_letter,0,.025))
	out.append(_action(charger_model.global_position+Vector3.UP*.1,("Dock walkie to charge" if state.walkie_carried else "Take walkie")+" • %d%%"%state.walkie_percent(),toggle_walkie_dock,0,.03))
	var radio := speaker.global_position
	out.append(_action(radio, "Turn receiver off" if state.receiver_on else "Turn receiver on", toggle_receiver))
	var panel := home_point(Vector3(0,1.15,-2.08))
	out.append(_action(panel, "Backup: %s • %.0f%% charge" % ["ON" if state.backup_on else "OFF", state.battery_wh / LookoutAssignment.BATTERY_CAP_WH * 100], toggle_backup))
	out.append(_action(panel+Vector3(0,-.12,0),"Read power status • "+power_status(),read_power_status,0,.04))
	if state.repair_stage == 3:
		out.append(_action(panel, "Automatic transfer: %s" % ("ARMED" if state.auto_transfer_on else "DISABLED"), toggle_auto_transfer, 0, .02))
	out.append(_action(panel, "Switch desk lamp off" if state.lamp_on else "Switch desk lamp on", toggle_lamp, 0, .01))
	out.append(_action(pantry.global_position, "Open lookout provisions", func() -> void: world.gear.open_chest(pantry)))
	var stove: Vector3 = world.fire_lookout.to_global(stove_point(Vector3(0,.55,.301)))
	var dry_point:=home_point(Vector3(-1.94,.65,.35))
	out.append_array(world.fire_actions(fire, stove, update_presentation, 2.1, .8, dry_point))
	out.append(_action(dry_point,"Read food preparation notes",read_food_notes,0,.04))
	var rack:=home_point(Vector3(1.87,.18,1.55))
	out.append(_action(rack, "Take firewood (%d left)" % wood_left, take_wood, 1, .03))
	if wood_left<VISIBLE_WOOD_CAP and world.inv.count("wood")>0:
		out.append(_action(rack,"Stack firewood (%d)"%mini(VISIBLE_WOOD_CAP-wood_left,world.inv.count("wood")),stack_wood,1,.05))
	out.append_array(world._sleep_items(world.fire_lookout))
	var gate_label:="Close compound gate" if boundary.gate_open else "Open compound gate"
	if boundary.gate_blocked:gate_label+=" • clear the swing area"
	elif boundary.gate_moving:gate_label+=" • opening" if boundary.gate_open else " • closing"
	out.append(_action(boundary.gate_point(),gate_label,boundary.toggle_gate))
	var cabinet := relay.to_global(Vector3(0,1.10,.52))
	match state.repair_stage:
		0: out.append(_action(cabinet, "Inspect transfer cabinet", inspect_relay, 6))
		1: out.append(_action(cabinet, "Install replacement transfer relay" if world.inv.count("power_relay") > 0 else ("Retrieve your collected relay from storage or its dropped pickup" if state.parts_claimed else "Replacement reserved at North Ridge Supply"), install_relay, 6))
		2: out.append(_action(cabinet, "Verify backup transfer", verify_relay, 4))
		3:
			out.append(_action(cabinet, "Disable repeater • save 12 W" if state.relay_enabled else "Enable repeater • 12 W", toggle_relay))
			out.append(_action(cabinet, "Relay commissioned • local service only", func() -> void: world._say("Commissioned relay supports site equipment and automatic battery transfer. Your personal dispatch receiver, town grid and public transmitter remain independent."), 0, .01))
	if case_model != null and not state.parts_claimed:
		out.append(_action(case_model.global_position + Vector3.UP * .15, "Collect reserved transfer relay", claim_parts, 3))
	if world.first_week!=null:out.append_array(world.first_week.actions())
	if solar_site!=null:out.append_array(solar_site.actions())
	if electrical!=null:out.append_array(electrical.actions())
	if shift!=null:out.append_array(shift.actions())
	if not world.player.is_sheltered() and world._view_dir().y<-.2:
		var gather:Vector3=world.player.position+world._view_dir()*1.4
		out.append(_action(world._ground(gather.x,gather.z)+Vector3.UP*.04,"Gather clean snow portion",gather_snow,3,.15))
	return out
func gather_snow() -> void:
	if world.player.is_sheltered():return
	if world.inv.can_add("snow_portion"):world.inv.add("snow_portion");world._say("Gathered snow; boil it with an empty bottle at the stove")
	else:world._say("Pack full")
func take_water() -> void:
	var n:=water.collect(world.inv);world._say("Collected %.1f L drinking water"%(n*.5) if n>0 else "Make room in your backpack; water stays in the kettle");update_presentation()
func read_log() -> void:
	var directions := "Follow the logging track down to the road and North Ridge Supply."
	if not world.stores.is_empty():
		var d: Vector3 = world.stores[0].global_position - world.fire_lookout.global_position
		var bearing := fposmod(rad_to_deg(atan2(d.x,-d.z)),360)
		directions = "North Ridge Supply is approximately %.0f m away on bearing %.0f° (straight-line). Follow the logging track down to the road; collect the reserved relay case at the store counter." % [Vector2(d.x,d.z).length(),bearing]
	var task: String = ["Inspect the ground transfer cabinet with your insulated service kit.","Collect the reserved transfer relay, return and install it in the cabinet.","Verify the cabinet transfer circuit with your service tester, even if the home battery is empty.","Relay signed off. Local service restored."][state.repair_stage]
	if state.repair_stage==1 and state.parts_claimed:task="Return to the ground cabinet and install the replacement relay." if world.inv.count("power_relay")>0 else "Retrieve your collected relay from storage or its dropped pickup before returning to the ground cabinet."
	var text := "KESTREL RELAY 07 — FIELD ASSIGNMENT\n\nCurrent work\n%s\n\nDepot and access\n%s\n\nCommunications\nTake the walkie from its desk cradle before travelling. Field dispatch and public news are monitored together. Its battery powers both signals away from home, independently of the desk receiver. A full charge lasts about one day. Dock it on this desk to recharge in roughly three hours from local mains or backup power. Amber indicates charging and green indicates full charge. The desk receiver remains public radio only. Bulletins begin at 06:00, 12:00, 17:00 and 00:00; noon recaps the morning. Green indicates receiver power and blue identifies public radio. Public reports are live, not queued: missed bulletins do not return. Dispatch keeps clear of every public slot. A dispatch call wakes you if your powered walkie is carried or within earshot on the desk; public broadcasts do not. Hold T to look at your wristwatch, or check time and walkie charge in Gear (Tab). Midnight closes the day just lived. The desk receiver and lamp can be switched off separately.\n\nLocal power\nInspect, replace and verify the transfer relay. Commissioning arms automatic battery transfer while the repeater is enabled. Manual backup is available at the desk panel; this supplies the lookout, not the town grid. Commissioning also connects the compound solar charger. Your service tester can commission an empty home reserve. Solar charges during daylight even with the backup output switch off; clouds and panel snow reduce input. Brush the panels when covered. After total depletion, the home outputs wait for 12 Wh before restarting. Read the desk power status or inspect the array for current input and load.\n\nOvernight stock\nDeliveries are expected, but the provisions here are finite. The rack starts with six logs. Each fuels this stove for two hours; collect fallen timber along the logging road, split it with your axe, and restock the rack before dark. Wood deposited in lookout provisions refills the same visible rack. Bring snow portions and empty bottles to the kettle. A batch prepares up to 2 L in 20 game minutes while the stove burns; collect it into your pack, drink in Gear or store it for tomorrow. Follow the timber markers for dry wood, a finite crew cache and the labelled crew-spur disconnect. Stoke the stove and prepare the sleeping berth before the weather closes in.\n\nFirst aid\nIn Gear (Tab), select your bandage and choose Apply bandage, or double-click it. One wrap stops bleeding; it does not restore lost blood immediately or cure infection. Recovery needs food above 900 kcal, water above 45%%, and no fever or hypothermia. Resting warm restores blood faster. Gather cloth and supplies during the first town visit. Outbreak transmission is a separate risk from ordinary wound infection; antibiotics cannot remove it.\n\nRest and maintenance\nFatigue accumulates over game hours. Warm, fed, hydrated sleep restores it; it lowers sustained stamina gradually. Wet clothes reduce sleep quality. At this desk, choose Maintain in Gear for a worn item. A whetstone and rag hone an axe or knife. A sewing kit, two rags and cordage mend clothing. A service kit, stick and two nails repair a hammer. Movement or damage interrupts work before its materials are spent." % [task,directions]
	world.reading.open("North Ridge • Service log",field_plan_text()+"\n\nREFERENCE NOTES\n\n"+text,world.player,world.hud)

func field_plan_text() -> String:
	var work:="Inspect the transfer cabinet beside the compound. Bring the service kit."
	match state.repair_stage:
		1:
			if world.inv.count("power_relay")>0:work="Return and fit the relay already in your pack."
			elif state.parts_claimed:work="Retrieve the relay you collected from its storage or dropped pickup, then return to the ground cabinet."
			else:work="Take the logging track to North Ridge Supply for the reserved relay."
		2:work="Verify the ground transfer circuit before signing off."
		3:work="Relay signed off. Choose your next outing from your actual food, water and fuel reserves."
	var heat:="Stove out — replenish and light it before preparing water or food." if fuel_s<=0 else "Stove: %.1f game hours remaining; %d logs on the rack."%[fuel_s/3600,wood_left]
	var bottles:int=pantry.count("clean_water")+world.inv.count("clean_water")+water.ready
	if shift!=null:
		var p:=shift.progress()
		work="Work order: %d of %d done. Next: %s\n%s"%[p.x,p.y,shift.next_task_title(),work]
	var result:="FIELD PLAN — %s\n\n%s\n\nBefore leaving\n%s\nPrepared drinking water: %.1f L in home stock, pack and kettle.\nWalkie: %s, %.0f%% charge.\n\n"%[world.clock.time_string(),work,heat,bottles*.5,"carried" if state.walkie_carried else "on its desk cradle",state.walkie_percent()]
	result+="Bring enough heat, water and food for the return, and leave room for supplies. The timber stop provides wood; the crew cache is finite. Animals range off the logging track. Cook raw portions, then use the drying rack for longer storage. Processing continues while you work nearby.\n\n"
	result+="Public bulletins: 06:00 / 12:00 / 17:00 / 00:00. Listening is optional. The store counter and clinic notices provide local evidence when reports are missed."
	return result
func toggle_receiver() -> void:
	world.audio.play_at("switch_click",speaker.global_position,-12,1,2,9)
	state.receiver_on = not state.receiver_on; _update_receiver_indicators(); _radio_update()
func toggle_backup() -> void:
	state.backup_on = not state.backup_on; update_presentation(); _radio_update()
	world._say("Local backup %s • %.0f%% • %s. The output switch does not disconnect solar charging." % ["enabled" if state.backup_on else "disabled", state.battery_wh / LookoutAssignment.BATTERY_CAP_WH * 100,power_status()])
func power_status() -> String:
	if state.grid_alive():return "MAINS • FULL" if state.battery_wh>=LookoutAssignment.BATTERY_CAP_WH-.01 else "MAINS CHARGING"
	if state.repair_stage!=3:return "RELAY INCOMPLETE"
	if not state.solar.fault().is_empty():return state.solar.fault()
	if not state.solar.enabled:return "SOLAR DISCONNECTED"
	if state.solar_watts()<=.01:
		if state.solar.snow_cover>=.95:return "PANELS SNOWED OVER"
		return "ON RESERVE • NIGHT" if state.powered() else "WAITING FOR DAYLIGHT"
	if state.recovery_lock:return "RECOVERING"
	if state.battery_wh>=LookoutAssignment.BATTERY_CAP_WH-.01:return "RESERVE FULL"
	var charger_w:=0.0
	if state.powered() and not state.walkie_carried:charger_w=LookoutAssignment.WALKIE_CHARGER_W if state.walkie_wh<LookoutAssignment.WALKIE_CAP_WH-.01 else LookoutAssignment.WALKIE_MONITOR_W/LookoutAssignment.WALKIE_CHARGER_EFFICIENCY
	return "SOLAR CHARGING" if state.solar_watts()>(state.house_load_w()+charger_w if state.powered() else 0.0) else "RESERVE DRAINING"
func read_power_status() -> void:
	var commissioning:="Ground circuit commissioned. The compound solar charger is connected." if state.repair_stage==3 else "Complete the ground cabinet inspection, replacement and commissioning to connect the compound solar charger."
	var diagnosis:="DC circuit checks clear. Night, cloud and snow obstruction are not equipment faults."
	match state.solar.fault():
		"DC FUSE OPEN":diagnosis="DC fuse continuity is open. Fit the matched spare from the logging-road crew packet with your service kit."
		"DC CABLE FAULT":diagnosis="DC lead continuity failed. Isolate the crew-spur feeder, then test and recover its spare lead with your service kit."
		"CHARGER FAULT":diagnosis="Controller self-test failed. The North Ridge Supply winter controller refit requires the crew packet's connectors and the isolated spur's tested lead."
	if not state.solar.cable_ok and not state.solar.controller_ok:diagnosis+=" The controller also failed. The matched winter refit replaces both; a healthy tested lead fitted during cable repair can be reused."
	var text:="%s\n\nHome reserve: %.1f / %.0f Wh.\nSolar input now: %.1f W. Panel snow cover: %.0f%%.\nSelected home loads: %.1f W, plus up to 6 W for a docked walkie."%[power_status(),state.battery_wh,LookoutAssignment.BATTERY_CAP_WH,state.solar_watts(),state.solar.snow_cover*100,state.house_load_w()]
	text+="\n\nDiagnosis\n"+diagnosis
	text+="\n\n"+commissioning+" Your insulated service tester works with an empty home battery. It does not refill it. The backup switch controls the home output; charging continues with that switch off."
	text+="\n\nAfter a flat battery, outputs wait for a 12 Wh reserve, then resume if backup is enabled. Daylight supplies energy; night does not. Clouds and panel snow reduce it. Brush the array when needed. Turn off the repeater (12 W) and lamp (7 W), and isolate the unused crew spur (6 W) to preserve charge. Solar does not restore the town grid or distant broadcasts."
	text+="\n\nController: "+("winter regulator fitted (86% conversion)." if state.solar.winter_controller else "standard regulator (78% conversion). Optional winter refit stock is recorded at the crew cache and North Ridge Supply.")
	world.reading.open("Kestrel 07 • local power",text,world.player,world.hud)
func toggle_auto_transfer() -> void: state.auto_transfer_on = not state.auto_transfer_on
func toggle_relay() -> void:
	state.relay_enabled = not state.relay_enabled; update_presentation(); _radio_update()
	world._say("Repeater %s. Disabling it saves 12 W and prevents automatic backup transfer. Your personal walkie remains independent." % ("enabled" if state.relay_enabled else "disabled"))
func toggle_lamp() -> void: state.lamp_on = not state.lamp_on; update_presentation()
func inspect_relay() -> void:
	if world.inv.count("service_kit") < 1: world._say("Your insulated service kit is required"); return
	if state.inspect(): world._say("Transfer contacts have failed. Replacement reserved at North Ridge Supply. Read the desk log for the route.")
func claim_parts() -> void:
	if state.parts_claimed: return
	# Keep the reservation in its case if the backpack cannot take it.
	if world.inv.can_add("power_relay"):
		world.inv.add("power_relay")
		state.parts_claimed = true; state.depot_visited = true; update_presentation(); world._say("Reserved relay collected. Return to the ground cabinet at the lookout.")
	else: world._say("Make room in your pack; the reserved relay will stay here.")
func install_relay() -> void:
	if state.repair_stage != 1: return
	if world.inv.count("service_kit") < 1 or world.inv.count("power_relay") < 1:
		world._say("Need your service kit and the replacement relay"); return
	if world.inv.remove("power_relay") and state.install(): world._say("Replacement seated. Verify the transfer before signing off.")
func verify_relay() -> void:
	if world.inv.count("service_kit")<1:world._say("Bring your insulated service tester to commission the circuit.");return
	if state.verify():
		update_presentation();_radio_update()
		world._say("Circuit commissioned; solar charger connected and backup armed. An empty reserve recovers in daylight. Switch off unneeded loads while it charges. The town grid remains separate.")
## Thin wrappers over the shared FireSource rules (scripts, tests, shift tasks).
func stoke(fuel_id: String = "wood") -> void:
	var res := fire.stoke(world.inv, fuel_id)
	world._say(String(res.msg)); update_presentation()
func take_wood() -> void:
	if wood_left > 0 and world.inv.can_add("wood"):
		world.chest_take(pantry,"wood",1)
		world.audio.play_at("rustle", pantry.global_position, -6, 1, 3, 18)
func stack_wood() -> void:
	var amount:=mini(maxi(VISIBLE_WOOD_CAP-wood_left,0),world.inv.count("wood"))
	if amount<=0:world._say("The visible rack is full" if wood_left>=VISIBLE_WOOD_CAP else "Gather and split firewood first");return
	world.chest_put(pantry,"wood",amount)
	world.audio.play_at("rustle",pantry.global_position,-6,1,3,18)
func boil() -> void:
	if fuel_s>0:world._say(water.begin(world.inv));update_presentation()
	else:world._say("Light the stove before boiling")
func cook() -> void:
	if fuel_s <= 0: return
	world._say(cooking.begin(world.inv, true)); update_presentation()
func take_cooked() -> void:
	if cooking.ready_count() == 0: return
	if cooking.collect(world.inv) > 0: update_presentation()
	else: world._say("Pack full. Food remains on the stove and continues to age.")
func dry_food() -> void:
	if not preservation.portions.is_empty():world._say(preservation.status());return
	if fuel_s<=0:world._say("Light the stove before starting the drying rack");return
	world._say(preservation.begin(world.inv));update_presentation()
func take_dried() -> void:
	var n:=preservation.collect(world.inv)
	world._say("Collected %d rack portions"%n if n>0 else "Pack full. Rack food remains in place and continues to age.");update_presentation()
func read_food_notes() -> void:
	world.reading.open("Lookout - Food preparation","Cook raw meat or fish on the stove first. One portion needs 20 game minutes of actual burn.\n\nSlice up to four cooked portions with a hunting knife (at least 4% condition); this uses 1% knife condition per portion. The rack needs two game hours of stove burn. Unlit work pauses, but food still spoils. You can leave it running while working outside.\n\nDrying keeps the cooked portion's calories and halves its weight. A fresh dried portion lasts ten game days at normal storage rate. Older food retains the same fraction of shelf life already spent: drying cannot make spoiled food fresh.\n\nCollect finished food promptly. A full pack leaves it on the rack. Keep a meal and drinking water for the next outing; do not spend your final stove fuel just to preserve surplus.",world.player,world.hud)
func heat_at(eye: Vector3) -> float:
	if not world.fire_lookout.contains_room(eye): return 0
	return fire.heat_at(eye.distance_to(home_point(Vector3(-1.65,.55,1.20))), true)
func chimney_world() -> Vector3:
	return world.fire_lookout.to_global(Vector3(-1.65,FireLookout.DECK_Y+4.02,1.20))
func is_refuge(point: Vector3) -> bool:
	if world.fire_lookout.contains_room(point): return true
	if not boundary.is_latched() or not boundary.contains_ground(point): return false
	for actor: Node in get_tree().get_nodes_in_group("hostile"):
		if actor is Node3D and not bool(actor.call("is_dead")) and boundary.contains_ground(actor.global_position): return false
	return true
func to_dict() -> Dictionary:
	return {"state":state.to_dict(),"home":{"schema":2,"electrical":electrical.to_dict() if electrical!=null else {},"shift":shift.to_dict() if shift!=null else {},"fire":fire.to_dict(),"wood_left":wood_left,"storage":pantry.to_dict(),"gate_open":boundary.gate_open,"gate_state":boundary.gate_state()}}
func _relay_foundations() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for foot: Vector2 in [Vector2(-1.04,-1.1),Vector2(1.04,-1.1),Vector2(0,-2.15),Vector2(-.45,0),Vector2(.45,0),Vector2(-.92,-.35)]:
		var w := relay.to_global(Vector3(foot.x,0,foot.y));var terrain_y:float=world.terrain.data.get_height(w)
		var depth := w.y-terrain_y+.10
		if depth < .02: continue
		var box:=BoxMesh.new();box.size=Vector3(.37,depth,.37)
		st.append_from(box,0,Transform3D(Basis.IDENTITY,Vector3(foot.x,-depth*.5,foot.y)))
	var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();relay.add_child(mesh)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.42,.45,.43);mat.roughness=1;mesh.material_override=mat

func _build_smoke(tower: FireLookout) -> void:
	stove_smoke = FireVisual.smoke(tower, Vector3(-1.65, FireLookout.DECK_Y + 4.02, 1.20))

## Counts are derived from authoritative inventory. Rebuild only when they change.
func _build_stock(tower: FireLookout) -> void:
	_stock = Node3D.new(); _stock.name = "LookoutSupplies"; tower.add_child(_stock)
	_stock.position.y = FireLookout.DECK_Y
	# A shallow insert supports pouches above the tins, within the original rack.
	var tray := MeshInstance3D.new(); tray.name = "ProvisionsTray"; tower.add_child(tray)
	tray.mesh = SurvivalProps.mesh_for("tray"); tray.position = Vector3(1.90,FireLookout.DECK_Y+.866,1.65)
	var wool := home_model.get_node_or_null("PantryFixed") as Node3D
	if wool != null: wool.position.y -= .0525
	_stock_label = Label3D.new(); tower.add_child(_stock_label)
	_stock_label.name = "ProvisionsTag"; _stock_label.font_size = 32; _stock_label.pixel_size = .00055
	_stock_label.position = Vector3(1.90, FireLookout.DECK_Y+.585, 1.43)
	_stock_label.rotation.y = PI; _stock_label.no_depth_test = false
	_stock_label.shaded = true; _stock_label.modulate = Color(.81,.77,.63)
	_update_stock()
func _update_stock() -> void:
	if _stock == null: return
	for n:Node3D in repair_stock.get_children():n.visible=pantry.count(n.name)>0
	var beans := maxi(pantry.count("beans"), 0)
	var jerky := maxi(pantry.count("jerky"), 0)
	var other := 0
	for id: String in pantry.contents:
		if id not in ["beans", "jerky", "wood"]: other += maxi(pantry.count(id),0)
	var signature := "%d/%d/%d/%d/%d" % [beans,jerky,wood_left,other,pantry.count("clean_water")]
	if signature == _stock_signature: return
	_stock_signature = signature
	for n:Node in bottle_stock.get_children():bottle_stock.remove_child(n);n.queue_free()
	for i in mini(pantry.count("clean_water"),4):
		var n:Node3D=(load("res://assets/opening_props/field_flask.glb") as PackedScene).instantiate();bottle_stock.add_child(n);n.position=Vector3((i-1.5)*.085,0,0)
	for node: Node in _stock.get_children():
		_stock.remove_child(node); node.queue_free()
	var wood_poses: Array[Transform3D] = []
	for i in mini(wood_left,VISIBLE_WOOD_CAP):
		wood_poses.append(Transform3D(Basis.IDENTITY, Vector3(1.65+(i%2)*.47, .228+floorf(float(i)/4)*.065, 1.56+(int(i/2)%2)*.14)))
	SurvivalProps.pile(_stock,"wood",wood_poses)
	var tin_poses: Array[Transform3D] = []
	for i in mini(beans,4):
		tin_poses.append(Transform3D(Basis(Vector3.UP, -.35+i*.16), Vector3(1.52+(i%4)*.23,.678,1.55+floorf(float(i)/4)*.14)))
	SurvivalProps.pile(_stock,"beans",tin_poses)
	var pouch_poses: Array[Transform3D] = []
	for i in mini(jerky,4):
		pouch_poses.append(Transform3D(Basis(Vector3.UP, -.08+i*.04),Vector3(1.52+i*.23, .881,1.62)))
	SurvivalProps.pile(_stock,"jerky",pouch_poses)
	# Food stack capacity is finite; deposits beyond it stay in inventory and are
	# explicitly marked stored, rather than implying every item is on the shelf.
	var overflow := maxi(beans-4,0)+maxi(jerky-4,0)+maxi(wood_left-VISIBLE_WOOD_CAP,0)
	_stock_label.text = "PROVISIONS • %d tins / %d pouches\nFIREWOOD • %d" % [beans,jerky,maxi(wood_left,0)]
	if other>0 or overflow>0: _stock_label.text += "\n%d other items%s" % [other," • extra stock stored" if overflow>0 else ""]

func read_city_letter()->void:
	world.audio.play_at("paper_turn",city_letter.global_position,-12,1,2,8)
	world.reading.open("From Elise • Sunday",FirstWeekStory.CITY_LETTER,world.player,world.hud)
