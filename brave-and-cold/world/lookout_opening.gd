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
var _dispatch_token := ""
var _audio_captions: Dictionary = {}
var fire_bounce: OmniLight3D
var fire_loop: AudioStreamPlayer3D
var fire_light: OmniLight3D
var stove_smoke: GPUParticles3D
var ember: MeshInstance3D
var fuel_s := 7200.0
var wood_left := 12
var cooking: Dictionary = {}
var _stock: Node3D
var _stock_label: Label3D
var _stock_signature := ""
var _token := ""
var _last_grid := true
var _receiver_power: MeshInstance3D
var _receiver_channel: MeshInstance3D
var _channel_label: Label3D
var _indicator: MeshInstance3D
const RELAY_LOCAL := Vector3(-9, 0, -6)
const CASE_LOCAL := Vector3(1.60, 1.42, 1.02)

func stove_point(offset: Vector3) -> Vector3:
	return FireLookout.STOVE_CENTER+Vector3.UP*FireLookout.DECK_Y+Basis(Vector3.UP,FireLookout.STOVE_YAW)*offset
func home_point(p: Vector3) -> Vector3:
	return world.fire_lookout.to_global(p + Vector3.UP * FireLookout.DECK_Y)
func build(w: Node3D, assignment: LookoutAssignment, saved: Dictionary = {}) -> void:
	world = w; state = assignment
	_audio_captions=state.audio_clips
	var tower: FireLookout = world.fire_lookout
	boundary = RefugeBoundary.new(); tower.add_child(boundary); boundary.build(world.terrain)
	boundary.gate_open = bool(saved.get("gate_open", false)); boundary.sync_gate()
	world.player.spatial_structures.append(boundary)
	relay = Node3D.new(); tower.add_child(relay)
	relay.position = boundary.ground_local(RELAY_LOCAL.x, RELAY_LOCAL.z)
	_asset(relay, "relay_station")
	# Cabinet and mast remain solid; no invisible pad or surface grading.
	boundary.obstacle_rects.append(Rect2(-10.15,-6.65,1.8,1.12))
	boundary.obstacle_posts.assign([Vector2(-10.04,-7.10),Vector2(-7.96,-7.10),Vector2(-9,-8.15)])
	_relay_foundations()
	_indicator = MeshInstance3D.new(); var bulb := SphereMesh.new(); bulb.radius = .035; bulb.height = .07
	_indicator.mesh = bulb; _indicator.position = Vector3(.43, 1.45, .48); relay.add_child(_indicator)
	var mat := StandardMaterial3D.new(); mat.emission_enabled = true; _indicator.material_override = mat
	home_model = _asset(tower, "lookout_home_detail"); home_model.position.y = FireLookout.DECK_Y
	pantry = StorageChest.new(); pantry.visual_enabled = false; tower.add_child(pantry)
	pantry.position = Vector3(1.90, FireLookout.DECK_Y + .40, 1.62)
	if saved.is_empty():
		pantry.put("beans", 4, 1, 0); pantry.put("jerky", 2, 1, 0); pantry.put("matches", 4, 1, 0); pantry.put("bandage", 2, 1, 0)
	else:
		pantry.load_dict(saved.get("storage", {})); fuel_s = float(saved.get("fuel_s", 0)); wood_left = int(saved.get("wood_left", 0)); cooking = saved.get("cooking", {}).duplicate(true)
	_build_stock(tower)
	pantry.contents_changed.connect(_update_stock)
	if not world.stores.is_empty():
		case_model = _asset(world.stores[0], "depot_reserved_case"); case_model.position = CASE_LOCAL
		case_model.visible = not state.parts_claimed
	speaker = AudioStreamPlayer3D.new(); tower.add_child(speaker); speaker.position = Vector3(1.78, FireLookout.DECK_Y + 1.05, -1.17)
	walkie=AudioStreamPlayer.new(); walkie.name="PersonalWalkie"; world.player.add_child(walkie)
	walkie.volume_db=-6
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
	update_presentation()
func _asset(parent: Node3D, id: String) -> Node3D:
	var node := (load("res://assets/lookout_opening/" + id + ".glb") as PackedScene).instantiate() as Node3D
	node.name = id; parent.add_child(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false): mesh.visibility_range_end = 180 if id == "relay_station" else 75
	return node
func starting_gear() -> void:
	world.inv = Inventory.new(world.body); world.inv.needs = world.needs
	for pair: Array in [["axe",1],["knife",1],["service_kit",1],["matches",2],["wood",2],["beans",1],["bandage",1],["parka",1],["sweater",1],["toque",1],["hide_mitts",1],["hide_boots",1],["hide_leggings",1]]:
		world.inv.add(pair[0], pair[1])
	for item: String in ["parka","sweater","toque","hide_mitts","hide_boots","hide_leggings"]: world.inv.use(item)
	world._say("Inspect the relay cabinet beside the tower. Read the service log on your desk.")
	world._say("Your walkie receives dispatch. The desk radio carries public news.")
func advance(game_s: float) -> void:
	state.advance_to(world.clock.total_game_s)
	var burn := minf(game_s, fuel_s); fuel_s = maxf(0, fuel_s - game_s)
	if not cooking.is_empty(): cooking["remaining_s"] = maxf(0, float(cooking.remaining_s) - burn)
	pantry.tick(game_s)
	if _last_grid and not state.grid_alive(): world._say("The mains have gone silent. " + ("Local backup is supplying the site." if state.backup_on else "Enable local backup at the desk panel."))
	_last_grid = state.grid_alive()
	if state.last_s >= 28 * 3600 and not state.zombies_seeded:
		state.zombies_seeded = true
		world._populate(world.opening_zombie_count, Vector2(world.player.position.x, world.player.position.z))
		world.pop.specials = world.pop.specials.filter(func(v:Vector3)->bool: return Vector2(v.x-world.player.position.x,v.z-world.player.position.z).length()>120)
	update_presentation(); _radio_update()
func update_presentation() -> void:
	_update_receiver_indicators()
	var lamp := world.fire_lookout.get_node_or_null("LookoutDeskLamp") as OmniLight3D
	if lamp != null: lamp.light_energy = .65 if state.powered() and state.lamp_on else 0
	fire_light.light_energy = (0.80 + .05 * sin(state.last_s * .19)) if fuel_s > 0 else 0
	fire_bounce.light_energy = .18 if fuel_s > 0 else 0
	ember.visible = fuel_s > 0
	stove_smoke.emitting = fuel_s > 0
	var motion := stove_smoke.process_material as ParticleProcessMaterial
	motion.gravity = Vector3(world.weather.wind_dir.x*.18,.45,world.weather.wind_dir.y*.18)
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
func _radio_update() -> void:
	world.hud.radio_heading=""; world.hud.radio_text=""; world.hud.radio_device=""
	if world.player.dead:
		walkie.stop(); speaker.stop(); return
	var sleeping: bool = world._sl_on and int(world._sl.get("phase",0))!=2
	var dispatch := state.dispatch_at(state.last_s) if not sleeping else {}
	var bulletin := state.public_broadcast_at(state.last_s) if not sleeping else {}
	# Stop conflicting dispatch before starting the desk transmission.
	_dispatch_token=_play_live(walkie,dispatch,_dispatch_token)
	_token=_play_live(speaker,bulletin,_token)
	if walkie.playing and not dispatch.is_empty():
		world.hud.radio_device="dispatch"
		world.hud.radio_heading="PERSONAL WALKIE • FIELD DISPATCH • "+String(dispatch.title)
		world.hud.radio_text=_live_caption(dispatch)
	elif speaker.playing and not bulletin.is_empty() and world.player.position.distance_to(speaker.global_position)<12:
		world.hud.radio_device="public"
		world.hud.radio_heading="DESK RADIO • NORTH RIDGE • "+String(bulletin.title)
		world.hud.radio_text=_live_caption(bulletin)
func _action(pos: Vector3, text: String, act: Callable, hold: float = 0, bias: float = 0, work: String = "reach") -> Dictionary:
	return {"pos":pos,"r":2.1,"tol":.8,"text":text,"hold":hold,"dbias":bias,"act":act,"work":work}
func actions() -> Array:
	var out: Array = []
	var desk := home_point(Vector3(.95,.88,-1.35))
	out.append(_action(desk, "Read service log", read_log))
	var radio := speaker.global_position
	out.append(_action(radio, "Turn receiver off" if state.receiver_on else "Turn receiver on", toggle_receiver))
	var panel := home_point(Vector3(0,1.15,-2.08))
	out.append(_action(panel, "Backup: %s • %.0f%% charge" % ["ON" if state.backup_on else "OFF", state.battery_wh / LookoutAssignment.BATTERY_CAP_WH * 100], toggle_backup))
	if state.repair_stage == 3:
		out.append(_action(panel, "Automatic transfer: %s" % ("ARMED" if state.auto_transfer_on else "DISABLED"), toggle_auto_transfer, 0, .02))
	out.append(_action(panel, "Switch desk lamp off" if state.lamp_on else "Switch desk lamp on", toggle_lamp, 0, .01))
	out.append(_action(pantry.global_position, "Open lookout provisions", func() -> void: world.gear.open_chest(pantry)))
	var stove: Vector3 = world.fire_lookout.to_global(stove_point(Vector3(0,.55,.301)))
	out.append(_action(stove, "Stoke stove • %.1f h fuel" % (fuel_s / 3600), stoke, 2))
	if fuel_s > 0:
		out.append(_action(stove, "Boil snow and drink", boil, 4, .01))
		if cooking.is_empty() and world.inv.has_raw(): out.append(_action(stove, "Cook one portion on stove", cook, 2, .02))
	if not cooking.is_empty():
		out.append(_action(stove, "Take cooked food" if float(cooking.remaining_s) <= 0 else "Cooking • %d min left" % int(ceil(float(cooking.remaining_s)/60)), take_cooked, 0, .03))
	out.append(_action(home_point(Vector3(1.87,.18,1.55)), "Take firewood (%d left)" % wood_left, take_wood, 1, .03))
	out.append_array(world._sleep_items(world.fire_lookout))
	out.append(_action(boundary.gate_point(), "Close compound gate" if boundary.gate_open else "Open compound gate", boundary.toggle_gate))
	var cabinet := relay.to_global(Vector3(0,1.10,.52))
	match state.repair_stage:
		0: out.append(_action(cabinet, "Inspect transfer cabinet", inspect_relay, 6))
		1: out.append(_action(cabinet, "Install replacement transfer relay" if world.inv.count("power_relay") > 0 else "Replacement reserved at North Ridge Supply", install_relay, 6))
		2: out.append(_action(cabinet, "Verify backup transfer", verify_relay, 4))
		3:
			out.append(_action(cabinet, "Disable repeater • save 12 W" if state.relay_enabled else "Enable repeater • 12 W", toggle_relay))
			out.append(_action(cabinet, "Relay commissioned • local service only", func() -> void: world._say("Commissioned relay supports site equipment and automatic battery transfer. Your personal dispatch receiver, town grid and public transmitter remain independent."), 0, .01))
	if case_model != null and not state.parts_claimed:
		out.append(_action(case_model.global_position + Vector3.UP * .15, "Collect reserved transfer relay", claim_parts, 3))
	return out
func read_log() -> void:
	var directions := "Follow the logging track down to the road and North Ridge Supply."
	if not world.stores.is_empty():
		var d: Vector3 = world.stores[0].global_position - world.fire_lookout.global_position
		var bearing := fposmod(rad_to_deg(atan2(d.x,-d.z)),360)
		directions = "North Ridge Supply is approximately %.0f m away on bearing %.0f° (straight-line). Follow the logging track down to the road; collect the reserved relay case at the store counter." % [Vector2(d.x,d.z).length(),bearing]
	var task: String = ["Inspect the ground transfer cabinet with your insulated service kit.","Collect the reserved transfer relay, return and install it in the cabinet.","Verify the cabinet transfer under local power.","Relay signed off. Local service restored."][state.repair_stage]
	if state.repair_stage==1 and state.parts_claimed:task="Return to the ground cabinet and install the replacement relay."
	var text := "KESTREL RELAY 07 — FIELD ASSIGNMENT\n\nCurrent work\n%s\n\nDepot and access\n%s\n\nCommunications\nField dispatch reaches your always-carried personal walkie-talkie. It is always listening and uses its own supply, independent of the desk receiver and the lookout mains. The desk receiver is public radio only. Bulletins begin at 06:00, 12:00, 17:00 and 00:00; noon recaps the morning. Green indicates receiver power and blue identifies public radio. Public reports are live, not queued: missed bulletins do not return. Dispatch keeps clear of every public slot. A dispatch call wakes you if asleep; public broadcasts do not. Midnight closes the day just lived. The desk receiver and lamp can be switched off separately.\n\nLocal power\nInspect, replace and verify the transfer relay. Commissioning arms automatic battery transfer while the repeater is enabled. Manual backup is available at the desk panel; this supplies the lookout, not the town grid.\n\nOvernight stock\nDeliveries are expected, but the provisions here are finite. Keep water, food and dry firewood ready. Stoke the stove, boil snow, and prepare the sleeping berth before the weather closes in." % [task,directions]
	world.reading.open("North Ridge • Service log",text,world.player,world.hud)
func toggle_receiver() -> void: state.receiver_on = not state.receiver_on; _update_receiver_indicators(); _radio_update()
func toggle_backup() -> void:
	state.backup_on = not state.backup_on; update_presentation(); _radio_update()
	world._say("Local backup %s. Charge %.0f%%. Lamp 7 W, receiver 3 W, commissioned relay 12 W." % ["enabled" if state.backup_on else "disabled", state.battery_wh / LookoutAssignment.BATTERY_CAP_WH * 100])
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
	if state.verify(): world._say("Transfer verified. Local site equipment restored and automatic backup armed. You can disable the repeater to conserve 12 W. Distant grid failures cannot be repaired here.")
	elif state.repair_stage == 2: world._say("No local power. Enable backup at the desk panel, then verify.")
func stoke() -> void:
	if fuel_s >= 16 * 3600: world._say("Stove fuel capacity reached"); return
	if world.inv.count("wood") < 1: world._say("Need firewood"); return
	if fuel_s <= 0 and world.inv.count("matches") < 1: world._say("Need a match to relight the stove"); return
	if fuel_s <= 0: world.inv.remove("matches")
	world.inv.remove("wood"); fuel_s = minf(16 * 3600, fuel_s + 2 * 3600); update_presentation()
func take_wood() -> void:
	if wood_left > 0 and world.inv.can_add("wood"):
		world.inv.add("wood"); wood_left -= 1; _update_stock()
		world.audio.play_at("rustle", pantry.global_position, -6, 1, 3, 18)
func boil() -> void:
	if fuel_s > 0: world.needs.drink(35); world._say("Drank boiled snow (+35 water)")
func cook() -> void:
	if not cooking.is_empty() or fuel_s <= 0: return
	for id: String in world.inv.counts:
		if Inventory.ITEMS[id].get("raw", false) and world.inv.remove(id):
			cooking = {"id": Inventory.ITEMS[id].cooked, "remaining_s": 1200.0}; return
func take_cooked() -> void:
	if cooking.is_empty() or float(cooking.remaining_s) > 0: return
	if world.inv.can_add(String(cooking.id)): world.inv.add(String(cooking.id)); cooking = {}
func heat_at(eye: Vector3) -> float:
	if fuel_s <= 0 or not world.fire_lookout.contains_room(eye): return 0
	var distance: float = eye.distance_to(home_point(Vector3(-1.65,.55,1.20)))
	return (145.0 + 340.0 * pow(maxf(0,1-distance/3),2)) * minf(1,fuel_s/300)
func is_refuge(point: Vector3) -> bool:
	if world.fire_lookout.contains_room(point): return true
	if boundary.gate_open or not boundary.contains_ground(point): return false
	for actor: Node in get_tree().get_nodes_in_group("hostile"):
		if actor is Node3D and not bool(actor.call("is_dead")) and boundary.contains_ground(actor.global_position): return false
	return true
func to_dict() -> Dictionary:
	return {"state":state.to_dict(),"home":{"fuel_s":fuel_s,"wood_left":wood_left,"cooking":cooking.duplicate(true),"storage":pantry.to_dict(),"gate_open":boundary.gate_open}}
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
	stove_smoke=GPUParticles3D.new();tower.add_child(stove_smoke)
	stove_smoke.position=Vector3(-1.65,FireLookout.DECK_Y+4.02,1.20)
	stove_smoke.amount=20;stove_smoke.lifetime=4;stove_smoke.preprocess=1;stove_smoke.visibility_aabb=AABB(Vector3(-10,-2,-10),Vector3(20,15,20))
	var motion:=ParticleProcessMaterial.new();motion.direction=Vector3.UP;motion.spread=12;motion.initial_velocity_min=.35;motion.initial_velocity_max=.65
	motion.scale_min=.18;motion.scale_max=.42
	var ramp:=Gradient.new();ramp.offsets=PackedFloat32Array([0,.12,.65,1]);ramp.colors=PackedColorArray([Color(.42,.45,.47,0),Color(.70,.72,.74,.18),Color(.76,.78,.80,.10),Color(.52,.54,.56,0)])
	var fade:=GradientTexture1D.new();fade.gradient=ramp;motion.color_ramp=fade;stove_smoke.process_material=motion
	var image:=Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var radius:=Vector2((x-31.5)/31.5,(y-31.5)/31.5).length()
			image.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-radius*radius),2)))
	var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(image);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.vertex_color_use_as_albedo=true;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var quad:=QuadMesh.new();quad.size=Vector2(1.6,1.6);quad.material=material
	stove_smoke.draw_pass_1=quad;stove_smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	var beans := maxi(pantry.count("beans"), 0)
	var jerky := maxi(pantry.count("jerky"), 0)
	var other := 0
	for id: String in pantry.contents:
		if id not in ["beans", "jerky"]: other += maxi(pantry.count(id),0)
	var signature := "%d/%d/%d/%d" % [beans,jerky,wood_left,other]
	if signature == _stock_signature: return
	_stock_signature = signature
	for node: Node in _stock.get_children():
		_stock.remove_child(node); node.queue_free()
	var wood_poses: Array[Transform3D] = []
	for i in mini(maxi(wood_left,0),12):
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
	var overflow := maxi(beans-4,0)+maxi(jerky-4,0)+maxi(wood_left-12,0)
	_stock_label.text = "PROVISIONS • %d tins / %d pouches\nFIREWOOD • %d" % [beans,jerky,maxi(wood_left,0)]
	if other>0 or overflow>0: _stock_label.text += "\n%d other items%s" % [other," • extra stock stored" if overflow>0 else ""]
