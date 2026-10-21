extends Node3D
## Playable slice root: terrain + forest + water + sky rig + survival systems + player + HUD.
## Run: Godot --path brave-and-cold res://world/game_world.tscn -- hour=17.5 pos=x,z yaw= pitch= out=file.png
## Args: hour, pos, yaw, pitch, out (screenshot then quit), trees=0, walk=N (auto-walk N s, print stats, quit), speed= (time_scale)

const MAP := "res://data/terrain/valley_b"

var terrain: Terrain3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sky_rig: SkyRig
var clock := GameClock.new()
var weather := Weather.new()
var snowfall: SnowFall
var weather_presentation: Node3D
var road: RoadNet
var huts: Array = []
var trailnet: TrailNet
var colliders: Array = []
var hut_sites: Array = []
var ice: IceField
var ice_holes: Array = []
var body := BodyTemperature.new()
var snow := SnowField.new()
var noise_bus := NoiseBus.new()
var player: Player
var hud: Hud
var lens_flare: LensFlare
var reading: ReadingModal
var forest: ForestScatter
var plants: PlantField
var footprints: Footprints
var cabins: Array[Cabin] = []
var fire_lookout: FireLookout # Standalone additive mountain structure; never a ground cabin collider.
var opening: LookoutOpening
var route_dressing:RouteDressing
var first_week:FirstWeekRoute
var collapse:FirstWeekCollapse
var town_life:TownLife
var clinic_plan:Dictionary={}
var opening_state: LookoutAssignment
var opening_zombie_count := 250
var interaction_count := 0 # completed/instant player interactions (pacing log)
var pacing: PacingLog
var out_path := ""
var walk_secs := 0.0
var _t := 0.0
var _frames := 0
var wind := 3.0
var _walk_started := false
var _ft: Array[float] = []
var route_detail_enabled := false
var environment_detail_enabled := false


## M5 staged loading: report a stage to the menu's LoadingOverlay and give the main loop one
## frame to draw it. Without an overlay (headless tests, tools) this neither waits nor
## changes frame timing. Never called after the HUD exists: _process runs once hud != null.
var _load_t0 := 0
var built := false   # _ready finished (with the overlay, _ready yields; `hud` exists before this)
func _stage(f: float, text: String) -> void:
	if _load_t0 == 0: _load_t0 = Time.get_ticks_msec()
	print("LOAD_STAGE %.2f %s %d ms" % [f, text, Time.get_ticks_msec() - _load_t0])
	if LoadingOverlay.current == null: return
	LoadingOverlay.report(f, text)
	await _yield_frame()


## One drawn frame for the overlay with the whole world held still: wolves, zombies,
## terrain, the HUD and this node's own _process skip it, so a yield in the middle of
## setup can never let a half-built world act (or take input).
func _yield_frame() -> void:
	var pm := process_mode
	process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	process_mode = pm


## Maps a sub-build's local 0..1 onto [a, b] of the overall bar (same stage label).
## Returns an empty Callable without an overlay, so builders run straight through.
func _sub_progress(a: float, b: float, text: String) -> Callable:
	if LoadingOverlay.current == null: return Callable()
	return func(f: float) -> void:
		LoadingOverlay.report(lerpf(a, b, clampf(f, 0.0, 1.0)), text)
		await _yield_frame()


func _ready() -> void:
	Settings.load_all()
	var opts := _args()
	environment_detail_enabled = opts.get("detail","winter") != "baseline" and opts.get("atmosphere","winter") != "baseline"
	await _stage(0.02, "Raising the valley")
	_build_environment()
	var terrain_assets := "res://data/terrain/terrain_assets.tres"
	if opts.get('atmosphere', 'winter') != 'baseline':
		terrain_assets = 'res://data/terrain/terrain_environment_assets.tres' if environment_detail_enabled else 'res://data/terrain/terrain_winter_assets.tres'
	terrain = WorldEnvironmentBuilder.terrain(self, MAP, terrain_assets)
	# Staged loading yields frames before the player camera exists; Terrain3D would log
	# "Cannot find the active camera" and stop its physics process. Hold it until setup.
	terrain.set_physics_process(false)
	await _stage(0.09, "Laying the roads")
	road = RoadNet.new()
	road.grading_enabled = opts.get("road_grade","smooth") != "baseline"
	route_detail_enabled=environment_detail_enabled and opts.get("route_detail","winter")!="baseline"
	road.detail_enabled = environment_detail_enabled and opts.get("road_detail", "winter") != "baseline"
	add_child(road)
	trailnet = TrailNet.new()
	add_child(trailnet)
	if opts.get('road', '1') == '1':
		road.plan()
	ice = IceField.new()
	ice.load_map()
	if road.points.size() > 40 and opts.get('huts', '1') == '1':
		var wimg := MapIO.load_png('res://data/maps/valley_b/water_mask.png')
		wimg.convert(Image.FORMAT_L8)
		hut_sites = Hut.find_sites(terrain, road, wimg, int(opts.get('hutn', 5)))
		if opts.get('icecamp', '1') == '1':
			hut_sites.append_array(_plan_ice_camps())
		print('HUT_SITES ', hut_sites.size(), ' ', hut_sites)
		if opts.get('hamlet', '1') == '1':
			_plan_hamlet(wimg)
		if opts.get('store', '1') == '1':
			_plan_store(wimg)
			if opts.get("clinic","1")=="1":clinic_plan=FirstWeekCollapse.plan(self,wimg)
		for hs in hut_sites:
			var hp := Vector2(float(hs['x']), float(hs['z']))
			var hyaw := deg_to_rad(float(hs['yaw']))
			trailnet.add_trail(_road_edge_toward(hp), hp + Vector2(sin(hyaw), cos(hyaw)) * 1.8, 11)
	await _stage(0.17, "Growing the timber")
	if opts.get("trees", "1") == "1":
		forest = ForestScatter.new()
		forest.detail_enabled = environment_detail_enabled
		forest.diversity_enabled = opts.get("forest_diversity", "winter") != "baseline"
		forest.crown_quality_enabled = opts.get("forest_crowns", "winter") != "baseline"
		forest.weather = weather
		add_child(forest)
		forest.exclude = func(x: float, z: float) -> bool:
			for hs in hut_sites:
				if absf(x - float(hs['x'])) < 7.0 and absf(z - float(hs['z'])) < 7.0:
					return true
			for hp2 in hamlet_plan:
				if absf(x - float(hp2['x'])) < 8.0 and absf(z - float(hp2['z'])) < 8.0:
					return true
			if not store_plan.is_empty() and absf(x - float(store_plan['x'])) < 8.0 and absf(z - float(store_plan['z'])) < 8.0:
				return true
			for he2 in hamlet_extra:
				if absf(x - float(he2['x'])) < 5.0 and absf(z - float(he2['z'])) < 5.0:
					return true
			return road.is_near(x, z) or trailnet.is_near(x, z)
		forest.progress = _sub_progress(0.17, 0.41, "Growing the timber")
		await forest.build(terrain)
		forest.progress = Callable()
		if opts.get('plants', '1') == '1':
			await _stage(0.41, "Scattering brush")
			plants = PlantField.new()
			add_child(plants)
			plants.progress = _sub_progress(0.41, 0.48, "Scattering brush")
			await plants.build(terrain, forest.exclude)
			plants.progress = Callable()
	await _stage(0.48, "Freezing the lakes")
	ice.activate_shoreline()
	if plants != null: print("PLANTS under ice suppressed=", plants.suppress_under_ice(ice))
	await _stage(0.49, "Ploughing the roads")
	road.build_mesh(terrain)
	road.build_props(terrain)
	await _stage(0.52, "Icing the rivers")
	var w := WaterSurfaces.new()
	add_child(w)
	w.progress = _sub_progress(0.52, 0.66, "Icing the rivers")
	await w.build("res://data/maps/valley_b", ice)
	w.progress = Callable()
	if opts.get('atmosphere', 'winter') != 'baseline':
		var ice_material := w.surface.material_override as ShaderMaterial
		ice_material.set_shader_parameter('winter_surface', true)
		ice_material.set_shader_parameter('detail_surface', environment_detail_enabled)
		if environment_detail_enabled:
			ice_material.set_shader_parameter('ice_fields', preload('res://assets/environment_detail/textures/ice_fields.png'))
		ice_material.set_shader_parameter('surface_noise', preload('res://assets/textures/atmosphere/cloud_fields.png'))
	await _stage(0.66, "Drifting the snow")
	snow.build("res://data/maps/valley_b")
	await _stage(0.74, "Lighting the sky")
	clock.hour = float(opts.get("hour", 16.5))
	sky_rig = SkyRig.new() if opts.get("atmosphere", "winter") == "baseline" else preload("res://world/atmosphere_rig.gd").new()
	add_child(sky_rig)
	sky_rig.setup(sun, env, sky_mat)
	if sky_rig is AtmosphereRig:
		(sky_rig as AtmosphereRig).material.set_shader_parameter("cloud_quality",opts.get("sky_clouds","winter")!="baseline")
	sky_rig.weather = weather
	if opts.has('weather'):
		var wi := ['clear', 'cloudy', 'flurry', 'snow', 'blizzard'].find(String(opts['weather']).to_lower())
		if wi >= 0:
			weather.lock_state(wi)
	if not sky_rig is AtmosphereRig:
		sky_rig.clouds = CloudLayer.new()
		add_child(sky_rig.clouds)
	sky_rig.apply_hour(clock.hour)
	player = Player.new()
	add_child(player)
	player.setup(terrain, snow, body, noise_bus)
	terrain.set_physics_process(true)
	snowfall = SnowFall.new()
	add_child(snowfall)
	snowfall.follow = player
	snowfall.weather = weather
	snowfall.buildings = Callable(self, "_building_list")
	if sky_rig is AtmosphereRig:
		snowfall.enable_winter_presentation()
		if environment_detail_enabled:
			snowfall.enable_detail_layers()
			weather_presentation = preload("res://world/weather_presentation.gd").new()
			weather_presentation.world = self
			add_child(weather_presentation)
	player.forest = forest
	player.ice = ice
	player.walk_ribbons.assign([road,trailnet])
	if sky_rig.clouds != null:
		sky_rig.clouds.follow = player
	sky_rig.apply_hour(clock.hour)
	footprints = Footprints.new()
	footprints.detail_enabled = environment_detail_enabled
	add_child(footprints)
	player.footprints = footprints
	viewmodel = Viewmodel.new()
	viewmodel.player = player
	viewmodel.game_clock=clock
	player.needs=needs
	viewmodel.detail_enabled = environment_detail_enabled
	player.cam.add_child(viewmodel)
	await get_tree().process_frame
	await get_tree().process_frame
	var home := _find_spawn()
	var sp := home if not opts.has("pos") else Vector2(float(String(opts["pos"]).split(",")[0]), float(String(opts["pos"]).split(",")[1]))
	if opts.has('roadpos') and road.points.size() > 2:
		var ri := clampi(int(opts['roadpos']), 0, road.points.size() - 2)
		var rp: Vector2 = road.points[ri]
		var rq: Vector2 = road.points[ri + 1]
		sp = rp
		print('ROADPOS ', ri, ' ', rp, ' first ', road.points[0], ' last ', road.points[road.points.size() - 1])
		opts['yaw'] = str(rad_to_deg(atan2(-(rq.x - rp.x), -(rq.y - rp.y))))
	var sv: Dictionary = SaveGame.pending
	SaveGame.pending = {}
	var loading := not sv.is_empty()
	opening_state = LookoutAssignment.new()
	opening_state.enabled = opts.get("lookout","1") != "0" and opts.get("opening","assignment") != "survival" and (not loading or sv.has("opening"))
	if loading and sv.has("opening"): opening_state.restore(sv.opening.get("state",{}))
	elif opening_state.enabled: opening_state.new_run(int(opts.get("opening_seed",Time.get_unix_time_from_system())))
	var baseline_pace: bool = opts.get("opening_pace", "winter") == "baseline"
	if loading:
		clock.restore(sv.get("clock", {}))
	else:
		clock.set_pace(GameClock.OPENING_TIME_SCALE if opening_state.enabled and not baseline_pace else GameClock.LEGACY_TIME_SCALE)
	if opts.has("speed"):
		var requested_rate: float = float(opts.speed)
		if requested_rate > 0.0: clock.set_pace(requested_rate)
		else: clock.time_scale = 0.0
	opening_state.audio_clock_rate = clock.base_time_scale
	opening_zombie_count = int(opts.get("zombies",250))
	if opening_state.enabled and not loading and not opts.has("hour"): clock.hour = LookoutAssignment.START_HOUR
	if not loading: opening_state.align_calendar(clock.day,clock.hour,clock.total_game_s,true)
	if loading:
		sp = Vector2(float(sv['player']['x']), float(sv['player']['z']))
	player.place(sp.x, sp.y)
	await _stage(0.81, "Building the hamlet")
	_place_cabin(home)
	_build_hamlet(home)
	_build_store()
	_build_huts()
	_build_ice_holes()
	if not loading and (not instant_bullets or opts.has('rifles')): _place_rifle_caches()
	_build_fire_lookout(opts)
	if plants != null:
		for cb in cabins:
			plants.suppress_near(cb.global_position.x, cb.global_position.z, 9.0)
		for hu in huts:
			plants.suppress_near(hu.global_position.x, hu.global_position.z, 7.0)
	await _stage(0.86, "Waking the dead")
	pop = Population.new()
	add_child(pop)
	pop.terrain = terrain
	pop.player = player
	pop.world_list = zombies
	pop.bus = noise_bus
	pop.make_zombie = Callable(self, "_new_zombie")
	if opening_state.enabled:pop.reserve_target=Population.T0_CAP
	noise_bus.noise.connect(pop.on_noise)
	noise_bus.light.connect(pop.on_light)
	if opts.has("wound"):
		player.injury.wound(float(opts["wound"]), 0.0)
	if road != null:
		pop.road_pts = road.points
	if not opts.has("wolftest") and not opts.has("zombietest") and not opts.has("deertest"):
		if loading:
			_restore_creatures(sv)
		else:
			_spawn_wolves(int(opts.get("wolves", 3)), home, 70.0, 140.0)
			_spawn_bears(int(opts.get("bears", 2)), home, 150.0, 320.0)
		if not loading:
			if not opening_state.enabled: _populate(int(opts.get("zombies", 700)), home)
			if opts.has("horde"):   # dev: a horde of N, hordedist m ahead (default 180)
				var hf := Vector2(-sin(deg_to_rad(float(opts.get('yaw', 0.0)))), -cos(deg_to_rad(float(opts.get('yaw', 0.0)))))
				pop.spawn_horde(Vector2(player.position.x, player.position.z) + hf * float(opts.get('hordedist', 180.0)), int(opts['horde']))
			if opts.has("popview"):   # screenshot helper: stand ~dist m west of the densest clump, looking east
				var bk := -1
				var bn := 0
				for k in pop.cells:
					var n: int = (pop.cells[k] as PackedVector3Array).size()
					if n > bn:
						bn = n
						bk = int(k)
				var cxx := float(bk / 64) * Population.CELL - Population.HALF + Population.CELL * 0.5
				var czz := float(bk % 64) * Population.CELL - Population.HALF + Population.CELL * 0.5
				player.place(cxx - float(opts["popview"]), czz)
				opts["yaw"] = "-90"
				opts["pitch"] = "-2"
			if opening_state.enabled and fire_lookout != null:
				_spawn_route_deer(int(opts.get("deer",6)))
			else:
				_spawn_deer(int(opts.get("deer", 6)), home)
	player.cabins = colliders
	if opts.has('hutpos') and not huts.is_empty():
		var hu0: Hut = huts[clampi(int(opts['hutpos']), 0, huts.size() - 1)]
		var hwp: Vector3 = hu0.to_global(Vector3(float(opts.get('hutx', 0.0)), 0.0, float(opts.get('hutd', 6.0))))
		player.place(hwp.x, hwp.z)
		var hdir: Vector3 = hu0.global_position - hwp
		opts['yaw'] = rad_to_deg(atan2(-hdir.x, -hdir.z))
		opts['pitch'] = -4.0
	if opts.has('icepos'):
		for ih in huts:
			if ih.on_ice:
				var iwp: Vector3 = ih.to_global(Vector3(float(opts.get('icex', 1.0)), 0.0, float(opts.get('iced', 8.0))))
				player.place(iwp.x, iwp.z)
				var idir: Vector3 = ih.global_position - iwp
				opts['yaw'] = rad_to_deg(atan2(-idir.x, -idir.z))
				opts['pitch'] = float(opts.get('icepitch', -6.0))
				break
	if opts.has('storepos') and not stores.is_empty():
		var sp0: Store = stores[0]
		var swp: Vector3 = sp0.to_global(Vector3(float(opts.get('storex', 0.0)), 0.0, float(opts.get('stored', 9.0))))
		player.place(swp.x, swp.z)
		var sdir: Vector3 = sp0.global_position - swp
		opts['yaw'] = rad_to_deg(atan2(-sdir.x, -sdir.z))
		opts['pitch'] = float(opts.get('storepitch', -4.0))
	if opts.has('outpos') and not outbuildings.is_empty():
		var ob0: Outbuilding = outbuildings[clampi(int(opts['outpos']), 0, outbuildings.size() - 1)]
		var owp: Vector3 = ob0.to_global(Vector3(float(opts.get('outx', 1.5)), 0.0, float(opts.get('outd', 6.0))))
		player.place(owp.x, owp.z)
		var odir: Vector3 = ob0.global_position - owp
		opts['yaw'] = rad_to_deg(atan2(-odir.x, -odir.z))
		opts['pitch'] = -4.0
	if opts.has('hamletpos') and hamlet_n > 0:
		var hedge := _road_edge_toward(hamlet_center)
		var hv := (hamlet_center - hedge)
		var hstart := hamlet_center - hv.normalized() * float(opts.get('hamletd', 40.0))
		player.place(hstart.x, hstart.y)
		opts['yaw'] = rad_to_deg(atan2(-hv.x, -hv.y))
		opts['pitch'] = -3.0
	if not cabins.is_empty():
		if opts.has("stove"):
			cabins[0].add_wood()
		if opts.has("dooropen"):
			cabins[0].toggle_door()
		if opts.has("win"):  # screenshot helper: "0b2,1c,2k" = window 0 two boards, 1 curtain, 2 smashed
			for tok in String(opts["win"]).split(","):
				var wop: Opening = cabins[0].openings[int(tok.substr(0, 1))]
				if "b" in tok:
					for bi in int(tok.substr(tok.find("b") + 1, 1)):
						wop.add_board()
				if "c" in tok:
					wop.hang_curtain()
				if "k" in tok:
					wop.hit(99.0)
		if opts.has("cabinpos"):
			var lp := String(opts["cabinpos"]).split(",")
			var wp: Vector3 = cabins[0].to_global(Vector3(float(lp[0]), 0.0, float(lp[1])))
			player.place(wp.x, wp.z)
			var st: Vector3 = cabins[0].stove_world_pos()
			player.yaw = atan2(-(st.x - wp.x), -(st.z - wp.z))
			player.pitch = deg_to_rad(-12.0)
			if opts.has("cabinyaw"):
				player.yaw = cabins[0].rotation.y + deg_to_rad(float(opts["cabinyaw"]))
				player.pitch = deg_to_rad(float(opts.get("cabinpitch", -3.0)))
	snow.interior_check = func(x: float, z: float) -> bool:
		for cb in colliders:
			if cb.contains_xz(x, z):
				return true
		return false
	if not opts.has("cabinpos"):
		player.yaw = deg_to_rad(float(opts.get("yaw", 0.0)))
		player.pitch = deg_to_rad(float(opts.get("pitch", -3.0)))
	if opts.has("trail"):
		_lay_trail(int(opts["trail"]))
	if loading:
		_apply_save(sv, opts)
	await _stage(0.93, "Settling in")
	hud = Hud.new()
	add_child(hud)
	hud.setup(player, body, snow, clock)
	if not opts.has('nohud'):
		lens_flare = LensFlare.new(); lens_flare.world = self; add_child(lens_flare)
	hud.weather = weather
	hud.visible = not opts.has('nohud')
	gear = GearScreen.new()
	add_child(gear)
	_loot = opts.has('loot')
	_gear_opt = opts.has('gear')
	_craftui = opts.has('craftui')
	_wearui = opts.has('wearui')
	_gear_sel = String(opts.get('gearsel', ''))
	_geartest = opts.has('geartest')
	opts_dropdemo = opts.has('dropdemo')
	audio = GameAudio.new()
	add_child(audio)
	audio.detail_enabled = environment_detail_enabled
	audio.setup(player, self, wind)
	if viewmodel != null: viewmodel.mech.connect(audio.mech)   # bolt / lever foley
	audio.weather = weather
	await _stage(0.95, "Opening the lookout")
	if opening_state.enabled and fire_lookout != null:
		opening = LookoutOpening.new(); add_child(opening)
		opening.build(self,opening_state,sv.get("opening",{}).get("home",{}))
		# Playtest pacing CSV (user://pacing/), real play only: not headless tests or autostart runs.
		if DisplayServer.get_name() != "headless" and not opts.has("autostart"):
			pacing = PacingLog.new(); add_child(pacing); pacing.start(self)
		first_week=FirstWeekRoute.new();add_child(first_week);first_week.build(self,sv.get("first_week",{}))
		if route_detail_enabled:
			route_dressing=RouteDressing.new();add_child(route_dressing);route_dressing.build(self);player.spatial_structures.append(route_dressing)
		opening.electrical=ElectricalFieldwork.new();opening.add_child(opening.electrical)
		opening.electrical.build(self,sv.get("opening",{}).get("home",{}).get("electrical",{}))
		opening_state.field_load_w=0 if first_week.feeder_isolated else 6
		if not loading:
			opening.starting_gear(baseline_pace)
			var camera_override := false
			for option: String in ["pos","roadpos","hutpos","icepos","storepos","outpos","hamletpos","cabinpos","lookoutpos"]:
				if opts.has(option): camera_override = true
			if not camera_override:
				player.position = fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+player.eye_h,.3))
				player.yaw = fire_lookout.rotation.y; player.pitch = -.08
	await _stage(0.97, "Waking the town")
	reading=ReadingModal.new();add_child(reading)
	collapse=FirstWeekCollapse.new();add_child(collapse);collapse.build(self,clinic_plan,sv.get("collapse",{}))
	if opening_state.enabled and opts.get("town_life","1")!="0":
		town_life=TownLife.new();add_child(town_life);town_life.build(self,sv.get("town_life",{}),loading and not sv.has("town_life"))
	_build_rooms(sv.get("rooms", []))
	_build_forage(sv.get("forage", []))
	_build_warrens()
	for sd: Variant in sv.get("snares", []):
		if sd is Dictionary: _add_snare(Vector3(float(sd.x), float(sd.y), float(sd.z)), float(sd.yaw), sd)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	dev = DevMenu.new()
	add_child(dev)
	dev.setup(self)
	if opts.has('devmenu'):
		dev.open()
	pause_menu.save_requested.connect(func() -> void: pause_menu.save_status(save_game()))
	out_path = String(opts.get("out", ""))
	_selftest = opts.has("selftest")
	_wolftest = opts.has("wolftest")
	_beartest = opts.has("bear")
	_mash = opts.has("mash")
	_flareopt = opts.has("flare")
	_zombietest = opts.has("zombietest")
	_deertest = opts.has("deertest")
	_vmtest = String(opts.get('vmtest', ''))
	_opts_vmact = String(opts.get('vmact', ''))
	viewmodel.visible = not opts.has('nohud') or _vmtest != ''
	if opts.has('vmt'):
		viewmodel.freeze_t = float(opts.get('vmt', 0.0))
	_campfire_opt = opts.has("campfire")
	_savetest = String(opts.get('savetest', ''))
	opts_pausetest = opts.has('pausetest')
	pause_shot = String(opts.get('pausetest', ''))
	_force_death = opts.has("dead")
	wolf_test_dist = float(opts.get("wdist", 22.0))
	walk_secs = float(opts.get("walk", 0.0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (out_path == "" and walk_secs == 0.0) else Input.MOUSE_MODE_VISIBLE
	# Gear must be ready for Tab before the first gameplay process frame.
	_ensure_gear()
	print("LOAD_STAGE 1.00 ready %d ms" % (Time.get_ticks_msec() - _load_t0))
	built = true
	LoadingOverlay.report(1.0, "")


func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			d[kv[0]] = kv[1]
	return d


## Added only after the existing map has finished placing roads, trees and buildings.
## The optional camera helpers do not change the default spawn.
func _build_fire_lookout(opts: Dictionary) -> void:
	if String(opts.get('lookout', '1')) == '0':
		return
	if not FileAccess.file_exists(FireLookout.SITE_PATH):
		push_warning('Fire lookout site has not been generated yet')
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FireLookout.SITE_PATH))
	if not parsed is Dictionary:
		push_error('Fire lookout site data is invalid')
		return
	fire_lookout = FireLookout.new()
	fire_lookout.detail_enabled = environment_detail_enabled
	fire_lookout.route_dressing_enabled = route_detail_enabled
	add_child(fire_lookout)
	fire_lookout.build(parsed)
	var stair_base := fire_lookout.to_global(Vector3(4.45, 0.0, 1.8))
	var stair_ground: float = terrain.data.get_height(stair_base)
	if not is_nan(stair_ground):
		# Imported terrain sampling takes priority over raster quantization. Only
		# the new structure moves; existing terrain and map contents remain intact.
		fire_lookout.position.y = stair_ground + 0.03
	fire_lookout.build_foundations(terrain)
	fire_lookout.build_access_path(terrain)
	if fire_lookout.access_ribbon!=null:player.walk_ribbons.append(fire_lookout.access_ribbon)
	player.spatial_structures.append(fire_lookout)
	fire_lookout.event.connect(_on_opening_event)
	if route_detail_enabled:
		var path:Array=parsed.get("route",[])
		if path.size()>1:
			var a:Array=path[0];var b:Array=path[1]
			var direction:=Vector2(float(b[0])-float(a[0]),float(b[1])-float(a[1])).normalized()
			var point:=Vector2(float(a[0]),float(a[1]))+Vector2(-direction.y,direction.x)*3.5+direction*12
			var sign:Node3D=(load("res://assets/route_detail/lookout_wayfinding.glb") as PackedScene).instantiate()
			sign.name="LookoutServiceWayfinding"
			sign.position=Vector3(point.x,terrain.data.get_height(Vector3(point.x,0,point.y)),point.y);sign.rotation.y=atan2(-direction.x,-direction.y);add_child(sign)
			for mesh:MeshInstance3D in sign.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=180
	print('FIRE_LOOKOUT at ', fire_lookout.position, ' yaw=', fire_lookout.rotation_degrees.y)
	if opts.has('lookoutpos'):
		var mode := String(opts['lookoutpos'])
		if mode == 'deck' or mode == 'room':
			var local := Vector3(0.0, FireLookout.DECK_Y, 2.75 if mode == 'deck' else 0.0)
			player.position = fire_lookout.to_global(local) + Vector3.UP * player.eye_h
			player._ready_ground = true
			player._last_pos = player.position
			opts['yaw'] = str(fire_lookout.rotation_degrees.y + (0.0 if mode == 'deck' else 180.0))
			opts['pitch'] = '0'
		else:
			var point := fire_lookout.approach_point(float(opts.get('lookoutdist', 17.0)))
			player.place(point.x, point.z)
			var target := fire_lookout.to_global(Vector3(0.0, FireLookout.DECK_Y * 0.7, 0.0))
			var direction := target - Vector3(point.x, fire_lookout.position.y + player.eye_h, point.z)
			opts['yaw'] = str(rad_to_deg(atan2(-direction.x, -direction.z)))
			opts['pitch'] = str(rad_to_deg(atan2(direction.y, Vector2(direction.x, direction.z).length())))


func _build_environment() -> void:
	# shared with the menu diorama (world/world_environment_builder.gd)
	var e := WorldEnvironmentBuilder.build(self)
	sun = e.sun; sky_mat = e.sky_mat; env = e.env


var _indoor_k := 0.0            # 0 outside .. 1 inside a cabin (smoothed)
const INDOOR_FOG_MULT := 0.12
const INDOOR_AMBIENT_MULT := 1.6


## Frame-budget accounting for profile_frame_budget.gd (off in play): ms per labelled section.
var prof_on := false
var prof: Dictionary = {}
var _prof_t := 0
func _pm(label: String) -> void:
	var now := Time.get_ticks_usec()
	prof[label] = float(prof.get(label, 0.0)) + (now - _prof_t) / 1000.0
	_prof_t = now

func _process(delta: float) -> void:
	if hud == null:
		return
	if prof_on: _prof_t = Time.get_ticks_usec()
	_frames += 1
	_update_viewmodel()
	_update_optic(delta)
	if prof_on: _pm('viewmodel')
	_t += delta
	if _sl_on:
		_sleep_update(delta)
	# time / lighting
	var clock_delta := delta
	if opening != null and _sl_on and int(_sl.get("phase",0))==1 and clock.time_scale>0:
		var call_at: float=opening.next_dispatch_wake(clock.total_game_s,clock.total_game_s+delta*clock.time_scale)
		if is_finite(call_at): clock_delta=(call_at-clock.total_game_s)/clock.time_scale
	var gs := clock.advance(clock_delta)
	for cabin:Cabin in cabins:cabin.advance(gs)
	for sb: Node in _stove_buildings(): (sb.get("stove") as Stove).advance(gs)
	_advance_rooms(gs)
	if hud != null:
		var here := room_at(player.position)
		hud.indoor_c = here.room_c if here != null else NAN
	for carcass:Node3D in get_tree().get_nodes_in_group("carcasses"):Carcass.advance_food(carcass,gs)
	if opening != null: opening.advance(gs)
	if first_week!=null:first_week.update(gs)
	if collapse!=null:collapse.update(gs)
	if town_life!=null:town_life.update(gs)
	if prof_on: _pm('story_route')
	if inv != null:
		for sn in inv.tick(gs, Spoilage.rate_c(air_c())):
			_say("%s spoiled" % sn)
	for food:ItemPickup in get_tree().get_nodes_in_group("perishable_pickups"):food.tick(gs, Spoilage.rate_c(air_at(food.global_position)))
	if prof_on: _pm('food_tick')
	weather.advance(delta, gs)
	wind = weather.wind
	road.update_weather(weather.precip,gs)
	if fire_lookout!=null and fire_lookout.access_material!=null:fire_lookout.access_material.set_shader_parameter("fresh_snow",road.snow_cover)
	if trailnet.path_material!=null:trailnet.path_material.set_shader_parameter("fresh_snow",road.snow_cover)
	clock.weather_offset_c = weather.temp_off
	sky_rig.apply_hour(clock.hour)
	if sky_rig is AtmosphereRig:
		snowfall.set_light_tint((sky_rig as AtmosphereRig).snow_tint())
	# inside a cabin the world fog (blizzard haze, aerial perspective) must not veil the room: fade it right down, ease in/out at the door
	var in_cabin := false
	for cb in cabins:
		if cb.contains_xz(player.position.x, player.position.z):
			in_cabin = true
			break
	if fire_lookout != null and fire_lookout.contains_room(player.position):
		in_cabin = true
	if not in_cabin:   # fishing huts and the general store are interiors too: no blizzard haze inside
		for hb in huts + stores:
			if hb.contains_xz(player.position.x, player.position.z):
				in_cabin = true
				break
	if collapse!=null and collapse.clinic!=null and collapse.clinic.contains_xz(player.position.x,player.position.z):in_cabin=true
	_indoor_k = move_toward(_indoor_k, 1.0 if in_cabin else 0.0, delta * 2.0)
	if sky_rig is AtmosphereRig:
		(sky_rig as AtmosphereRig).apply_shelter(_indoor_k)
	elif _indoor_k > 0.0:
		env.fog_density *= lerpf(1.0, INDOOR_FOG_MULT, _indoor_k)
		# a cold dark cabin must still read: lift ambient and warm it a touch (stove / window light adds on top)
		env.ambient_light_energy *= lerpf(1.0, INDOOR_AMBIENT_MULT, _indoor_k)
		env.ambient_light_color = env.ambient_light_color.lerp(Color(0.62, 0.50, 0.42), 0.3 * _indoor_k)
	var night := sky_rig.gameplay_night_factor
	Zombie.night_factor = night
	Zombie.ambient_c = clock.ambient_c()
	if prof_on: _pm('weather_sky')
	pop.tick(delta)
	if prof_on: _pm('pop_tick')
	_attack_cd = maxf(0.0, _attack_cd - delta)
	Carcass.wind_dir = weather.wind_dir
	_craft_update(delta)
	_reload_update(delta)
	if Engine.get_process_frames() % 90 == 0:
		_hole_upkeep()
	if plants != null and Engine.get_process_frames() % 120 == 0:
		plants.update_regrow(clock.total_game_s)
	_autosave_t += delta
	if _autosave_t > 120.0 and out_path == '' and walk_secs == 0.0 and not _selftest and not _wolftest and not _zombietest and not _deertest:
		_autosave_t = 0.0
		if _safe_to_save() and save_game():
			_say('Autosaved')
	for cb in cabins:
		cb.set_night(night)
	if fire_lookout != null:
		fire_lookout.set_night(night, opening != null and opening.fire.is_lit(), player.cam.global_position)
	if Engine.get_process_frames() % 6 == 0:
		for il: Node in get_tree().get_nodes_in_group("interior_lighting"):
			(il as InteriorLighting).update(1.0 - night, weather.overcast, weather.precip)
		for cbs in cabins:
			FireVisual.set_smoke(cbs.smoke, cbs.fire, weather.wind_dir)
		for cfs in campfires:
			FireVisual.set_smoke(cfs.smoke, cfs.fire, weather.wind_dir)
		for sb: Node in _stove_buildings():
			FireVisual.set_smoke((sb.get("stove") as Stove).smoke, (sb.get("stove") as Stove).fire, weather.wind_dir)
	_fire_cue_t += delta
	if _fire_cue_t > 2.0:
		_fire_cue_t = 0.0
		for cf in campfires:
			cf.fire.cue(noise_bus, cf.global_position, night, 1.0, cf)
		for sb: Node in _stove_buildings():
			(sb.get("stove") as Stove).fire.cue(noise_bus, (sb as Node3D).global_position, night, 0.6 * float(sb.call("noise_leak")), sb)
		if opening != null:
			opening.fire.cue(noise_bus, opening.chimney_world(), night, LookoutOpening.LIGHT_LEAK, opening)
	for stn in stores:
		stn.set_night(night)
	if prof_on: _pm('misc')
	# survival
	snow.advance(delta)
	if prof_on: _pm('snow')
	var fw := player.fire_w
	for cb in cabins:
		fw = maxf(fw, cb.heat_at(player.position.x, player.position.z))
	if opening != null: fw = maxf(fw,opening.heat_at(player.position))
	for cf in campfires:
		cf.advance(gs, 2.0 if weather.precip > 0.2 else 1.0)
		fw = maxf(fw, cf.heat_at(player.position.x, player.position.z))
	body.metabolism_mult = needs.metabolism_mult()
	body.update(gs, air_c(), wind, player.is_sheltered(), fw, player.activity, 0.0 if player.is_sheltered() else weather.precip * 0.05, false)
	needs.resting=_sl_on and int(_sl.get("phase",0))==1
	needs.rest_quality=_sleep_quality() if needs.resting else 1.0
	needs.update(gs, player.activity, body.core)
	if inv != null: inv.wear_clothing(gs,player.activity,weather.precip)   # survival mode has no pack until first pickup
	if prof_on: _pm('survival')
	_act_update(delta, Input.is_key_pressed(KEY_E))
	Inventory.infinite = player.god
	for chx in chests:
		var cc: StorageChest = chx
		cc.want_open = gear != null and gear.is_open and gear._chest == cc and gear._tab == "chest"
		cc.spoilage_rate = Spoilage.rate_c(air_at(cc.global_position))  # snow-cold box or heated room
		cc.tick(gs)
	_hold_attack()
	_bullets_update(delta)
	player.injury.update(gs, delta)
	_advance_small_game(gs)
	# N6 frostbite: head / hands / feet against the wind-chilled air; warm = heated room, fire or mild air
	var fb_before := frostbite.count()
	var fb_warm := fw > 80.0 or (room_at(player.position) != null and air_c() > 0.0) or body.feels_like > -5.0
	for fm: String in frostbite.advance(gs, body.feels_like, fb_warm, inv, body.wetness):
		_say(fm)
	if frostbite.count() > fb_before and not player.dead:
		player.hurt(Frostbite.CAP_LOSS * (frostbite.count() - fb_before), "Frostbite")
	player.health = minf(player.health, frostbite.max_condition())
	var sd := needs.damage_per_s()
	if sd > 0.0 and not player.dead:
		player.hurt(sd * delta, 'Died of thirst' if needs.water <= 0.0 else 'Starved to death')
	if body.core <= BodyTemperature.FATAL:
		player.hurt(9999.0, "Froze to death")
	# One recovery pass after needs and damage, using actual clock advancement.
	var recovering_sleep:bool=_sl_on and int(_sl.get("phase",0))==1
	player.injury.recover(gs,needs,body.core,Injury.REST_RECOVERY_MULT*_sleep_quality() if recovering_sleep else 1.0)
	if prof_on: _pm('actions')
	# The candidate scan is ~1.1 ms; at 30 Hz the prompt is still immediate to the eye.
	if _frames % 2 == 0 or not _act.is_empty():
		_update_prompt()
	if prof_on: _pm('prompt')
	if out_path != "" and _frames == 40:
		get_viewport().get_texture().get_image().save_png(out_path)
		print("SHOT_SAVED ", out_path, " hour=", clock.hour, " pos=", player.position, " yaw=", player.yaw, " proxies=", pop.proxy_n, " active=", pop.active.size(), " hordes=", pop.hordes.size())
		get_tree().quit()
	if _force_death and _frames == 35:
		player.hurt(999.0, "Mauled by a wolf")
	if _zombietest and _frames > 30:
		_zombietest_step(delta)
	if opts_pausetest and _frames == 40:
		opts_pausetest = false
		_act_cancel()
		pause_menu.open()
		print('PT paused=', get_tree().paused)
		await get_tree().create_timer(0.6, true).timeout
		get_viewport().get_texture().get_image().save_png(pause_shot)
		var f0 := _frames
		pause_menu.resume()
		await get_tree().create_timer(0.5).timeout
		print('PT resumed paused=', get_tree().paused, ' frames advanced=', _frames > f0, ' mouse=', Input.mouse_mode)
		get_tree().quit()
	if _savetest != '' and _frames == 40:
		if _savetest == 'save':
			inv = Inventory.new(body)
			inv.needs = needs
			inv.add('wood', 3)
			inv.add('matches', 4)
			inv.add('parka')
			inv.use('parka')
			_build_campfire()
			needs.calories = 1234.0
			body.core = 35.5
			player.health = 71.0
			clock.hour = 9.25
			deer[0].hp = 33.0
			print('SAVETEST wrote=', save_game())
		_print_state()
		get_tree().quit()
	if _gear_opt and _frames == 36 and gear.inv != null:
		gear.open()
		if _craftui:
			gear._craft_mode = true
			for pr in [['reed', 3], ['stick', 5], ['thatch', 2], ['knife', 1], ['gut', 1], ['wood', 2]]:
				inv.add(pr[0], pr[1])
		if _wearui:
			for wid in ['parka', 'toque', 'hide_mitts', 'hide_boots', 'hide_leggings', 'wolf_hat', 'sweater', 'bear_coat']:
				inv.add(wid)
			for wid in ['bear_coat', 'wolf_hat', 'hide_mitts', 'hide_boots', 'hide_leggings']:
				inv.use(wid)
		if _gear_sel != '':
			gear._sel = {'id': _gear_sel, 'from': 'pack', 'n': inv.count(_gear_sel)}
	if opts_dropdemo and _frames == 34 and inv != null:
		drop_item('beans', 3)
		drop_item('flare', 1)
	if _geartest and _frames == 35:
		_run_geartest()
	if _campfire_opt and _frames == 25:
		inv = Inventory.new(body)
		inv.needs = needs
		inv.add('wood', 3)
		inv.add('matches', 1)
		inv.add('flare', 2)
		_build_campfire()
	if _vmtest != '' and _frames == 30:
		_run_vmtest()
	if _deertest and _frames > 30:
		_deertest_step(delta)
	if _wolftest and _frames > 30:
		_wolftest_step(delta)
	if _selftest and _frames == 30:
		_run_selftest()
	if walk_secs > 0.0 and _frames > 10:
		_autowalk()


func _autowalk() -> void:
	if _t > 3.0:
		_ft.append(get_process_delta_time())
	if not _walk_started:
		_walk_started = true
		var ev := InputEventKey.new()
		ev.keycode = KEY_W
		ev.physical_keycode = KEY_W
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventKey.new()
		ev2.keycode = KEY_SHIFT
		ev2.physical_keycode = KEY_SHIFT
		ev2.pressed = true
		Input.parse_input_event(ev2)
		print("WALK_START pos=", player.position)
	if _t > walk_secs:
		_ft.sort()
		var tot := 0.0
		for x in _ft:
			tot += x
		print("BENCH avg_fps=%.1f p99_ms=%.1f frames=%d" % [_ft.size() / maxf(tot, 0.001), _ft[int(_ft.size() * 0.99)] * 1000.0, _ft.size()])
		print("WALK_END pos=", player.position, " stamina=%.1f exhausted=%s core=%.2f state=%s tier=%d hour=%.2f moved_speed=%.2f" % [
			player.stamina, str(player.exhausted), body.core, body.state_name(), snow.tier_at(player.position.x, player.position.z), clock.hour, player.speed_now])
		get_tree().quit()


## Spawn: nearest open, gentle, dry, snowy spot to map centre that borders forest (shelter within ~25 m).
func _find_spawn() -> Vector2:
	var water := MapIO.load_png("res://data/maps/valley_b/water_mask.png")
	water.convert(Image.FORMAT_L8)
	var half := 1024
	var best := Vector2.ZERO
	var best_d := 1e9
	for r in range(0, 700, 6):
		for a in range(0, 360, 12):
			var x := cos(deg_to_rad(a)) * r
			var z := sin(deg_to_rad(a)) * r
			if snow.canopy_height_at(x, z) > 1.0:
				continue
			if water.get_pixel(int(x) + half, int(z) + half).r > 0.5:
				continue
			var h: float = terrain.data.get_height(Vector3(x, 0, z))
			var hx: float = terrain.data.get_height(Vector3(x + 6, 0, z))
			var hz: float = terrain.data.get_height(Vector3(x, 0, z + 6))
			if is_nan(h) or is_nan(hx) or is_nan(hz) or absf(hx - h) > 0.7 or absf(hz - h) > 0.7:
				continue
			var shelter := snow.canopy_height_at(x + 20, z) >= 10.0 or snow.canopy_height_at(x - 20, z) >= 10.0 or snow.canopy_height_at(x, z + 20) >= 10.0 or snow.canopy_height_at(x, z - 20) >= 10.0
			if shelter and r < best_d:
				best_d = r
				best = Vector2(x, z)
		if best_d < 1e8:
			break
	print("SPAWN ", best)
	return best


func _lay_trail(n: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	for i in range(2, n + 2):
		var p := player.position + fwd * i * 0.7
		var g: float = terrain.data.get_height(p)
		if not is_nan(g):
			snow.trample(p.x, p.z, 0.5)
			footprints.step(p.x, g, p.z, player.yaw, maxi(snow.tier_at(p.x, p.z), 2))


## Cabin site: flat, open, dry ground 25-90 m from spawn, door facing the spawn point.
func _place_cabin(spawn: Vector2) -> void:
	var water := MapIO.load_png("res://data/maps/valley_b/water_mask.png")
	water.convert(Image.FORMAT_L8)
	for r in range(28, 110, 6):
		for a in range(0, 360, 15):
			var x := spawn.x + cos(deg_to_rad(a)) * r
			var z := spawn.y + sin(deg_to_rad(a)) * r
			if _site_ok(x, z, water):
				var cb := Cabin.new()
				add_child(cb)
				var yaw := rad_to_deg(atan2(spawn.x - x, spawn.y - z))
				if cb.setup(terrain, x, z, yaw):
					cabins.append(cb)
					print("CABIN at ", Vector2(x, z), " yaw ", yaw)
					return
				cb.queue_free()
	print("CABIN no site found")


## Point on the road bank (5 m off the centreline) nearest to p.
func _road_edge_toward(p: Vector2) -> Vector2:
	var best := p
	var bd := 1e18
	for q in road.points:
		var d := p.distance_squared_to(q)
		if d < bd:
			bd = d
			best = q
	return best + (p - best).normalized() * 5.0


# ---- Ice camp + ice fishing: huts stand ON the ice; holes beside them; chop your own with a hatchet
## Interior water far from shore (>=24 m clear), nearest the road: one camp per water body. Returns hut sites [{x,z,yaw,y}].
func _plan_ice_camps() -> Array:
	var cands: Array = []
	var gx := -1000.0
	while gx <= 1000.0:
		var gz := -1000.0
		while gz <= 1000.0:
			if not is_nan(ice.ice_at(gx, gz)) and ice.clearance(gx, gz, 26.0) >= 24.0:
				cands.append(Vector2(gx, gz))
			gz += 10.0
		gx += 10.0
	var out: Array = []
	if cands.is_empty() or road.points.size() < 8:
		print('ICECAMP no interior water found')
		return out
	var rp: Array = []
	var ri := 0
	while ri < road.points.size():
		rp.append(road.points[ri])
		ri += 4
	var scored: Array = []
	for c: Vector2 in cands:
		var bd := 1e9
		for q: Vector2 in rp:
			bd = minf(bd, c.distance_squared_to(q))
		scored.append({"c": c, "d": sqrt(bd)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	var centres: Array = []
	for s in scored:
		var c: Vector2 = s["c"]
		var far := true
		for o: Vector2 in centres:
			if o.distance_to(c) < 150.0:
				far = false
		if far and centres.size() < 2:
			centres.append(c)
	for c: Vector2 in centres:
		var nearest: Vector2 = rp[0]
		for q: Vector2 in rp:
			if q.distance_squared_to(c) < nearest.distance_squared_to(c):
				nearest = q
		var d := (nearest - c).normalized()
		var tang := Vector2(-d.y, d.x)
		var yaw := rad_to_deg(atan2(d.x, d.y))   # doorway (+Z) faces the road
		for k in 2:
			var p := c + tang * (float(k) * 14.0 - 7.0)
			var iy := ice.ice_at(p.x, p.y)
			if not is_nan(iy):
				out.append({"x": p.x, "z": p.y, "yaw": yaw, "y": iy})
	print('ICECAMP sites=', out.size(), ' ', out)
	return out


func _make_hole(x: float, z: float, perm: bool, born: float = -1.0) -> IceHole:
	var iy := ice.ice_at(x, z)
	if is_nan(iy):
		return null
	var h := IceHole.new()
	h.position = Vector3(x, 0.0, z)
	add_child(h)
	h.setup(iy, perm, clock.total_game_s if born < 0.0 else born)
	ice_holes.append(h)
	return h


func _build_ice_holes() -> void:
	for hu in huts:
		var h: Hut = hu
		if not h.on_ice:
			continue
		for sx in [-1.0, 1.0]:
			var wp: Vector3 = h.to_global(Vector3(sx * 1.1, 0.0, Hut.HZ + 2.4 + (0.6 if sx > 0.0 else 0.0)))
			_make_hole(wp.x, wp.z, true)
	print('ICECAMP holes=', ice_holes.size())


func _restore_holes(lst: Array) -> void:
	for h in ice_holes.duplicate():
		if not h.perm:
			ice_holes.erase(h)
			h.queue_free()
	for d: Dictionary in lst:
		if bool(d.get('perm', false)):
			for h in ice_holes:
				if Vector2(h.position.x - float(d['x']), h.position.z - float(d['z'])).length() < 0.2:
					h.spooked_until = float(d.get('spooked', 0.0))
		else:
			var nh := _make_hole(float(d['x']), float(d['z']), false, float(d.get('born', 0.0)))
			if nh != null:
				nh.spooked_until = float(d.get('spooked', 0.0))


func _hole_upkeep() -> void:
	for h in ice_holes.duplicate():
		if h.expired(clock.total_game_s):
			ice_holes.erase(h)
			h.queue_free()


func _hole_near(x: float, z: float, r: float) -> IceHole:
	for h in ice_holes:
		if Vector2(h.position.x - x, h.position.z - z).length() < r:
			return h
	return null


func _fish_cands(cands: Array) -> void:
	if inv == null or ice == null:
		return
	var pp := player.position
	var hole := _hole_near(pp.x, pp.z, 2.3)
	if hole != null:
		var hd := Vector2(hole.position.x - pp.x, hole.position.z - pp.z).length()
		if not _aim_ok(hole.global_position, 2.8, 0.9):
			return
		if inv.count('tackle') > 0:
			var tgt: IceHole = hole
			cands.append({"m": _lm, 'd': hd, 'text': 'Fish through the hole', 'hold': 10.0, 'kcal': 10.0, 'act': func() -> void: _fish_at(tgt)})
		else:
			cands.append({"m": _lm, 'd': hd, 'text': 'Fishing hole (needs fishing tackle)', 'act': func() -> void: _say('You need fishing tackle')})
		return
	if is_nan(ice.ice_at(pp.x, pp.z)):
		return
	if inv.count('axe') > 0 and _hole_near(pp.x, pp.z, 4.0) == null:
		var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
		var hx := pp.x + fwd.x * 1.3
		var hz := pp.z + fwd.z * 1.3
		if not is_nan(ice.ice_at(hx, hz)):
			cands.append({"m": 0.3, 'd': 1.3, 'text': 'Chop a fishing hole', 'hold': 12.0, 'kcal': 25.0, 'noise': 32.0, 'act': func() -> void:
				if _make_hole(hx, hz, false) != null:
					_say('Hole chopped through the ice')})


func _fish_at(hole: IceHole) -> void:
	var cond := inv.condition('tackle')
	var spooked := clock.total_game_s < hole.spooked_until
	var p := Fishing.bite_chance(clock.hour, cond, 0, spooked)
	if inv.wear('tackle', 0.03) <= 0.0:
		inv.remove('tackle')
		inv.cond.erase('tackle')
		_say('Your tackle snaps')
	if randf() < p:
		var id := Fishing.pick(randf())
		if inv.can_add(id):
			inv.add(id)
			hole.spooked_until = clock.total_game_s + Fishing.SPOOK_S
			_say('Caught a %s' % inv.name_of(id).replace('Raw ', '').to_lower())
		else:
			_say('A fish on the line, but your pack is full')
	else:
		_say('Nothing bites' if not spooked else 'Quiet: the fish are spooked')

func _build_huts() -> void:
	for hs in hut_sites:
		var h := Hut.new()
		add_child(h)
		if h.setup(terrain, float(hs['x']), float(hs['z']), float(hs['yaw']), float(hs.get('y', NAN))):
			huts.append(h)
			print('HUT at ', Vector2(float(hs['x']), float(hs['z'])))
		else:
			h.queue_free()
	colliders = []
	colliders.append_array(cabins)
	colliders.append_array(huts)
	colliders.append_array(outbuildings)
	colliders.append_array(greenhouses)
	colliders.append_array(stores)
	noise_bus.buildings = colliders
	for cbx in cabins:
		cbx.bus = noise_bus
		cbx.event.connect(_on_opening_event)
	for bx in colliders:
		for opx in bx.openings:
			opx.event.connect(_on_opening_event)
	if not cabins.is_empty() and road.points.size() > 2:
		var cyaw := deg_to_rad(cabins[0].rotation_degrees.y)
		var cp := Vector2(cabins[0].position.x, cabins[0].position.z)
		trailnet.add_trail(_road_edge_toward(cp), cp + Vector2(sin(cyaw), cos(cyaw)) * 3.9, 23)
	for ci in range(1, cabins.size()):
		var hy := deg_to_rad(cabins[ci].rotation_degrees.y)
		var hp := Vector2(cabins[ci].position.x, cabins[ci].position.z)
		trailnet.add_trail(_road_edge_toward(hp), hp + Vector2(sin(hy), cos(hy)) * 3.9, 23)
	trailnet.build_mesh(terrain)


## Hamlet: a cluster of 4-5 cabins well off the start, 35-60 m from the road. Reuses Cabin (doors, stove, windows); crates hold scavenged loot, not the starter kit.
var hamlet_center := Vector2.ZERO
var hamlet_n := 0


var store_plan := {}          # {x, z, yaw} planned before the forest
var stores: Array = []


## Roadside general store: flat spot 24-34 m off the road, far from the start, hamlet and huts.
func _plan_store(water: Image) -> void:
	store_plan = {}
	var i := road.points.size() - 25
	while i > 40:
		var rp: Vector2 = road.points[i]
		if rp.length() < 300.0 or rp.distance_to(hamlet_center) < 150.0:
			i -= 6
			continue
		var rq: Vector2 = road.points[mini(i + 1, road.points.size() - 1)]
		var d := (rq - rp).normalized()
		var nrm := Vector2(-d.y, d.x)
		for off in [26.0, -26.0, 34.0, -34.0, 44.0, -44.0]:
			var q: Vector2 = rp + nrm * off
			var ok := true
			for hs in hut_sites:
				if Vector2(float(hs['x']), float(hs['z'])).distance_to(q) < 80.0:
					ok = false
			if not ok or road.is_near(q.x, q.y, 14.0):
				continue
			var yaw := rad_to_deg(atan2(rp.x - q.x, rp.y - q.y))
			var fwd := Vector2(sin(deg_to_rad(yaw)), cos(deg_to_rad(yaw)))
			var side := Vector2(fwd.y, -fwd.x)
			for pt in [q, q + side * 3.2, q - side * 3.2, q + fwd * 3.5]:
				if not _flat_ok(pt.x, pt.y, water):
					ok = false
			if ok:
				store_plan = {'x': q.x, 'z': q.y, 'yaw': yaw}
				print('STORE_PLAN at ', q)
				return
		i -= 6
	print('STORE_PLAN none')


func _build_store() -> void:
	if store_plan.is_empty():
		return
	var st := Store.new()
	st.detail_enabled=route_detail_enabled
	add_child(st)
	if st.setup(terrain, float(store_plan['x']), float(store_plan['z']), float(store_plan['yaw'])):
		stores.append(st)
		print('STORE built at ', st.global_position)
	else:
		st.queue_free()


func _loot_store(st: Store, i: int) -> void:
	st.looted[i] = true
	st.update_loot_visuals()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(st.position.x) * 13.0 + absf(st.position.z) * 7.0) + i * 101
	var tables := [
		[['beans', 3, 30], ['matches', 3, 20], ['flare', 1, 8], ['rag', 2, 10], ['bandage', 1, 8]],
		[['ammo', 8, 25], ['bandage', 2, 16], ['antiseptic', 1, 12], ['antibiotics', 1, 8], ['matches', 2, 14], ['knife', 1, 5], ['tackle', 1, 10], ['compact_patrol_rifle', 1, 2], ['frontier_vented_rifle', 1, 2],
		 ['cell_batteries', 2, 10], ['flashlight', 1, 5], ['reflex_micro', 1, 2], ['scope_3_9x', 1, 1], ['light_clamp', 1, 2], ['muzzle_moderator', 1, 1]],
		[['sweater', 1, 12], ['toque', 1, 12], ['hammer', 1, 8], ['nails', 30, 14], ['plank', 6, 14], ['rag', 3, 12], ['axe', 1, 3],
		 ['duct_tape', 2, 10], ['screwdriver', 1, 6], ['scout_mount_clamp', 1, 2], ['cell_batteries', 2, 6]],
	]
	var table: Array = tables[i]
	var total := 0
	for e in table:
		total += int(e[2])
	var got: Array[String] = []
	for r in rng.randi_range(3, 4):
		var roll := rng.randi_range(0, total - 1)
		for e in table:
			roll -= int(e[2])
			if roll < 0:
				var n := maxi(1, int(e[1]) - rng.randi_range(0, int(e[1]) / 2))
				inv.add(String(e[0]), n)
				got.append('%s x%d' % [e[0], n])
				break
	_say('Found: ' + ', '.join(got))


var hamlet_plan: Array = []   # [{x, z, yaw}] planned BEFORE the forest so trees keep out of it
var hamlet_extra: Array = []  # [{kind, x, z, yaw}] woodshed / outhouse
var outbuildings: Array = []
var greenhouses: Array[Greenhouse] = []   # phase F winter greenhouse (hamlet extra)
var frostbite := Frostbite.new()           # N6 per-region cold injury
var warrens: Array[Vector3] = []          # rabbit warrens (seeded)
var rabbits: Array = []
var snares: Array[Snare] = []
var _rabbit_acc := 0.0


## Terrain-only hamlet planning (needs no forest). 3-5 cabins 35-90 m off the road, > 400 m from the map centre (where the start cabin lives).
func _plan_hamlet(water: Image) -> void:
	hamlet_plan = []
	hamlet_extra = []
	if road.points.size() < 60:
		return
	var layout := [Vector2(0, 0), Vector2(15, 4), Vector2(-14, 7), Vector2(9, -16), Vector2(-10, -15)]
	var i := 40
	var best_n := 0
	while i < road.points.size() - 20:
		var rp: Vector2 = road.points[i]
		if rp.length() < 400.0:
			i += 6
			continue
		var rq: Vector2 = road.points[mini(i + 1, road.points.size() - 1)]
		var d := (rq - rp).normalized()
		var nrm := Vector2(-d.y, d.x)
		for off in [35.0, -35.0, 45.0, -45.0, 58.0, -58.0, 72.0, -72.0, 90.0, -90.0]:
			var c: Vector2 = rp + nrm * off
			var spots: Array = []
			var far_from_huts := true
			for hs in hut_sites:
				if Vector2(float(hs['x']), float(hs['z'])).distance_to(c) < 80.0:
					far_from_huts = false
			if not far_from_huts:
				continue
			for l in layout:
				var q: Vector2 = c + nrm * l.x + d * l.y
				if _flat_ok(q.x, q.y, water) and not road.is_near(q.x, q.y, 9.0):
					spots.append({'x': q.x, 'z': q.y, 'yaw': rad_to_deg(atan2(rp.x - q.x, rp.y - q.y)) + float((spots.size() * 37) % 31 - 15)})
			if spots.size() > best_n and spots.size() >= 3:
				best_n = spots.size()
				hamlet_plan = spots
				hamlet_center = c
				hamlet_extra = _plan_extras(c, nrm, d, rp, spots, water)
				if best_n >= layout.size():
					print('HAMLET_PLAN at ', c, ' n=', best_n)
					return
		i += 6
	print('HAMLET_PLAN best n=', best_n, ' at ', hamlet_center)


func _plan_extras(c: Vector2, nrm: Vector2, d: Vector2, rp: Vector2, spots: Array, water: Image) -> Array:
	var out: Array = []
	var want := ['woodshed', 'outhouse', 'greenhouse']
	var offs := [Vector2(-3, 24), Vector2(24, -4), Vector2(-26, 0), Vector2(2, -27), Vector2(-24, 22), Vector2(26, 18)]
	for k in want:
		var he := Vector2(Greenhouse.HX + 0.2, Greenhouse.HZ + 0.2) if k == 'greenhouse' else Outbuilding.half_extents(k)
		for o in offs:
			var q: Vector2 = c + nrm * o.x + d * o.y
			if road.is_near(q.x, q.y, 8.0) or not _flat_ok(q.x, q.y, water):
				continue
			var clash := false
			for s in spots:
				if Vector2(float(s['x']), float(s['z'])).distance_to(q) < 8.0 + he.x:
					clash = true
			for e in out:
				if Vector2(float(e['x']), float(e['z'])).distance_to(q) < 7.0:
					clash = true
			if clash:
				continue
			out.append({'kind': k, 'x': q.x, 'z': q.y, 'yaw': rad_to_deg(atan2(rp.x - q.x, rp.y - q.y)) + float(out.size() * 23 - 12)})
			break
	return out


func _flat_ok(x: float, z: float, water: Image) -> bool:
	var hs: Array[float] = []
	for ox in [-5.0, 0.0, 5.0]:
		for oz in [-5.0, 0.0, 5.0]:
			var px: float = x + ox
			var pz: float = z + oz
			var wx := int(px) + 1024
			var wz := int(pz) + 1024
			if wx < 0 or wz < 0 or wx >= water.get_width() or wz >= water.get_height():
				return false
			if water.get_pixel(wx, wz).r > 0.5:
				return false
			var h: float = terrain.data.get_height(Vector3(px, 0, pz))
			if is_nan(h):
				return false
			hs.append(h)
	return (hs.max() - hs.min()) < 1.4


func _build_hamlet(_home: Vector2) -> void:
	hamlet_n = 0
	for hp in hamlet_plan:
		var cb := Cabin.new()
		cb.tint = [Color(0.92, 0.88, 0.84), Color(1.0, 1.0, 1.0), Color(0.88, 0.9, 0.95), Color(1.0, 0.95, 0.88), Color(0.9, 0.86, 0.8)][hamlet_n % 5]
		add_child(cb)
		if cb.setup(terrain, float(hp['x']), float(hp['z']), float(hp['yaw'])):
			if route_detail_enabled:
				var identity:Node3D=(load("res://assets/route_detail/home_identity_%d.glb"%(hamlet_n%5)) as PackedScene).instantiate()
				identity.name="HamletIdentity";cb.add_child(identity)
				for mesh:MeshInstance3D in identity.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=100
			cb.wood_pile = 2 + (hamlet_n * 3) % 5
			cabins.append(cb)
			hamlet_n += 1
		else:
			cb.queue_free()
	outbuildings = []
	for he in hamlet_extra:
		if String(he['kind']) == 'greenhouse':
			var gh := Greenhouse.new(); add_child(gh)
			if gh.setup(terrain, float(he['x']), float(he['z']), float(he['yaw'])):
				greenhouses.append(gh); print('GREENHOUSE at ', Vector2(float(he['x']), float(he['z'])))
			else:
				gh.queue_free()
			continue
		var ob := Outbuilding.new()
		add_child(ob)
		if ob.setup(terrain, String(he['kind']), float(he['x']), float(he['z']), float(he['yaw'])):
			outbuildings.append(ob)
		else:
			ob.queue_free()
	if hamlet_n > 0:
		print('HAMLET built outbuildings=', outbuildings.size(), '  cabins=', hamlet_n, ' at ', hamlet_center)

## Scavenged crate: 3-5 rolls from a weighted table, seeded by the crate position so it is stable.
func _loot_hamlet_crate(cb: Cabin) -> void:
	cb.crate_looted = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(cb.position.x) * 31.0 + absf(cb.position.z) * 17.0)
	var table := [['matches', 3, 22], ['beans', 2, 20], ['ammo', 5, 12], ['bandage', 1, 14], ['rag', 2, 14], ['antiseptic', 1, 8], ['antibiotics', 1, 5], ['nails', 20, 9], ['plank', 3, 8], ['flare', 1, 7], ['sweater', 1, 4], ['toque', 1, 4], ['knife', 1, 3], ['hammer', 1, 3], ['cooking_pot', 1, 5], ['carrot_seeds', 3, 6], ['kale_seeds', 3, 6], ['potato', 2, 6],
				 ['cell_batteries', 2, 6], ['flashlight', 1, 4], ['duct_tape', 1, 5], ['screwdriver', 1, 3]]
	var total := 0
	for e in table:
		total += int(e[2])
	var got: Array[String] = []
	for r in rng.randi_range(3, 5):
		var roll := rng.randi_range(0, total - 1)
		for e in table:
			roll -= int(e[2])
			if roll < 0:
				var n := maxi(1, int(e[1]) - rng.randi_range(0, int(e[1]) / 2))
				inv.add(String(e[0]), n)
				got.append('%s x%d' % [e[0], n])
				break
	_say('Found: ' + ', '.join(got))


func _site_ok(x: float, z: float, water: Image) -> bool:
	var hs: Array[float] = []
	for ox in [-5.0, 0.0, 5.0]:
		for oz in [-5.0, 0.0, 5.0]:
			var px: float = x + ox
			var pz: float = z + oz
			if snow.canopy_height_at(px, pz) > 1.0:
				return false
			if water.get_pixel(int(px) + 1024, int(pz) + 1024).r > 0.5:
				return false
			var h: float = terrain.data.get_height(Vector3(px, 0, pz))
			if is_nan(h):
				return false
			hs.append(h)
	return (hs.max() - hs.min()) < 1.4


var inv: Inventory
var gear: GearScreen
var _sel_text := ""
var _sel_idx := 0
var _n_actions := 0
var _kill_ids := {}
var _loot := false
var _loot_done := false
var _gear_opt := false
var _gear_sel := ''
var _geartest := false
var _craftui := false
var _wearui := false
var opts_dropdemo := false
var _cands_cache: Array = []
var _cur: Dictionary = {}


func _say(msg: String) -> void:
	hud.say(msg)


func _ensure_gear() -> void:
	if inv == null:
		return
	if _loot and not _loot_done:
		_loot_done = true
		for id in Inventory.ITEMS.keys():
			inv.add(id, 3 if id in ['wood', 'beans', 'ammo', 'matches'] else 1)
		inv.add('wood', 6)
	if gear != null and gear.inv != inv:
		gear.setup(self, inv, player, needs, body, clock, hud)
	hud.inv = inv
	hud.needs = needs


func _count_kills() -> int:
	for z in zombies:
		if is_instance_valid(z) and z.is_dead() and not _kill_ids.has(z.get_instance_id()):
			_kill_ids[z.get_instance_id()] = true
	return _kill_ids.size()


func gear_use(id: String) -> void:
	if inv == null:
		return
	if id == 'flare':
		_throw_flare()
		return
	# Treat the current player even after a load or injury-object replacement.
	if Inventory.kind_of(id)=="med":Inventory.injury=player.injury
	var before:=inv.count(id)
	_say(inv.use(id))
	if inv.count(id)<before and viewmodel!=null:
		viewmodel.queue_treatment(id)
		if id in ["bandage","clean_water"]:audio.play_at("cloth_wrap" if id=="bandage" else "bottle_sip",player.position,-14,1,1,4)


func gear_hands(rifle: bool) -> void:
	if rifle and inv.count('rifle') > 0:
		rifle_up = true
		_say('Rifle raised')
	else:
		rifle_up = false
		_say('Hatchet in hands' if inv.count('axe') > 0 else 'Empty hands')


func drop_item(id: String, n: int) -> void:
	if inv == null or inv.count(id) < 1:
		return
	n = mini(n, inv.count(id))
	if inv.is_worn(id) and n >= inv.count(id):
		inv.use(id)
	if id == 'rifle' and n >= inv.count(id):
		rifle_up = false
	var nm := inv.name_of(id)
	var cd := inv.condition(id)
	var food_age:=float(inv.age.get(id,0))
	if id == 'rifle': id = inv.rifle_id()
	if not inv.remove(id, n):
		return
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var p := player.position + fwd * 1.3
	var h: float = player.ground_at(p.x, p.z)
	if is_nan(h):
		h = player.position.y - player.eye_h
	var st: Array = inv.last_removed_states.duplicate(true) if Inventory.is_rifle(id) else []
	for s in st:   # a scoped rifle dropped in the snow can knock its sight
		if s is Dictionary and String((s.get('fit', {}) as Dictionary).get('optic', '')) != '': s['zero'] = _knocked(s.get('zero', [0.0, 0.0]), randf_range(0.2, 0.8))
	var dropped := ItemPickup.spawn(self, id, n, Vector3(p.x, h, p.z), cd if cd < 0.999 else -1.0,food_age, st)
	_say('Dropped %s%s' % [nm, ' x%d' % n if n > 1 else ''])


func take_pickup(node: Node) -> void:
	var p := node as ItemPickup
	if p == null or inv == null or p.is_queued_for_deletion():
		return
	if not inv.can_add(p.id, p.n):
		_say('Your pack is full')
		return
	var had := inv.count(p.id)
	var cur_c := inv.condition(p.id)
	if Inventory.is_rifle(p.id): inv.add(p.id, p.n, p.states)   # it keeps its own sight, light, zero, rounds
	else: inv.add_aged(p.id,p.n,p.age_s)
	if p.cond >= 0.0 or cur_c < 0.999:
		inv.cond[p.id] = (cur_c * float(had) + (p.cond if p.cond >= 0.0 else 1.0) * float(p.n)) / float(had + p.n)
	_say('Picked up %s%s' % [inv.name_of(p.id), ' x%d' % p.n if p.n > 1 else ''])
	p.queue_free()


func _run_geartest() -> void:
	var fails := 0
	inv = Inventory.new(body)
	inv.needs = needs
	inv.add('wood', 9)
	var c1 := inv.stacks().size() == 3
	inv.add('parka')
	inv.use('parka')
	inv.add('rifle')
	var c2 := inv.stacks().size() == 3
	var inv2 := Inventory.new(body)
	inv2.add('ammo', 240)
	var c3 := inv2.stacks().size() == Inventory.CAPACITY and not inv2.can_add('ammo', 1) and not inv2.can_add('matches', 1) and inv2.can_add('rifle', 1)
	var pk0 := get_tree().get_nodes_in_group('pickups').size()
	drop_item('wood', 2)
	var c4 := inv.count('wood') == 7 and get_tree().get_nodes_in_group('pickups').size() == pk0 + 1
	var node: Node = get_tree().get_nodes_in_group('pickups')[pk0]
	take_pickup(node)
	var c5 := inv.count('wood') == 9 and node.is_queued_for_deletion()
	drop_item('parka', 1)
	var c6 := inv.jacket() == '' and inv.count('parka') == 0 and is_equal_approx(body.warmth, 0.25)
	gear.setup(self, inv, player, needs, body, clock, hud)
	gear.open()
	var c7 := gear.is_open and player.ui_open
	gear.close()
	var c8 := not gear.is_open and not player.ui_open
	print('GEARTEST stacks=%s worn+equip=%s cap=%s drop=%s take=%s dropworn=%s open=%s close=%s' % [c1, c2, c3, c4, c5, c6, c7, c8])
	for c in [c1, c2, c3, c4, c5, c6, c7, c8]:
		if not c:
			fails += 1
	# --- simulated mouse UI ---
	inv = Inventory.new(body)
	inv.needs = needs
	inv.add('beans', 2)
	inv.add('wood', 5)
	inv.add('parka')
	inv.add('matches', 2)
	gear.setup(self, inv, player, needs, body, clock, hud)
	gear.open()
	await _frames_wait(3)
	await _sim_double(gear._pack_rect(1).get_center())       # stacks: parka, beans, wood4, wood1, matches
	var u1ok := inv.count('beans') == 1
	await _frames_wait(2)
	await _sim_drag(gear._pack_rect(0).get_center(), gear._slot_rect('jacket').get_center())
	var u2ok := inv.jacket() == 'parka'
	await _frames_wait(2)
	var pk1 := get_tree().get_nodes_in_group('pickups').size()
	await _sim_drag(gear._pack_rect(1).get_center(), gear._ground_rect(2).get_center())   # wood x4 -> ground
	var u3ok := inv.count('wood') == 1 and get_tree().get_nodes_in_group('pickups').size() == pk1 + 1
	await _frames_wait(2)
	await _sim_btn(gear._pack_rect(0).get_center(), MOUSE_BUTTON_RIGHT)    # beans -> menu
	var u4ok: bool = not gear._menu.is_empty() and gear._menu['entries'].size() >= 2
	await _frames_wait(2)
	var mr: Rect2 = gear._hits.filter(func(h) -> bool: return h['k'] == 'menu')[0]['r']
	await _sim_btn(mr.get_center(), MOUSE_BUTTON_LEFT)
	await _sim_btn(mr.get_center(), MOUSE_BUTTON_LEFT, false)
	var u5ok := inv.count('beans') == 0
	var ke := InputEventKey.new()
	ke.keycode = KEY_ESCAPE
	ke.pressed = true
	gear._input(ke)
	var u6ok := not gear.is_open
	print('GEARTEST ui dbl-eat=%s drag-wear=%s drag-drop=%s menu=%s menu-act=%s esc=%s' % [u1ok, u2ok, u3ok, u4ok, u5ok, u6ok])
	for c in [u1ok, u2ok, u3ok, u4ok, u5ok, u6ok]:
		if not c:
			fails += 1
	print('GEARTEST failures=', fails)
	get_tree().quit()


func _frames_wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _sv(v: Vector2) -> Vector2:
	return gear._origin() + v * gear._scale()


func _sim_btn(v: Vector2, btn: int, pressed := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = pressed
	e.position = _sv(v)
	gear._on_gui(e)
	await get_tree().process_frame


func _sim_move(v: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _sv(v)
	gear._on_gui(e)
	await get_tree().process_frame


func _sim_double(v: Vector2) -> void:
	await _sim_btn(v, MOUSE_BUTTON_LEFT, true)
	await _sim_btn(v, MOUSE_BUTTON_LEFT, false)
	await _sim_btn(v, MOUSE_BUTTON_LEFT, true)
	await _sim_btn(v, MOUSE_BUTTON_LEFT, false)


func _sim_drag(a: Vector2, b: Vector2) -> void:
	await _sim_move(a)
	await _sim_btn(a, MOUSE_BUTTON_LEFT, true)
	await _sim_move(a + (b - a) * 0.5)
	await _sim_move(b)
	await _sim_btn(b, MOUSE_BUTTON_LEFT, false)


## Window/door events (from zombies or the player): sound + noise that draws the horde.
func _on_opening_event(ev: String, pos: Vector3) -> void:
	if ev == "glass_break":
		noise_bus.emit_noise(pos, 38.0, null)
		if audio != null:
			audio.play_at("glass", pos, 6.0, randf_range(0.92, 1.08), 10.0, 180.0)
	elif ev == "board_break":
		noise_bus.emit_noise(pos, 22.0, null)
		if audio != null:
			audio.play_at("chop", pos, 2.0, randf_range(0.6, 0.75), 8.0, 100.0)


const HAMMER_WEAR_BOARD := 1.0 / 90.0   # per board nailed: 90 boards = 6 fully boarded cabins (door 3 + 3 windows x 4 = 15)
const HAMMER_WEAR_PULL := 1.0 / 250.0   # per plank pulled with the claw


## Wear the hammer; at 0% it breaks and is gone.
func _hammer_wear(amt: float) -> void:
	_wear_tool("hammer", amt)


func _wear_tool(id: String, amt: float) -> void:
	if inv == null or inv.count(id) <= 0:
		return
	var before := inv.condition(id)
	var after := inv.wear(id, amt)
	if id == "hammer":
		if after <= 0.0 and not inv.infinite:
			inv.remove("hammer", inv.count("hammer"))
			_say("The hammer broke!")
		elif after < 0.2 and before >= 0.2:
			_say("The hammer is badly worn")


## One board nailed up: a plank + a nail, and the hammer wears. False (nothing used) when something is missing.
func _nail_board() -> bool:
	if inv.count("hammer") <= 0 or inv.count("plank") < 1 or inv.count("nails") < 1:
		return false
	if not (inv.remove("plank") and inv.remove("nails", 1)):
		return false
	_hammer_wear(HAMMER_WEAR_BOARD)
	return true


func _door_cands(cands: Array, cb: Node3D, fwd: Vector3) -> void:
	var dp: Vector3 = cb.door_inside_pos()
	var dd := (dp - player.position).length()
	if cb.door_open or cb.door_broken or not _aim_ok(dp, 2.2, 1.0):
		return
	if cb.door_boards < 3:
		if inv.count("hammer") > 0 and inv.count("plank") > 0 and inv.count("nails") >= 1:
			cands.append({"m": _lm, "d": dd + 0.04, "text": "Barricade door (%d/3)" % cb.door_boards, "hold": 6.0, "kcal": 8.0, "noise": 22.0, "work": "hammer", "work_pos": dp, "act": func() -> void:
				if not cb.door_open and not cb.door_broken and cb.door_boards<3 and _nail_board():
					cb.add_door_board()
					_say("Door barricaded: %d/3" % cb.door_boards)})
		else:
			cands.append({"m": _lm, "d": dd + 0.1, "text": "Barricade door (needs hammer, plank, nail)", "act": func() -> void: _say("Need a hammer, a plank and a nail")})
	if cb.door_boards > 0:
		cands.append({"m": _lm, "d": dd + 0.03, "text": "Pull off door plank", "hold": 3.0, "kcal": 4.0, "noise": 14.0, "act": func() -> void:
			if cb.remove_door_board():
				_hammer_wear(HAMMER_WEAR_PULL)
				inv.add("plank")
				inv.add("nails", 1)
				_say("Door plank off")})


## Interaction targeting. The view ray starts at the eye and follows yaw/pitch (no head bob / sway, deterministic).
func _view_dir() -> Vector3:
	return Vector3(-sin(player.yaw) * cos(player.pitch), sin(player.pitch), -cos(player.yaw) * cos(player.pitch))


## Perpendicular distance from point p to the view ray, INF when it is behind you.
func _aim_miss(p: Vector3) -> float:
	var to := p - player.position
	var f := _view_dir()
	var along := to.dot(f)
	if along <= 0.0:
		return INF
	return (to - f * along).length()


## Is p under the crosshair? Within `reach` metres (3D, from the eye) AND within `tol` metres of the view ray.
## Standing practically on top of it (< 0.8 m) counts without looking.
func _ground_y(x: float, z: float) -> float:
	var h: float = IceField.lift(terrain.data.get_height(Vector3(x, 0.0, z)), x, z)   # frozen lakes: the ice is the ground
	return 0.0 if is_nan(h) else h


## Is the crosshair on this tree trunk (x, z, r)? The view ray must pass within r + 0.4 m of the trunk's axis somewhere
## between the ground and 5 m up, or you are standing right against it. Sets _lm to that miss.
var _tree_aimed := func(tv: Vector3) -> bool:
	return _trunk_aimed(tv)

var _plant_aimed := func(p: Dictionary) -> bool:
	if p.is_empty():
		return false
	return _aim_ok(Vector3(float(p["x"]), _ground_y(float(p["x"]), float(p["z"])) + 0.25, float(p["z"])), 2.3, 0.8)


func _trunk_aimed(tv: Vector3) -> bool:
	var eye := player.position
	var to := Vector2(tv.x - eye.x, tv.y - eye.z)
	if to.length() < tv.z + 0.9:
		_lm = 0.2
		return true
	var v := _view_dir()
	var vh := Vector2(v.x, v.z)
	if vh.length() < 0.05:
		return false
	var t := to.dot(vh) / vh.length_squared()
	if t <= 0.0:
		return false
	var pt := eye + v * t
	var gy := _ground_y(tv.x, tv.y)
	if pt.y < gy - 0.3 or pt.y > gy + 5.0:
		return false
	var miss := Vector2(pt.x - tv.x, pt.z - tv.y).length() - tv.z
	if miss <= 0.4 * aim_tol_scale:
		_lm = maxf(miss, 0.0)
		return true
	return false


var aim_tol_scale := 1.0   # playtest knob: multiplies every interaction tolerance (0.8 tighter, 1.25 looser)
var _lm := 0.5             # crosshair miss (m) of the target the last passing _aim_ok() looked at


func _aim_ok(p: Vector3, reach: float, tol: float) -> bool:
	var dist := (p - player.position).length()
	if dist > reach:
		return false
	var miss := _aim_miss(p)
	if dist < 0.8:
		_lm = minf(miss, 1.5)
		return true
	if miss <= tol * aim_tol_scale:
		_lm = miss
		return true
	return false


## Board / unboard / curtain actions for windows within reach, from the INSIDE of cabins and huts.
func _opening_cands(cands: Array, fwd: Vector3) -> void:
	var blds: Array = []
	blds.append_array(cabins)
	blds.append_array(huts)
	if collapse!=null and collapse.clinic!=null:blds.append(collapse.clinic)
	for bld in blds:
		var inside: bool = bld.contains_xz(player.position.x, player.position.z)
		if inside and bld is Cabin:
			_door_cands(cands, bld, fwd)
		for op in bld.openings:
			var o: Opening = op
			var od := (o.center_world() - player.position).length()
			if not _aim_ok(o.center_world(), 2.0, 0.75):
				continue
			# either side: smash intact glass, climb through a clear gap, sweep up shards
			if not o.glass_broken and inv.count("axe") > 0:
				cands.append({"m": _lm, "d": od + 0.08, "text": "Smash window (loud)", "hold": 1.0, "kcal": 3.0, "act": func() -> void: o.smash()})
			if o.passable():
				cands.append({"m": _lm, "d": od - 0.05, "text": "Climb through window" + (" (glass!)" if o.shards else ""), "hold": 1.6, "kcal": 6.0, "noise": 8.0, "act": func() -> void:
					var dest: Vector3 = o.outside_pos() if inside else o.inside_pos()
					if o.shards:
						player.hurt(3.0, "Bled out on broken glass")
						player.injury.wound(0.3, 0.12)
						_say("Cut on the glass")
					player.position.x = dest.x
					player.position.z = dest.z})
			if o.shards:
				cands.append({"m": _lm, "d": od + 0.03, "text": "Clear glass shards", "hold": 3.0, "kcal": 3.0, "act": func() -> void:
					if o.clear_shards():
						_say("Sill cleared")})
			if not inside:
				continue
			if o.boards < Opening.MAX_BOARDS:
				if inv.count("hammer") > 0 and inv.count("plank") > 0 and inv.count("nails") >= 1:
					cands.append({"m": _lm, "d": od, "text": "Board up window (%d/%d)" % [o.boards, Opening.MAX_BOARDS], "hold": 5.0, "kcal": 6.0, "noise": 22.0, "work": "hammer", "work_pos": o.center_world(), "act": func() -> void:
						if _nail_board():
							o.add_board()
							_say("Boarded: %d/%d" % [o.boards, Opening.MAX_BOARDS])})
				else:
					cands.append({"m": _lm, "d": od + 0.05, "text": "Board up window (needs hammer, plank, nail)", "act": func() -> void: _say("Need a hammer, a plank and a nail")})
			if o.boards > 0:
				cands.append({"m": _lm, "d": od + 0.02, "text": "Pull off a plank", "hold": 3.0, "kcal": 4.0, "noise": 14.0, "act": func() -> void:
					if o.remove_board():
						_hammer_wear(HAMMER_WEAR_PULL)
						inv.add("plank")
						inv.add("nails", 1)
						_say("Plank off (+1 plank, +1 nail)")})
			if not o.curtain:
				if inv.count("rag") >= 2:
					cands.append({"m": _lm, "d": od + 0.01, "text": "Hang curtain (2 rags)", "hold": 4.0, "kcal": 3.0, "act": func() -> void:
						if inv.remove("rag", 2):
							o.hang_curtain()
							_say("Curtain hung: light and eyes blocked")})
				else:
					cands.append({"m": _lm, "d": od + 0.06, "text": "Hang curtain (needs 2 rags)", "act": func() -> void: _say("Need 2 rags")})
			else:
				cands.append({"m": _lm, "d": od + 0.01, "text": "Take down curtain", "hold": 2.0, "act": func() -> void:
					if o.remove_curtain():
						inv.add("rag", 2)
						_say("+2 rags")})


## Crosshair ranking. A thing behind a nearer thing on the same line of sight is not offered (the window hides the
## stove behind it); what is best centred on the crosshair comes first, distance second.
func _rank_cands(cands: Array) -> Array:
	var keep: Array = []
	for c in cands:
		var cm := float(c.get("m", -1.0))
		var hidden := false
		if cm >= 0.0:
			for a in cands:
				var am := float(a.get("m", -1.0))
				if am >= 0.0 and am < 0.35 and float(a["d"]) + 0.8 < float(c["d"]) and absf(am - cm) < 0.3:
					hidden = true
					break
		if not hidden:
			keep.append(c)
	keep.sort_custom(func(x, y) -> bool: return float(x["d"]) + 1.2 * minf(float(x.get("m", 0.4)), 1.5) < float(y["d"]) + 1.2 * minf(float(y.get("m", 0.4)), 1.5))
	return keep


func _update_prompt() -> void:
	if _sl_on:
		hud.actions = []
		_cands_cache = []
		_cur = {}
		return
	if inv == null:
		inv = Inventory.new(body)
		inv.add("wood", 2)
		inv.add("matches", 1)
		inv.needs = needs
	_ensure_gear()
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var cands: Array = []
	for hu in huts:
		var hud: Hut = hu
		var hdd: float = hud.to_global(Vector3(0.0, 1.0, Hut.HZ)).distance_to(player.position)
		if not hud.door_broken and _aim_ok(hud.to_global(Vector3(0.0, 1.0, Hut.HZ)), 2.2, 1.0):
			cands.append({"m": _lm, 'd': hdd, 'text': 'Close door' if hud.door_open else 'Open door', 'act': hud.toggle_door})
		if not hu.crate_looted:
			var hh: Hut = hu
			var hd: float = hh.tackle_world_pos().distance_to(player.position)
			if _aim_ok(hh.tackle_world_pos(), 1.8, 0.6):
				cands.append({"m": _lm, 'd': hd, 'text': 'Search tackle box', 'hold': 2.0, 'act': func() -> void:
					hh.crate_looted = true
					inv.add('matches', 2)
					inv.add('beans', 1)
					inv.add('flare', 1)
					inv.add('knife', 1)
					inv.add('tackle', 1)
					_say('Found: 2 matches, beans, flare, knife, fishing tackle')})
	_fish_cands(cands)
	for stx in stores:
		var sto: Store = stx
		var sdd: float = sto.to_global(Vector3(0.0, 1.0, Store.HZ)).distance_to(player.position)
		if not sto.door_broken and _aim_ok(sto.to_global(Vector3(0.0, 1.0, Store.HZ)), 2.2, 1.0):
			cands.append({"m": _lm, 'd': sdd, 'text': 'Close door' if sto.door_open else 'Open door', 'act': sto.toggle_door})
		for li in 3:
			if not sto.looted[li]:
				var lpd: float = sto.loot_world_pos(li).distance_to(player.position)
				if _aim_ok(sto.loot_world_pos(li), 1.7, 0.6):
					var lidx: int = li
					cands.append({"m": _lm, 'd': lpd, 'text': String(Store.LOOT_NAMES[li]), 'hold': 2.5, 'act': func() -> void: _loot_store(sto, lidx)})
	for ob in outbuildings:
		if ob.wood_left > 0:
			var obb: Outbuilding = ob
			var od: float = obb.wood_world_pos().distance_to(player.position)
			if _aim_ok(obb.wood_world_pos(), 2.0, 0.8):
				cands.append({"m": _lm, 'd': od, 'text': 'Take firewood (%d left)' % obb.wood_left, 'hold': 1.0, 'act': func() -> void:
					if obb.wood_left > 0:
						obb.wood_left -= 1
						inv.add('wood')
						_say('+1 firewood')})
	if fire_lookout != null:
		var dp:=fire_lookout.door_world_pos()
		if _aim_ok(dp,2.2,1.1):
			var text: String="Door is broken" if fire_lookout.door_broken else ("Close door" if fire_lookout.door_open else "Open door")
			if fire_lookout.door_boards>0:text="Door barricaded (%d/3)" % fire_lookout.door_boards
			cands.append({"m":_lm,"d":dp.distance_to(player.position),"text":text,"act":_toggle_lookout_door})
		if fire_lookout.contains_room(player.position):_door_cands(cands,fire_lookout,fwd)
	for cb in cabins:
		var items: Array[Dictionary] = [
			{"pos": cb.door_world_pos(), "r": 2.0, "tol": 1.1, "text": "Door is broken" if cb.door_broken else ("Close door" if cb.door_open else "Open door"), "act": cb.toggle_door},
			{"pos": cb.woodpile_world_pos(), "r": 1.9, "text": "Take firewood (%d left)" % cb.wood_pile, "act": func() -> void:
				if cb.take_firewood():
					inv.add("wood")
					_say("+1 firewood")},
		]
		if not cb.crate_looted and cb != cabins[0]:
			items.append({"pos": cb.crate_world_pos(), "r": 1.7, "text": "Search crate", "hold": 3.0, "act": func() -> void: _loot_hamlet_crate(cb)})
		elif not cb.crate_looted:
			items.append({"pos": cb.crate_world_pos(), "r": 1.7, "text": "Search crate", "hold": 3.0, "act": func() -> void:
				cb.crate_looted = true
				inv.add("matches", 4)
				inv.add("flare", 1)
				inv.add("parka")
				inv.add("axe")
				inv.add("knife")
				inv.add("sweater")
				inv.add("toque")
				inv.add("rifle")
				inv.add("ammo", 6)
				inv.add("beans", 2)
				inv.add("hammer")
				inv.add("nails", 40)
				inv.add("plank", 8)
				inv.add("rag", 4)
				inv.add("bandage", 2)
				inv.add("antiseptic", 1)
				inv.add("antibiotics", 1)
				_say("Found: hatchet, knife, rifle + 6 rounds, parka, sweater, toque, matches, beans, hammer, nails, planks, rags")})
		items.append_array(fire_actions(cb.fire, cb.stove_world_pos(), cb.refresh_fire, 1.7, 0.9, cb.rack_world_pos()))
		items.append_array(_furniture_items(cb))
		items.append_array(_sleep_items(cb))
		for it in items:
			if it.get('hide', false):
				continue
			var ipos: Vector3 = it["pos"]
			var d := (ipos - player.position).length()
			if not _aim_ok(ipos, float(it["r"]), float(it.get("tol", 0.9))):
				continue
			it["d"] = d + float(it.get("dbias", 0.0))
			it["m"] = _lm
			cands.append(it)
	if opening != null:
		for it: Dictionary in opening.actions():
			var point: Vector3 = it.pos
			if _aim_ok(point,float(it.get("r",2.1)),float(it.get("tol",.8))):
				it["m"] = _lm; it["d"] = point.distance_to(player.position)+float(it.get("dbias",0)); cands.append(it)
	if collapse!=null:
		for it:Dictionary in collapse.actions():
			var pt:Vector3=it.pos
			if _aim_ok(pt,float(it.get("r",2.1)),float(it.get("tol",.8))):it["m"]=_lm;it["d"]=pt.distance_to(player.position)+float(it.get("dbias",0));cands.append(it)
	if town_life!=null:
		for it:Dictionary in town_life.actions():
			var pt:Vector3=it.pos
			if _aim_ok(pt,float(it.get("r",2.1)),float(it.get("tol",.8))) and HitZones.building_block(_building_list(),player.position,(pt-player.position).normalized(),player.position.distance_to(pt))>=player.position.distance_to(pt)-.15:
				it["m"]=_lm;it["d"]=pt.distance_to(player.position);cands.append(it)
	var wb := _workbench_point()
	if wb != Vector3.INF and _aim_ok(wb, 2.2, .9):
		cands.append({"pos": wb, "r": 2.2, "m": _lm, "d": wb.distance_to(player.position), "text": "Gunsmith at the workbench",
					  "act": func() -> void: open_gunsmith(inv.rifle_id(), true)})
	_chest_cands(cands)
	_forage_cands(cands)
	_snare_cands(cands)
	for g: Greenhouse in greenhouses:
		if g.global_position.distance_to(player.position) > 7.0:
			continue
		for it: Dictionary in g.actions(inv, _say):
			if _aim_ok(it.pos, float(it.r), float(it.tol)):
				it["m"] = _lm; it["d"] = (it.pos as Vector3).distance_to(player.position); cands.append(it)
	_opening_cands(cands, fwd)
	for sb: Node in _stove_buildings():
		var st: Stove = sb.get("stove")
		for it: Dictionary in fire_actions(st.fire, st.top_world(), Callable(), 2.3, 0.9):  # low stove top sits ~1.1 m under the eye
			if not _aim_ok(it.pos, float(it.r), float(it.tol)):
				continue
			it["m"] = _lm
			it["d"] = st.top_world().distance_to(player.position) + float(it.get("dbias", 0.0))
			cands.append(it)
	for cf in campfires:
		var cfire: Campfire = cf
		for it: Dictionary in fire_actions(cfire.fire, cfire.global_position + Vector3(0.0, 0.2, 0.0), Callable(), 2.6, 0.9):
			if not _aim_ok(it.pos, float(it.r), float(it.tol)):
				continue
			it["m"] = _lm
			it["d"] = cfire.global_position.distance_to(player.position) + float(it.get("dbias", 0.0))
			cands.append(it)
	for cn in get_tree().get_nodes_in_group("carcasses"):
		var cnode := cn as Node3D
		if cnode == null or cnode.is_queued_for_deletion():
			continue
		var cdist := cnode.global_position.distance_to(player.position)
		if not _aim_ok(cnode.global_position + Vector3(0.0, 0.3, 0.0), 2.6, 1.0):
			continue
		for candidate:Dictionary in _carcass_actions(cnode):
			candidate.m=_lm;candidate.d=cdist+float(candidate.get("dbias",0));cands.append(candidate)

	for bn in get_tree().get_nodes_in_group("bodies"):
		var bz := bn as Node3D
		if bz == null or bz.is_queued_for_deletion() or bz.get_meta("searched", false):
			continue
		var bd := bz.global_position.distance_to(player.position)
		if _aim_ok(bz.global_position + Vector3(0.0, 0.3, 0.0), 2.4, 1.0):
			cands.append({"m": _lm, "d": bd, "text": "Search body", "hold": 3.0, "kcal": 5.0, "act": func() -> void: _search_body(bz)})
	for pk in get_tree().get_nodes_in_group("pickups"):
		var ip := pk as ItemPickup
		if ip == null:
			continue
		var pc := ip.global_position + Vector3(0.0, 0.15, 0.0)
		if _aim_ok(pc, 2.8, 0.55):
			var pick: ItemPickup = ip
			var pmiss := _aim_miss(pc)
			cands.append({"m": _lm, "d": 0.5 + (pmiss if pmiss < 50.0 else 0.0) * 1.5 + (pc - player.position).length() * 0.1, "text": "Take %s%s" % [inv.name_of(ip.id), " x%d" % ip.n if ip.n > 1 else ""], "act": func() -> void: take_pickup(pick)})
	if plants != null:
		var pl: Dictionary = plants.nearest(player.position, fwd, 1.8, _plant_aimed)
		if not pl.is_empty():
			_plant_aimed.call(plants.get_plant(pl["key"]))   # sets _lm for the plant actually chosen
			var kd: Dictionary = PlantField.KINDS[pl["kind"]]
			var iid: String = kd["item"]
			var pn: int = int(kd["n"])
			var phold := float(kd["hold"])
			if inv.count('knife') > 0 and kd.has("knife_hold"):
				phold = float(kd["knife_hold"])
			var pkey: String = pl["key"]
			cands.append({"m": _lm, "d": float(pl["d"]) + 0.2, "text": "Gather %s (+%d %s)" % [kd["label"], pn, inv.name_of(iid)], "hold": phold, "kcal": 3.0, "act": func() -> void:
				if plants.pick(pkey, clock.total_game_s):
					audio.play_at("rustle", player.position, -4.0, randf_range(0.85, 1.2), 4.0, 40.0)
					_give_or_drop(iid, pn, player.position + fwd * 0.8)})
	var axe_up := inv.count('axe') > 0 and not rifle_up
	if forest != null and axe_up:
		var tr: Dictionary = forest.nearest_tree(player.position, fwd, 2.0, true, _tree_aimed)
		if not tr.is_empty():
			_tree_aimed.call(Vector3(tr["x"], tr["z"], tr["r"]))
			var tk: String = ForestScatter.tree_key(float(tr["x"]), float(tr["z"]))
			var pw := lerpf(0.55, 1.0, inv.condition('axe'))
			var left := float(forest.chop_hp.get(tk, ForestScatter.hits_total(float(tr["h"]))))
			cands.append({"m": _lm, "d": float(tr["d"]) + 0.3, "text": "Chop tree (%d hits)" % int(ceil(left / pw)), "label": "Chopping", "hold": 0.85,
				"work": "chop",
				"again": func() -> bool: return not forest.felled.has(tk) and inv.count('axe') > 0 and not rifle_up,
				"act": func() -> void: _chop_hit(tr)})
	for lg in get_tree().get_nodes_in_group("logs"):
		var wl := lg as WoodLog
		if wl == null or wl.is_queued_for_deletion():
			continue
		var ld := wl.dist_to(player.position)
		if ld < 2.2 and _aim_ok(wl.interaction_point(player.position, _view_dir(), 2.6), 2.6, 1.2):
			if axe_up:
				cands.append({"m": _lm, "d": ld + 0.2, "text": "Split log (+%d firewood, %d sticks)" % [wl.firewood, wl.sticks], "hold": 5.0, "kcal": 25.0, "noise": 20.0, "work": "split", "work_pos": wl.interaction_point(player.position, _view_dir(), 2.6), "act": func() -> void: _split_log(wl)})
			else:
				cands.append({"m": _lm, "d": ld + 0.2, "text": "Log (needs a hatchet equipped)", "act": func() -> void: _say('Need a hatchet to split this')})
	cands = _rank_cands(cands)
	if cands.size() > 40:
		cands.resize(40)
	var texts: Array = []
	for c in cands:
		texts.append(String(c["text"]).split(" (")[0])
	_n_actions = cands.size()
	_sel_idx = texts.find(_sel_text)
	if _sel_idx < 0:
		_sel_idx = 0
	var best: Dictionary = cands[_sel_idx] if not cands.is_empty() else {}
	_sel_text = String(texts[_sel_idx]) if not cands.is_empty() else ""
	var shown: Array = []
	for c in cands:
		shown.append(String(c["text"]))
	hud.actions = shown
	hud.action_sel = _sel_idx
	_cur = best
	_cands_cache = cands
	hud.prompt = String(best.get("text", ""))
	var info := "Wood %d  Matches %d" % [inv.count("wood"), inv.count("matches")]
	if inv.jacket() != "":
		info += "  [%s]" % inv.name_of(inv.jacket())
	if inv.top() != "":
		info += "  [%s]" % inv.name_of(inv.top())
	var other := inv.extra.size() - (1 if inv.jacket() != "" else 0) - (1 if inv.top() != "" else 0)
	if other > 0:
		info += " +%d" % other
	for cb in cabins:
		if cb.is_lit():
			info += "   Stove: %.0f min left" % (cb.stove_fuel_s / 60.0)
	info += '   Cal %d (%s)  Water %d%% (%s)' % [int(needs.calories), needs.hunger_state(), int(needs.water), needs.thirst_state()]
	if inv.count('rifle') > 0:
		info += '   [%s] ammo %s' % ['RIFLE' if rifle_up else 'hatchet', 'INF' if player.god else str(inv.count('ammo'))]
	info += '   Wt %.1f/%d kg' % [inv.total_weight(), int(Inventory.WEIGHT_SOFT)]
	hud.info = info
	hud.rifle_up = rifle_up
	hud.scoped = viewmodel != null and viewmodel.scoped_view
	player.aim_req = aim_override or rifle_up and inv != null and inv.count('rifle') > 0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	player.speed_mult = inv.speed_mult()*needs.travel_mult()
	hud.kills = _count_kills()


# ---- Optics: GPU scope picture, scope-in settle, long-range targets in the scope cone.
var _was_scoped := false
var _scope_promote_t := 0.0
## ---- Weapon light (kit v3 attachments): L toggles, batteries drain faster in the cold, and a
## lit beam is a light lure for zombies ahead of you (NoiseBus.emit_light) as well as a beacon.
const LIGHT_LURE_EVERY_S := 0.5
var _light_lure_t := 0.0
func _toggle_weapon_light() -> void:
	var rid := inv.rifle_id()
	if not rifle_up or rid == '':
		_toggle_torch(); return
	if RifleDB.light(rid).is_empty():
		_say('No light on this rifle. Lower it to use a flashlight' if inv.count('flashlight') > 0 else 'No light on this rifle'); return
	var f: Dictionary = RifleDB.fitted(rid).duplicate()
	if float(f.get('light_h', 0.0)) <= 0.0:
		if inv.count('cell_batteries') > 0:
			inv.remove('cell_batteries'); f['light_h'] = float(RifleDB.light(rid).get('battery_h', 6.0)); inv.fitted[rid] = f
			inv.light_on = true; _say('Fresh batteries in the light')
		else:
			_say('The light is dead. You need batteries')
		return
	inv.fitted[rid] = f
	inv.light_on = not inv.light_on
	_say('Light on' if inv.light_on else 'Light off')

## ---- Handheld flashlight (W3): rifle lowered, one hand. Same battery rules and lure as weapon lights.
const TORCH := {"range_m": 28.0, "angle_deg": 24.0, "energy": 5.0, "battery_h": 6.0}
var _torch: SpotLight3D
func _toggle_torch() -> void:
	if inv.count('flashlight') < 1:
		_say('No light to switch on'); return
	if inv.torch_h <= 0.0:
		if inv.count('cell_batteries') > 0:
			inv.remove('cell_batteries'); inv.torch_h = float(TORCH.battery_h); inv.torch_on = true; _say('Fresh batteries in the flashlight')
		else:
			_say('The flashlight is dead. You need batteries')
		return
	inv.torch_on = not inv.torch_on
	_say('Flashlight on' if inv.torch_on else 'Flashlight off')

func torch_shining() -> bool:
	return inv != null and inv.torch_on and inv.torch_h > 0.0 and inv.count('flashlight') > 0 and not rifle_up and player != null and not player.dead

func _update_torch(delta: float) -> void:
	var on := torch_shining()
	if on and _torch == null and player != null:
		_torch = SpotLight3D.new(); _torch.name = 'HandTorch'
		_torch.spot_range = float(TORCH.range_m); _torch.spot_angle = float(TORCH.angle_deg) * 0.5
		_torch.spot_angle_attenuation = 1.6; _torch.light_energy = float(TORCH.energy); _torch.light_color = Color(1.0, 0.93, 0.80)
		_torch.shadow_enabled = true; _torch.shadow_bias = 0.06; _torch.light_specular = 0.35
		_torch.position = Vector3(0.20, -0.22, -0.15); _torch.rotation = Vector3(0.05, 0.10, 0.0)   # held low and right, aimed at the view centre
		player.cam.add_child(_torch)
		WeaponPresentation.add_beam(_torch)
	if viewmodel != null: viewmodel.torch_on = on
	# the lamp sits in the held flashlight's head once the hand model exists
	if _torch != null and viewmodel != null and viewmodel.torch_beam != null and _torch.get_parent() != viewmodel.torch_beam:
		_torch.get_parent().remove_child(_torch); viewmodel.torch_beam.add_child(_torch)
		_torch.position = Vector3.ZERO; _torch.rotation = Vector3.ZERO
	if _torch != null: _torch.visible = on
	if viewmodel != null and viewmodel._torch != null: WeaponPresentation.set_lens_glow(viewmodel._torch, on)
	if not on: return
	var cold := 1.0 + 0.67 * clampf(-air_c() / 20.0, 0.0, 1.0)
	inv.torch_h = maxf(0.0, inv.torch_h - delta * clock.time_scale / 3600.0 * cold)
	if inv.torch_h <= 0.0:
		inv.torch_on = false; _say('The flashlight dims and dies'); return
	_light_lure(float(TORCH.range_m), delta)

func _light_lure(reach: float, delta: float) -> void:
	_light_lure_t -= delta
	if _light_lure_t <= 0.0 and noise_bus != null:
		_light_lure_t = LIGHT_LURE_EVERY_S
		var fwd := -player.cam.global_transform.basis.z
		noise_bus.emit_light(player.position + fwd * reach * 0.6, reach * 0.8, player)   # what the beam lights
		noise_bus.emit_light(player.position, 18.0, player)                              # the lamp itself

## Light shafts: only something in the air shows a beam - falling snow, fog, night haze.
func beam_k() -> float:
	var night: float = sky_rig.gameplay_night_factor if sky_rig != null else 0.0
	var air := 0.18 + (weather.precip * 1.1 if weather != null else 0.0) + (maxf(0.0, weather.fog_mult - 1.0) * 0.4 if weather != null else 0.0)
	return clampf(night * air, 0.0, 1.2) * lerpf(1.0, 0.25, _indoor_k)

func _update_beams() -> void:
	var k := beam_k()
	var nodes: Array = []
	if _torch != null: nodes.append(_torch)
	if viewmodel != null and viewmodel._rifle != null and viewmodel._rifle.lamp != null: nodes.append(viewmodel._rifle.lamp)
	# the lit lamp for the snow shader (flakes in the cone light up)
	var lamp: SpotLight3D = null
	for n: Node in nodes:
		var sl := n as SpotLight3D
		if sl != null and sl.visible and sl.light_energy > 0.05 and sl.is_visible_in_tree(): lamp = sl; break
	if lamp != null:
		var lp := lamp.global_position; var ld := -lamp.global_basis.z.normalized()
		RenderingServer.global_shader_parameter_set("player_lamp_pos", Vector4(lp.x, lp.y, lp.z, clampf(lamp.light_energy / 6.0, 0.2, 1.4)))
		RenderingServer.global_shader_parameter_set("player_lamp_dir", Vector4(ld.x, ld.y, ld.z, cos(deg_to_rad(lamp.spot_angle))))
		RenderingServer.global_shader_parameter_set("player_lamp_range", lamp.spot_range)
	elif _lamp_global_on:
		RenderingServer.global_shader_parameter_set("player_lamp_pos", Vector4.ZERO)
	_lamp_global_on = lamp != null
	for n: Node in nodes:
		var b := n.get_node_or_null("BeamShaft") as MeshInstance3D
		if b != null: (b.material_override as ShaderMaterial).set_shader_parameter("intensity", k)

var _lamp_global_on := true
## Knocks shift a scope's zero: a struggle, a heavy hit while carrying it (drops are handled in drop_item).
var _was_struggling := false
var _last_hp := -1.0
func _zero_knocks(rid: String) -> void:
	if player == null or inv == null: return
	var knock := 0.0
	if player.struggling and not _was_struggling: knock = randf_range(0.6, 1.6)
	elif _last_hp >= 0.0 and _last_hp - player.health > 12.0: knock = randf_range(0.3, 1.0)
	_was_struggling = player.struggling; _last_hp = player.health
	if knock > 0.0 and rid != '' and RifleDB.is_v3(rid) and String(RifleDB.fitted(rid).get('optic', '')) != '':
		inv.zero[rid] = _knocked(inv.zero.get(rid, [0.0, 0.0]), knock)
		_say('The scope took a knock')

static func _knocked(z: Array, m: float) -> Array:
	var a := randf() * TAU
	var v := Vector2(float(z[0]), float(z[1])) + Vector2(cos(a), sin(a)) * m
	v = v.limit_length(6.0)
	return [v.x, v.y]

func light_shining() -> bool:
	if inv == null or not inv.light_on or not rifle_up: return false
	var rid := inv.rifle_id()
	return rid != '' and not RifleDB.light(rid).is_empty() and float(RifleDB.fitted(rid).get('light_h', 0.0)) > 0.0

func _update_weapon_light(rid: String, delta: float) -> void:
	var on := light_shining()
	if viewmodel != null: viewmodel.light_on = on
	if not on: return
	# battery: game hours at the clock's rate; 20 C nominal, -20 C gives ~60 % of the run time
	var f: Dictionary = inv.fitted.get(rid, RifleDB.fitted(rid))
	var cold := 1.0 + 0.67 * clampf(-air_c() / 20.0, 0.0, 1.0)
	f['light_h'] = maxf(0.0, float(f.get('light_h', 0.0)) - delta * clock.time_scale / 3600.0 * cold)
	inv.fitted[rid] = f
	if float(f['light_h']) <= 0.0:
		inv.light_on = false; _say('The light dims and dies'); return
	_light_lure(float(RifleDB.light(rid).get('range_m', 30.0)), delta)

func _update_optic(delta: float) -> void:
	if hud == null or hud.scope == null or player == null: return
	RifleDB.inv = inv   # v3 rifles read their fitted attachments from the live inventory
	var rid := inv.rifle_id() if inv != null else ''
	var o: Dictionary = RifleDB.optic(rid) if rid != '' else {}
	var kind := String(o.get('type', 'iron'))
	_update_weapon_light(rid, delta)
	_update_torch(delta)
	Zombie.player_lit = light_shining() or torch_shining()   # a lit lamp carries far at night
	Wolf.player_lit = Zombie.player_lit
	_update_beams()
	_zero_knocks(rid)
	hud.optic_kind = kind if rifle_up else ''
	var scoped: bool = viewmodel != null and viewmodel.scoped_view
	if scoped and not _was_scoped: player.scope_settle = 0.6
	_was_scoped = scoped
	# kit v3 reflex / red-dot tubes draw their dot in the lens; only kit v2 reflex art needs the overlay dot
	var on := scoped or (kind == 'reflex' and not RifleDB.is_v3(rid) and rifle_up and player.aim_k > 0.9)
	var mag := tan(deg_to_rad(Player.HIP_FOV) * 0.5) / tan(deg_to_rad(player.cam.fov) * 0.5)
	hud.scope.update_view(on, kind, String(o.get('reticle', 'none')), mag, player.cam.fov, player.sway, delta)
	if forest != null: forest.set_view_scale(clampf(mag / 1.6, 1.0, 3.0) if scoped else 1.0)
	if pop == null: return
	# Through 3x+ glass the player sees past the 240 m proxy ring and must be able
	# to hit what is seen: widen proxies, promote the ones in the cone to actors.
	var long := scoped and mag >= 2.5
	pop.proxy_r = Population.SCOPE_PROXY_R if long else Population.PROXY_R
	_scope_promote_t -= delta
	if long and _scope_promote_t <= 0.0:
		_scope_promote_t = 0.25
		var half := atan(tan(deg_to_rad(player.cam.fov) * 0.5) * 0.9)
		pop.promote_cone(player.cam.global_position, -player.cam.global_basis.z, cos(half), minf(pop.proxy_r, BULLET_RANGE), 6)


# ---- ActionRunner: hold-to-act with progress ring. Candidates may carry "hold" (s), "kcal", "noise" (m), "label".
const ACTION_DURATION_MULT := 0.5  # Halve active work waits; costs and world simulation keep their own timing.
var _act: Dictionary = {}
var _act_t := 0.0
var _act_hold := 0.0
var _act_pos := Vector3.ZERO
var _act_hp := 100.0
var _work_cues := 0


func _act_begin(c: Dictionary, repeating := false) -> void:
	_act_cancel()
	var hold := float(c.get("hold", 0.0))
	if hold <= 0.0:
		interaction_count += 1
		(c["act"] as Callable).call()
		return
	_act = c
	_act_t = 0.0
	_act_hold = hold * ACTION_DURATION_MULT
	_act_pos = player.position
	_act_hp = player.health
	_work_cues = 0
	if viewmodel != null: viewmodel.begin_work(String(c.get("work", "")), _act_hold, repeating)
	if float(c.get("game_min", 0.0)) > 0.0:
		# bench / field work: the hold covers its real game minutes (needs, cold and the clock run on)
		_ts_restore = clock.time_scale
		clock.time_scale = maxf(clock.time_scale, float(c["game_min"]) * 60.0 / maxf(_act_hold, 0.1))
	if c.has("start"):
		(c["start"] as Callable).call()
	if float(c.get("noise", 0.0)) > 0.0:
		noise_bus.emit_noise(player.position, float(c["noise"]), player)


var _ts_restore := -1.0
func _act_cancel(msg := "", completed := false) -> void:
	if _ts_restore >= 0.0:
		clock.time_scale = _ts_restore; _ts_restore = -1.0
	if viewmodel != null: viewmodel.end_work(completed)
	_act = {}
	_act_t = 0.0
	if hud != null:
		hud.action_t = -1.0
	if msg != "":
		_say(msg)


## Advance the running action. held = action key still down. Cancels on release, movement, damage, struggle.
func _act_update(delta: float, held: bool) -> void:
	if _act.is_empty():
		if hud != null:
			hud.action_t = -1.0
		return
	var moved := Vector2(player.position.x - _act_pos.x, player.position.z - _act_pos.z).length() > 0.6
	if not held and not bool(_act.get("auto",false)):
		_act_cancel("Hold E to finish")
		return
	if moved or player.airborne or player.dead or player.struggling or player.ui_open or player.health < _act_hp - 0.01:
		_act_cancel("Interrupted")
		return
	var work := String(_act.get("work", ""))
	if (work in ["chop","split"] and (inv.count("axe")==0 or rifle_up)) or (work=="hammer" and inv.count("hammer")==0):
		_act_cancel("Tool put away")
		return
	_act_t += delta
	if viewmodel != null:
		viewmodel.update_work(_act_t)
		var cues := viewmodel.work_impacts(minf(_act_t,_act_hold))
		if cues>_work_cues and audio != null:
			var at: Vector3 = _act.get("work_pos",_act.get("pos",player.position+_view_dir()*.8))
			# Feedback does not spend resources or emit additional AI noise.
			audio.play_at("hammer" if work=="hammer" else "chop",at,-4,1,5,50)
		_work_cues = cues
	hud.action_t = _act_t / _act_hold
	hud.action_label = String(_act.get("label", String(_act.get("text", "")).split(" (")[0]))
	if _act_t >= _act_hold:
		var c := _act
		_act_cancel("", true)
		var kc := float(c.get("kcal", 0.0))
		if kc > 0.0:
			needs.calories = maxf(0.0, needs.calories - kc)
		interaction_count += 1
		(c["act"] as Callable).call()
		if held and c.has("again") and not player.dead and (c["again"] as Callable).call():
			_act_begin(c, true)


# ---- Wood: chop trees, fell them, split logs
func _chop_hit(tr: Dictionary) -> void:
	var x := float(tr["x"])
	var z := float(tr["z"])
	var tk := ForestScatter.tree_key(x, z)
	if forest.felled.has(tk):
		return
	var power := lerpf(0.55, 1.0, inv.condition('axe'))
	var left := float(forest.chop_hp.get(tk, ForestScatter.hits_total(float(tr["h"])))) - power
	inv.wear('axe', 0.004)
	needs.calories = maxf(0.0, needs.calories - 9.0)
	noise_bus.emit_noise(player.position, 38.0, player)
	var at := Vector3(x, player.position.y - 0.4, z)
	audio.play_at("chop", at, 4.0, randf_range(0.9, 1.1), 8.0, 120.0)
	FallingTree.burst(self, at + Vector3(0, 0.3, 0), 6, 1.5)
	if left <= 0.0:
		forest.chop_hp.erase(tk)
		_fell_tree(x, z)
	else:
		forest.chop_hp[tk] = left


func _fell_tree(x: float, z: float) -> void:
	var info: Dictionary = forest.fell(x, z)
	if info.is_empty():
		return
	var away := Vector3(x - player.position.x, 0.0, z - player.position.z)
	away = away.normalized() if away.length() > 0.01 else Vector3(0, 0, -1)
	var r := float(info["r"])
	var h := float(info["h"])
	WoodLog.make_stump(self, terrain, x, z, r)
	var ft := FallingTree.new()
	add_child(ft)
	ft.setup(forest.tree_mesh(int(info["vi"])), forest.tree_mat(), info["origin"], info["basis"], away, h, func() -> void: _land_tree(x, z, away, h, r))
	noise_bus.emit_noise(player.position, 55.0, player)
	audio.play_at("crash", Vector3(x, player.position.y, z), 6.0, randf_range(0.9, 1.05), 14.0, 200.0)
	_say('Timber!')


func _land_tree(x: float, z: float, away: Vector3, h: float, r: float) -> void:
	var wl := WoodLog.new()
	add_child(wl)
	wl.setup(terrain, x, z, away, h, r)
	audio.play_at("thud", wl.center() + Vector3(0, 0.5, 0), 8.0, 0.5, 14.0, 160.0)
	noise_bus.emit_noise(wl.center(), 45.0, player)


func _split_log(wl: WoodLog) -> void:
	if not is_instance_valid(wl) or wl.is_queued_for_deletion():
		return
	if inv.count("axe") < 1 or rifle_up:
		_say("Equip a hatchet to split this log"); return
	var fw := wl.firewood
	var sk := wl.sticks
	_give_or_drop('wood', fw, wl.center())
	_give_or_drop('stick', sk, wl.center())
	inv.wear('axe', 0.01)
	_say('Split log: %d firewood, %d sticks. Make planks in Gear > Craft.' % [fw, sk])
	if wl.has_meta("authored_stop") and first_week!=null:first_week.consume_timber()
	wl.queue_free()


func _give_or_drop(id: String, n: int, pos: Vector3) -> void:
	var dropped := 0
	for i in range(n):
		if inv.can_add(id, 1):
			inv.add(id, 1)
		else:
			dropped += 1
	if dropped > 0:
		ItemPickup.spawn(self, id, dropped, _ground(pos.x, pos.z))
		_say('Pack full: %d %s left on the ground' % [dropped, inv.name_of(id)])


func _carcass_actions(cn:Node3D) -> Array:
	var out:Array=[];var species:=Carcass.species_of(cn);var done:Dictionary=cn.get_meta("done",{})
	var index:=0
	for step:String in Carcass.open_steps(species,done):
		var info:=Carcass.tool_step(species,step,inv);var label:="%s %s"%[Carcass.STEP_VERB[step],Carcass.SPECIES[species].label]
		index+=1
		if not info.ok:
			out.append({"text":label+" (needs a usable tool)","dbias":index*.01,"act":func()->void:_say("Bring a knife with 1% condition, or a hatchet with 2% for meat only")});continue
		var tool:String=info.tool;var id:String=info.id;var n:int=info.n
		var stale:=step=="meat" and Carcass.food_age(cn)>=Inventory.shelf_s(id)
		out.append({"text":label+" (+%d %s)"%[n,"spoiled portions" if stale else inv.name_of(id)],"hold":float(info.time),"label":label,"work":"reach","dbias":index*.01,"act":func()->void:_carcass_step(cn,species,step,id,n,tool)})
	return out

func _carcass_step(cn:Node3D,sp:String,step:String,id:String,n:int,tool:String="") -> void:
	if cn==null or cn.is_queued_for_deletion() or not cn.is_in_group("carcasses") or Carcass.species_of(cn)!=sp:return
	var done:Dictionary=cn.get_meta("done",{})
	if done.get(step,false) or step not in Carcass.open_steps(sp,done):return
	# Recheck the chosen tool, never silently change yield/tool after the hold began.
	var info:=Carcass.tool_step(sp,step,inv,tool)
	if not info.ok or info.id!=id or int(info.n)!=n:
		_say("Butchery interrupted: the required usable tool is no longer available");return
	var output:=id;var food_age:=0.0
	if step=="meat":
		food_age=Carcass.food_age(cn)
		if food_age>=Inventory.shelf_s(id):output="rotten_meat";food_age=0
	done[step]=true;cn.set_meta("done",done)
	_give_or_drop_aged(output,n,cn.global_position,food_age)
	inv.wear(String(info.tool),float(info.wear));needs.calories=maxf(0,needs.calories-30)
	audio.play_at("slice",cn.global_position,0,1,6,60)
	_say("%s: +%d %s"%[String(Carcass.STEP_VERB[step]).replace(" from",""),n,inv.name_of(output)])
	if Carcass.open_steps(sp,done).is_empty():cn.queue_free()

func _give_or_drop_aged(id:String,n:int,pos:Vector3,age:float) -> void:
	var left:=n
	while left>0 and inv.can_add(id):inv.add_aged(id,1,age);left-=1
	if left>0:
		ItemPickup.spawn(self,id,left,_ground(pos.x,pos.z),-1,age)
		_say("Pack full: %d %s left on the ground"%[left,inv.name_of(id)])

## Break cabin furniture down into reclaimed wood (planks) and sticks: hatchet or hammer, loud.
func _furniture_items(cb: Cabin) -> Array:
	var out: Array = []
	for id: String in Cabin.FURNITURE:
		if id in cb.broken: continue
		var spec: Dictionary = Cabin.FURNITURE[id]
		var at := cb.furniture_world_pos(id)
		var tool := "axe" if inv != null and inv.count("axe") > 0 else ("hammer" if inv != null and inv.count("hammer") > 0 else "")
		var hold: float = float(spec.hold) * (1.0 if tool == "axe" else 1.5)
		var label := "Break down %s • %d planks, %d sticks" % [spec.name, int(spec.plank), int(spec.stick)]
		if tool == "":
			out.append({"pos": at, "r": 1.6, "tol": 0.8, "text": label + " • needs hatchet or hammer", "dbias": 0.05, "act": func() -> void: _say("Breaking down furniture needs a hatchet or a hammer")})
			continue
		var cid := id
		out.append({"pos": at, "r": 1.6, "tol": 0.8, "text": label, "hold": hold, "kcal": 30.0, "noise": 30.0, "work": "split", "dbias": 0.05, "act": func() -> void: _break_furniture(cb, cid)})
	return out


func _break_furniture(cb: Cabin, id: String) -> void:
	if id in cb.broken: return
	var tool := "axe" if inv.count("axe") > 0 else ("hammer" if inv.count("hammer") > 0 else "")
	if tool == "":
		_say("Breaking down furniture needs a hatchet or a hammer"); return
	var spec: Dictionary = Cabin.FURNITURE[id]
	var at := cb.furniture_world_pos(id)
	cb.break_furniture(id)
	_give_or_drop("plank", int(spec.plank), at)
	_give_or_drop("stick", int(spec.stick), at)
	inv.wear(tool, 0.02)
	audio.play_at("chop", at, -4, 1, 4, 40)
	_say("Broke down the %s: %d planks, %d sticks of reclaimed wood" % [spec.name, int(spec.plank), int(spec.stick)])


func _cabin_food_actions(cb:Cabin) -> Array:
	return fire_actions(cb.fire, cb.stove_world_pos(), cb.refresh_fire, 1.7).filter(func(it:Dictionary)->bool:return String(it.get("tag",""))=="cook")


func _search_body(bz: Node3D) -> void:
	if bz == null or bz.get_meta("searched", false):
		return
	bz.set_meta("searched", true)
	var loot := Carcass.body_loot(int(bz.global_position.x * 7.0) * 31 + int(bz.global_position.z * 13.0))
	if loot.is_empty():
		_say('Nothing on the body')
		return
	var parts: Array = []
	for id in loot.keys():
		_give_or_drop(String(id), int(loot[id]), bz.global_position)
		parts.append('%d %s' % [int(loot[id]), inv.name_of(String(id))])
	_say('Found: ' + ', '.join(parts))


func _carcass_list() -> Array:
	var out: Array = []
	for cn in get_tree().get_nodes_in_group('carcasses'):
		var c := cn as Node3D
		if c == null or c.is_queued_for_deletion():
			continue
		var sp := Carcass.species_of(c)
		if sp == '':
			continue
		out.append({'sp': sp, 'x': c.global_position.x, 'z': c.global_position.z, 'done': c.get_meta('done', {}),'food_age_s':Carcass.food_age(c),'scent_age_s':Carcass.age_s(c)})
	return out


func _log_list() -> Array:
	var out: Array = []
	for lg in get_tree().get_nodes_in_group('logs'):
		var wl := lg as WoodLog
		if wl != null and not wl.is_queued_for_deletion() and not wl.has_meta("authored_stop"):
			out.append(wl.to_save())
	return out


func _toggle_lookout_door() -> void:
	if fire_lookout.door_broken:_say("The door is broken");return
	if fire_lookout.door_boards>0:_say("Remove the door planks first");return
	fire_lookout.toggle_door()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE and pause_menu != null and not pause_menu.visible:
		pause_menu.open()
		return
	if _sl_on:
		return   # asleep: only the pause menu and the wake keys (polled) work
	if player.struggling and not player.dead:
		if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_SPACE or e.keycode == KEY_E):
			player.struggle_press()
		if e is InputEventKey or e is InputEventMouseButton:
			return
	if e is InputEventKey and e.pressed and e.keycode == KEY_M and player.dead:
		get_tree().change_scene_to_file('res://ui/main_menu.tscn')
		return
	if e is InputEventKey and e.pressed and e.keycode == KEY_R and player.dead:
		SaveGame.pending = SaveGame.read()
		get_tree().reload_current_scene()
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_R and rifle_up and not player.ui_open:
		_start_reload()
		return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if player.aim_k > 0.6:
			player.zoom_step(1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1)   # scope zoom while aimed
			return
		if _n_actions > 1:
			var stepv := -1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			_sel_idx = posmod(_sel_idx + stepv, _n_actions)
			hud.action_sel = _sel_idx
			_sel_text = String(hud.actions[_sel_idx]).split(" (")[0]
			_cur = _cands_cache[_sel_idx]
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _mouse_ok():
		_lmb_held = true
		_attack()
		return
	if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_lmb_held = false
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_E and not _cur.is_empty():
		_act_begin(_cur)
	elif e.keycode == KEY_V and inv != null:
		_throw_flare()
	elif e.keycode == KEY_L and inv != null:
		_toggle_weapon_light()
	elif e.keycode == KEY_B and inv != null:
		_build_campfire()
	elif e.keycode == KEY_X and inv != null and inv.count('rifle') > 0:
		_act_cancel()
		rifle_up = not rifle_up
		_say('Rifle raised' if rifle_up else 'Hatchet')
	elif e.keycode == KEY_F:
		_attack()


func _throw_flare() -> void:
	if not inv.remove('flare'):
		_say('No flares')
		return
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var p := player.position + fwd * 2.5
	var h: float = player.ground_at(p.x, p.z)
	if is_nan(h):
		h = player.position.y - player.eye_h
	var f := Flare.new()
	add_child(f)
	f.global_position = Vector3(p.x, h, p.z)
	_say('Flare lit (60 s)')


var _selftest := false


func _stand_at(p: Vector3, look: Vector3) -> void:
	player.position = Vector3(p.x, p.y, p.z)
	player.yaw = atan2(-(look.x - p.x), -(look.z - p.z))
	_update_prompt()


func _run_selftest() -> void:
	var cb: Cabin = cabins[0]
	var fails := 0
	# crate
	var cp := cb.crate_world_pos()
	_stand_at(cp + Vector3(-1.0, 0.0, 0.0), cp)
	var ok1 := String(_cur.get("text", "")) == "Search crate"
	var m0 := inv.count("matches")
	var p0 := inv.count("parka")
	if ok1:
		(_cur["act"] as Callable).call()
	var ok2 := inv.count("parka") == p0 + 1 and inv.count("matches") == m0 + 4 and inv.count("axe") >= 1 and inv.count("rifle") >= 1
	print("TEST crate prompt=%s loot=%s" % [ok1, ok2])
	# door
	var dp := cb.door_world_pos()
	_stand_at(dp + cb.global_transform.basis.z * 1.2, dp)
	var ok3 := String(_cur.get("text", "")).ends_with("door")
	print("TEST door prompt=%s" % ok3)
	# stove light
	var sp := cb.stove_world_pos()
	_stand_at(cb.to_global(Vector3(-1.4, 0.0, -0.6)) + Vector3(0, 1.7, 0), sp)
	var w0 := inv.count("wood")
	var ok4 := String(_cur.get("text", "")).begins_with("Light stove")
	if ok4:
		(_cur["act"] as Callable).call()
	var lit := cb.is_lit()
	var heat := cb.heat_at(player.position.x, player.position.z)
	print("TEST stove prompt=%s lit=%s wood %d->%d matches=%d heat=%.0fW" % [ok4, lit, w0, inv.count("wood"), inv.count("matches"), heat])
	# wear parka
	var warm0 := body.warmth
	var msg := inv.use("parka")
	print("TEST wear '%s' warmth=%.2f windproof=%.2f" % [msg, body.warmth, body.windproof])
	var msg2 := inv.use("parka")
	print("TEST unwear '%s' warmth=%.2f" % [msg2, body.warmth])
	if not (ok1 and ok2 and ok3 and ok4 and lit and heat > 100.0 and ((msg.begins_with("Took off") and msg2.begins_with("Wearing")) or (msg.begins_with("Wearing") and msg2.begins_with("Took off"))) and absf(body.warmth - warm0) < 0.01):
		fails += 1
	print("SELFTEST failures=", fails)
	get_tree().quit()


var wolves: Array[Wolf] = []
var bears: Array[Wolf] = []
var _wolftest := false
var _beartest := false
var _flareopt := false
var _flare_done := false
var _mash := false
var _mash_t := 0.0
var _wt := 0.0


func _spawn_wolves(n: int, center: Vector2, min_d: float, max_d: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var made := 0
	var tries := 0
	while made < n and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(min_d, max_d)
		var x := center.x + cos(a) * r
		var z := center.y + sin(a) * r
		if absf(x) > 950.0 or absf(z) > 950.0:
			continue
		var h: float = terrain.data.get_height(Vector3(x, 0, z))
		if is_nan(h):
			continue
		_add_wolf(Vector3(x, h, z), made)
		made += 1


func _spawn_bears(n: int, center: Vector2, min_d: float, max_d: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var made := 0
	var tries := 0
	while made < n and tries < 200:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(min_d, max_d)
		var x := center.x + cos(a) * r
		var z := center.y + sin(a) * r
		if absf(x) > 950.0 or absf(z) > 950.0:
			continue
		var h: float = terrain.data.get_height(Vector3(x, 0, z))
		if is_nan(h):
			continue
		_add_wolf(Vector3(x, h, z), 2000 + made, true)
		made += 1


func _add_wolf(p: Vector3, idx: int, bear := false) -> Wolf:
	if p.y>-400:p.y=RoadNet.lift(p.y,p.x,p.z)
	var w: Wolf = Bear.new() if bear else Wolf.new()
	add_child(w)
	w.global_position = p
	w.setup(terrain, snow, player, forest, colliders, noise_bus, 1000 + idx)
	if bear:
		bears.append(w)
	else:
		wolves.append(w)
	return w


func _wolftest_step(delta: float) -> void:
	_wt += delta
	if _flareopt and (_wt > 3.5 or out_path != "") and not _flare_done:
		_flare_done = true
		inv.add('flare', 1)
		_throw_flare()
	if _mash and player.struggling:
		_mash_t += delta
		if _mash_t > 0.125:
			_mash_t = 0.0
			player.struggle_press()
	if _wolves_spawned_for_test == false:
		_wolves_spawned_for_test = true
		var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
		var wp := player.position + fwd * wolf_test_dist
		wp.y = terrain.data.get_height(wp)
		_add_wolf(wp, 0, _beartest)
		print("WT wolf at dist 22, tier under player ", snow.tier_at(player.position.x, player.position.z))
	if _wt > 1.0 and not _noise_sent:
		_noise_sent = true
		noise_bus.emit_noise(player.position, 40.0, player)
		print("WT noise sent state=", _wt_w().state)
	if int(_wt * 2) != _wt_last:
		_wt_last = int(_wt * 2)
		var w := _wt_w()
		if _wt_last % 2 == 0:
			print("WT strug=%s prog=%.2f" % [str(player.struggling), player.struggle_prog]); print("WT t=%.0f state=%d dist=%.1f speed=%.2f hp=%.0f bites=%d" % [_wt, w.state, w.global_position.distance_to(player.position), w.speed_now, player.health, w.bites])
	if _wt > 26.0 or player.dead:
		print("WOLFTEST done hp=%.0f dead=%s bites=%d" % [player.health, str(player.dead), _wt_w().bites])
		get_tree().quit()


func _wt_w() -> Wolf:
	return bears[0] if _beartest else wolves[0]


var _wolves_spawned_for_test := false
var wolf_test_dist := 22.0
var _noise_sent := false
var _wt_last := -1


var zombies: Array[Zombie] = []
var pop: Population
var _force_death := false
var _zombietest := false
var _zt := 0.0
var _zt_spawned := false
var _zt_noise := false
var _zt_last := -1
var _attack_cd := 0.0
var viewmodel: Viewmodel
var _vmtest := ''
var _opts_vmact := ''
const AXE_DAMAGE := 40.0
const FIST_DAMAGE := 10.0


func _populate(n: int, center: Vector2) -> void:
	if n <= 0:
		return
	var water := MapIO.load_png("res://data/maps/valley_b/water_mask.png")
	water.convert(Image.FORMAT_L8)
	var anchors: Array = []
	for cb in cabins:
		anchors.append(Vector2(cb.global_position.x, cb.global_position.z))
	for hu in huts:
		anchors.append(Vector2(hu.global_position.x, hu.global_position.z))
	for st0 in stores:
		anchors.append(Vector2(st0.global_position.x, st0.global_position.z))
	var rp: Array = []
	if road != null:
		for i in range(0, road.points.size(), 4):
			rp.append(road.points[i])
	pop.generate(n, center, anchors, rp, water)
	pop.prewarm(16)
	var srng := RandomNumberGenerator.new()
	srng.seed = 4242   # sleepers are fixed per map, not per run
	for ci in range(1, cabins.size()):
		if srng.randf() < 0.6:
			pop.add_special(cabins[ci].to_global(Vector3(srng.randf_range(-1.5, 1.5), Cabin.FLOOR_LOCAL_Y, srng.randf_range(-0.8, 1.2))))
	for st1 in stores:
		for _k in 2:
			pop.add_special(st1.to_global(Vector3(srng.randf_range(-2.2, 2.2), Store.FLOOR_LOCAL_Y, srng.randf_range(-1.6, 1.4))))
	for hu in huts:
		if srng.randf() < 0.7:
			pop.add_special(hu.to_global(Vector3(srng.randf_range(-0.9, 0.9), Hut.FLOOR_LOCAL_Y, srng.randf_range(-0.7, 0.7))))


func _new_zombie(p: Vector3, idx: int) -> Zombie:
	p = RefugeBoundary.safe_spawn(p)
	if p.y>-400:p.y=RoadNet.lift(p.y,p.x,p.z)
	var z := Zombie.new()
	add_child(z)
	z.global_position = p
	z.rotation.y = randf() * TAU if idx>=0 else 0.0
	z.setup(terrain, snow, player, forest, colliders, noise_bus, idx)
	zombies.append(z)
	return z


## Real node (pooled). Test/dev spawns are NOT population-owned (never parked).
func _add_zombie(p: Vector3, idx: int) -> Zombie:
	var z := pop.acquire(p, idx)
	if not zombies.has(z):
		zombies.append(z)
	return z

func _attack() -> void:
	if _attack_cd > 0.0 or player.dead or inv == null:
		return
	_act_cancel()
	if rifle_up and inv.count('rifle') > 0:
		_shoot()
		return
	var axe := inv.count("axe") > 0
	_attack_cd = 0.9 if axe else 0.7
	swing_n += 1
	viewmodel.swing(axe)
	var dmg := (AXE_DAMAGE * lerpf(0.5, 1.0, inv.condition("axe")) if axe else FIST_DAMAGE)
	noise_bus.emit_noise(player.position, NoiseBus.RADIUS_AXE if axe else 10.0, player)
	await get_tree().create_timer(0.27 if axe else 0.14).timeout  # damage lands at swing impact, not at click
	if player.dead:
		return
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var best: Node3D = _melee_pick(2.3 if axe else 1.8)
	if best != null:
		best.call("hit", dmg, player.position)
		_hit_feedback(best, false)
		if axe:
			inv.wear("axe", 0.004)   # no-op while god
		audio.hit(best.global_position + Vector3(0, 1.0, 0))
		_say("Hit!")
	else:
		var tr: Dictionary = forest.nearest_tree(player.position, fwd, 2.0, true, _tree_aimed) if axe and forest != null else {}
		if tr.is_empty():
			_say("Swing")
		else:
			_chop_hit(tr)


var test_mouse := false   # tests: pretend the mouse is captured (headless cannot capture)


func _mouse_ok() -> bool:
	return test_mouse or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Buildings with solid walls (bullets and swings stop at them).
func _building_list() -> Array:
	var out: Array = []
	out.append_array(cabins)
	if fire_lookout != null:
		out.append(fire_lookout)
	out.append_array(huts)
	out.append_array(stores)
	out.append_array(outbuildings)
	if collapse!=null and collapse.clinic!=null:out.append(collapse.clinic)
	return out


var swing_n := 0   # melee swings started (tests)
var _lmb_held := false   # LMB went down while the game had the mouse; auto-repeats the attack while held


## Hold left mouse: keep swinging / chopping / firing as soon as the cooldown allows (a click is not required each time).
func _hold_attack() -> void:
	if not _lmb_held:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_lmb_held = false
		return
	if not _mouse_ok() or player.ui_open or player.dead or not _act.is_empty() or _sl_on or get_tree().paused:
		return
	if inv == null or _attack_cd > 0.0:
		return
	if rifle_up and inv.count('rifle') > 0 and inv.count('ammo') == 0 and not player.god:
		return  # do not machine-gun dry clicks
	_attack()


# ---- Storage chest
var chests: Array[StorageChest] = []


func _add_chest(p: Vector3, yaw: float) -> StorageChest:
	var c := StorageChest.new()
	add_child(c)
	c.global_position = p
	c.rotation.y = yaw
	chests.append(c)
	player.chests = chests.duplicate()
	if first_week!=null and first_week.cache!=null:player.chests.append(first_week.cache)
	return c


## N3 forage (ForageNode): rose bushes along the road verges, reishi stumps and fallen
## birch logs back in the timber. Seeded placement, so saves keep only harvested flags.
var forage: Array[ForageNode] = []
const FORAGE_PLAN := [["rose", 16, 8.0, 35.0], ["reishi", 8, 18.0, 70.0], ["birch", 10, 14.0, 60.0]]
func _build_forage(saved: Array) -> void:
	if road == null or road.points.size() < 60 or terrain == null:
		return
	var rng := RandomNumberGenerator.new(); rng.seed = 70417
	var pts := road.points
	for plan: Array in FORAGE_PLAN:
		var placed := 0; var tries := 0
		while placed < int(plan[1]) and tries < 600:
			tries += 1
			var rp: Vector2 = pts[rng.randi_range(20, pts.size() - 21)]
			var a := rng.randf() * TAU
			var p := rp + Vector2(cos(a), sin(a)) * rng.randf_range(float(plan[2]), float(plan[3]))
			if road.is_near(p.x, p.y, 5.0) or road._is_wet(p.x, p.y):
				continue
			var h: float = terrain.data.get_height(Vector3(p.x, 0, p.y))
			if is_nan(h) or not _flat_enough(p, 0.5):
				continue
			if forest != null and forest.resolve_trunks(p.x, p.y, 1.2).distance_to(p) > 0.01:
				continue
			if colliders.any(func(b: Node3D) -> bool: return Vector2(b.global_position.x, b.global_position.z).distance_to(p) < 9.0):
				continue
			if forage.any(func(f: ForageNode) -> bool: return Vector2(f.position.x, f.position.z).distance_to(p) < 25.0):
				continue
			var fn := ForageNode.new(); add_child(fn)
			fn.setup(String(plan[0]), Vector3(p.x, h - 0.04, p.y), rng.randf() * TAU)
			forage.append(fn); placed += 1
			if float(fn.spec().solid) > 0.0:
				player.spatial_structures.append(fn)
	for i in mini(saved.size(), forage.size()):
		forage[i].set_harvested(bool(saved[i]))

func _flat_enough(p: Vector2, tol: float) -> bool:
	var hs: Array = []
	for o: Vector2 in [Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]:
		hs.append(terrain.data.get_height(Vector3(p.x + o.x, 0, p.y + o.y)))
	return not hs.any(func(v: float) -> bool: return is_nan(v)) and float(hs.max()) - float(hs.min()) < tol

func _forage_cands(cands: Array) -> void:
	for fn: ForageNode in forage:
		if fn.harvested:
			continue
		var ap := fn.aim_point()
		if ap.distance_to(player.position) > 3.2 or not _aim_ok(ap, 2.4, 0.6):
			continue
		var sp := fn.spec(); var tool := String(sp.tool)
		var ok := tool == "" or inv.count(tool) > 0
		var txt := String(sp.verb) + ("" if ok else " • needs a %s" % inv.name_of(tool).to_lower())
		cands.append({"m": _lm, "d": ap.distance_to(player.position), "text": txt, "hold": float(sp.hold) if ok else 0.0, "kcal": 8.0, "act": func() -> void: harvest_forage(fn)})

func harvest_forage(fn: ForageNode) -> void:
	if fn.harvested:
		return
	var sp := fn.spec(); var tool := String(sp.tool)
	if tool != "" and inv.count(tool) < 1:
		_say("Need a %s" % inv.name_of(tool).to_lower())
		return
	var n := randi_range(int(sp.n[0]), int(sp.n[1]))
	_give_or_drop(String(sp.item), n, fn.aim_point())
	if tool != "":
		inv.wear(tool, 0.01)
	fn.set_harvested(true)
	audio.play_at("rustle", fn.aim_point(), -8, 1, 3, 18)
	_say("Collected %d %s" % [n, inv.name_of(String(sp.item)).to_lower()])


## Small game: seeded warrens off the road, two hares each; a lost hare is replaced
## (one per warren per game hour) only while the player is far away.
func _build_warrens() -> void:
	if road == null or road.points.size() < 60 or terrain == null:
		return
	var rng := RandomNumberGenerator.new(); rng.seed = 9031
	var tries := 0
	while warrens.size() < 10 and tries < 500:
		tries += 1
		var rp: Vector2 = road.points[rng.randi_range(20, road.points.size() - 21)]
		var a := rng.randf() * TAU
		var p := rp + Vector2(cos(a), sin(a)) * rng.randf_range(18.0, 70.0)
		if road.is_near(p.x, p.y, 8.0) or road._is_wet(p.x, p.y) or not _flat_enough(p, 0.8):
			continue
		if colliders.any(func(b: Node3D) -> bool: return Vector2(b.global_position.x, b.global_position.z).distance_to(p) < 15.0):
			continue
		if warrens.any(func(w: Vector3) -> bool: return Vector2(w.x, w.z).distance_to(p) < 60.0):
			continue
		warrens.append(_ground(p.x, p.y))
	for i in warrens.size():
		for k in 2:
			_add_rabbit(i, 100 * i + k)

func _add_rabbit(warren_i: int, seed_value: int) -> void:
	var w: Vector3 = warrens[warren_i]
	var r := Rabbit.new(); add_child(r)
	r.global_position = _ground(w.x + randf_range(-3, 3), w.z + randf_range(-3, 3))
	r.setup(terrain, snow, player, forest, noise_bus, w, seed_value)
	r.set_meta("warren", warren_i)
	rabbits.append(r)

func _advance_small_game(gs: float) -> void:
	rabbits = rabbits.filter(func(r: Variant) -> bool: return is_instance_valid(r) and not (r as Rabbit).is_dead())
	_rabbit_acc += gs
	if _rabbit_acc >= 3600.0:
		_rabbit_acc = 0.0
		for i in warrens.size():
			var have := rabbits.filter(func(r: Rabbit) -> bool: return int(r.get_meta("warren", -1)) == i).size()
			if have < 2 and warrens[i].distance_to(player.position) > 90.0:
				_add_rabbit(i, randi())
	for s: Snare in snares:
		s.advance(gs, nearest_warren(s.position))

func nearest_warren(p: Vector3) -> float:
	var best := INF
	for w: Vector3 in warrens:
		best = minf(best, Vector2(w.x - p.x, w.z - p.z).length())
	return best

func _add_snare(pos: Vector3, yaw: float, saved: Dictionary = {}) -> Snare:
	var s := Snare.new(); add_child(s); s.setup(pos, yaw, snares.size() * 7 + 3)
	if not saved.is_empty():
		s.condition = float(saved.get("cond", 1.0)); s._acc = float(saved.get("acc", 0.0)); s.set_caught(bool(saved.get("caught", false)))
	snares.append(s)
	return s

func _snare_cands(cands: Array) -> void:
	for s: Snare in snares:
		if not is_instance_valid(s):
			continue
		var sp := s.point()
		if sp.distance_to(player.position) > 3.0 or not _aim_ok(sp, 2.4, 0.6):
			continue
		if s.caught:
			cands.append({"m": _lm, "d": sp.distance_to(player.position), "text": "Take rabbit from the snare", "hold": 1.5, "act": func() -> void: _snare_take(s)})
		else:
			cands.append({"m": _lm, "d": sp.distance_to(player.position), "text": "Snare set (%d%%) • take it down" % int(s.condition * 100.0), "hold": 1.5, "act": func() -> void: _snare_remove(s)})

func _snare_take(s: Snare) -> void:
	_say(s.take(inv))
	if s.condition <= 0.0:
		_give_or_drop("stick", 2, s.point()); snares.erase(s); s.queue_free()

func _snare_remove(s: Snare) -> void:
	_give_or_drop("stick", 2, s.point())
	if s.condition >= 0.5:
		_give_or_drop("cordage", 1, s.point())
	snares.erase(s); s.queue_free()
	_say("Took down the snare")


## Where a chest would go: 1.4 m ahead on the surface you stand on, not on top of another chest.
func _chest_site() -> Dictionary:
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var p := player.position + fwd * 1.4
	var h: float = player.ground_at(p.x, p.z)
	if is_nan(h):
		h = player.position.y - player.eye_h
	if absf(h - (player.position.y - player.eye_h)) > 0.8:
		return {'ok': false, 'msg': 'Too steep here'}
	var pos := Vector3(p.x, h, p.z)
	for c in chests:
		if is_instance_valid(c) and c.global_position.distance_to(pos) < 1.1:
			return {'ok': false, 'msg': 'Too close to another chest'}
	if forest != null:
		var q: Vector2 = forest.resolve_trunks(p.x, p.z, 0.5)
		if q.distance_to(Vector2(p.x, p.z)) > 0.05:
			return {'ok': false, 'msg': 'A tree is in the way'}
	return {'ok': true, 'pos': pos, 'yaw': player.yaw}


func _chest_cands(cands: Array) -> void:
	for chx in chests:
		var ch: StorageChest = chx
		if not is_instance_valid(ch):
			continue
		var cp := ch.center_world()
		if not _aim_ok(cp, 2.6, 0.7):
			continue
		var cdd := (cp - player.position).length()
		cands.append({"m": _lm, "d": cdd - 0.2, "text": "Open chest (%d stacks)" % ch.stack_count(), "act": func() -> void: gear.open_chest(ch)})
		cands.append({"m": _lm, "d": cdd + 0.05, "text": "Turn chest", "act": func() -> void:
			ch.rotate_quarter()
			if audio != null:
				audio.play_at("thud", ch.global_position, -8.0, randf_range(0.9, 1.1), 3.0, 30.0)})
		if not ch.is_empty():
			cands.append({"m": _lm, "d": cdd + 0.2, "text": "Chest holds %d stacks (empty it to dismantle)" % ch.stack_count(), "act": func() -> void: _say("Empty the chest first")})
		if ch.is_empty():
			cands.append({"m": _lm, "d": cdd + 0.1, "text": "Dismantle chest (+4 planks, +4 nails)", "hold": 4.0, "kcal": 6.0, "noise": 14.0, "act": func() -> void: _dismantle_chest(ch)})


func _dismantle_chest(c: StorageChest) -> void:
	if not is_instance_valid(c) or not c.is_empty():
		return
	chests.erase(c)
	c.queue_free()
	_give_or_drop('plank', 4, player.position)
	_give_or_drop('nails', 4, player.position)
	_say('Chest dismantled (+4 planks, +4 nails)')


func chest_put(c: StorageChest, id: String, n: int) -> void:
	if inv == null or not is_instance_valid(c):
		return
	var have := inv.count(id) - (1 if inv.is_worn(id) else 0)
	n = mini(n, have)
	if n <= 0:
		_say('Take it off first' if inv.is_worn(id) else 'Nothing to store')
		return
	if not c.can_hold(id):
		_say('The chest is full')
		return
	if id == 'rifle' and n >= inv.count(id):
		rifle_up = false
	var cd := inv.condition(id)
	var ag := float(inv.age.get(id, 0.0))
	if not inv.remove(id, n):
		return
	c.put(id, n, cd, ag)
	if Inventory.is_rifle(id): c.put_states(id, inv.last_removed_states)
	_say('Stored %s%s' % [inv.name_of(id), ' x%d' % n if n > 1 else ''])


func chest_take(c: StorageChest, id: String, n: int) -> void:
	if inv == null or not is_instance_valid(c):
		return
	n = mini(n, c.count(id))
	while n > 0 and not inv.can_add(id, n):
		n -= 1
	if n <= 0:
		_say('Your pack is full' if c.count(id) > 0 else 'Nothing there')
		return
	var had := inv.count(id)
	var cur_c := inv.condition(id)
	var cur_a := float(inv.age.get(id, 0.0))
	var c_c := float(c.cond.get(id, 1.0))
	var c_a := float(c.age.get(id, 0.0))
	inv.add(id, n, c.take_states(id, n) if Inventory.is_rifle(id) else [])
	c.remove(id, n)
	if c_c < 0.999 or cur_c < 0.999:
		inv.cond[id] = (cur_c * had + c_c * n) / float(had + n)
	if Inventory.shelf_s(id) > 0.0:
		inv.age[id] = (cur_a * had + c_a * n) / float(had + n)
	_say('Took %s%s' % [inv.name_of(id), ' x%d' % n if n > 1 else ''])


func _restore_chests(lst: Array) -> void:
	for c in chests:
		if is_instance_valid(c):
			c.queue_free()
	chests.clear()
	for d: Dictionary in lst:
		var ch := _add_chest(Vector3(float(d['x']), float(d['y']), float(d['z'])), float(d.get('yaw', 0.0)))
		ch.load_dict(d)


## Melee target: a fan of rays from the camera (what the crosshair is over), then the old flat cone as a safety net
## so a swing at anything adjacent in front of you cannot whiff.
func _melee_pick(reach: float) -> Node3D:
	var origin := player.cam.global_position
	var cb := player.cam.global_transform.basis
	var best: Node3D = null
	var bt := INF
	for off: Vector2 in [Vector2(0, 0), Vector2(0.1, 0), Vector2(-0.1, 0), Vector2(0, 0.1), Vector2(0, -0.12), Vector2(0.18, -0.1), Vector2(-0.18, -0.1), Vector2(0, -0.3)]:
		var d := (cb * Vector3(off.x, off.y, -1.0)).normalized()
		var r := HitZones.trace(get_tree(), terrain, forest, origin, d, reach, ['hostile','resident'], _building_list())
		if r.has('node') and float(r['t']) < bt:
			bt = float(r['t'])
			best = r['node']
	if best != null:
		return best
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var bd := reach
	for h in get_tree().get_nodes_in_group('hostile')+get_tree().get_nodes_in_group('resident'):
		var n := h as Node3D
		if n == null or (n.has_method('is_dead') and n.call('is_dead')):
			continue
		var to := n.global_position - player.position
		to.y = 0.0
		var dd := to.length()
		if dd < bd and (dd < 0.7 or fwd.dot(to / maxf(dd, 0.001)) > 0.5):
			bd = dd
			best = n
	return best


func _hit_feedback(n: Node3D, head: bool) -> void:
	hud.hit_ms = Time.get_ticks_msec()
	hud.hit_head = head
	hud.hit_kill = n.has_method('is_dead') and bool(n.call('is_dead'))


## Shot direction: camera forward + random cone. Hip fire is loose, aimed is tight, moving/sprinting widens it.
func _shot_dir() -> Vector3:
	var cb := player.cam.global_transform.basis
	var deg := lerpf(2.2, 0.12, player.aim_k)
	deg *= 0.7 if player.crouching else 1.0
	deg += minf(player._vel.length(), 6.0) * lerpf(0.35, 0.12, player.aim_k)
	var zr := Vector2.ZERO
	if inv != null and inv.rifle_id() != '':
		var rid := inv.rifle_id()
		deg *= RifleDB.value(rid, 'spread', 1.0) * float(RifleDB.muzzle(rid).get('spread_mult', 1.0))
		if RifleDB.is_v3(rid): zr = inv.zero_of(rid) * 0.001   # sight not zeroed: the bullet lands off the dot / reticle
	var sp := deg_to_rad(deg)
	var ang := randf() * TAU
	var rad := sqrt(randf()) * sp
	return (cb * Vector3(cos(ang) * rad + zr.x, sin(ang) * rad + zr.y, -1.0)).normalized()


func _zombietest_step(delta: float) -> void:
	_zt += delta
	if not _zt_spawned:
		_zt_spawned = true
		inv = Inventory.new(body)
		inv.add("axe")
		var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
		var zp := player.position + fwd * wolf_test_dist
		zp.y = terrain.data.get_height(zp)
		var z := _add_zombie(zp, 1)
		print("ZT zombie at dist %.0f, tier at zombie %d, tier at player %d" % [wolf_test_dist, snow.tier_at(zp.x, zp.z), snow.tier_at(player.position.x, player.position.z)])
	if _zt > 1.0 and not _zt_noise:
		_zt_noise = true
		noise_bus.emit_noise(player.position, 40.0, player)
	var z0: Zombie = zombies[0]
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if z0.state != Zombie.State.DEAD and z0.global_position.distance_to(player.position) < 2.2:
		_attack()
	if int(_zt) != _zt_last:
		_zt_last = int(_zt)
		if _zt_last % 2 == 0:
			print("ZT t=%d state=%d dist=%.1f speed=%.2f hp=%.0f zhp=%.0f grabs=%d" % [_zt_last, z0.state, z0.global_position.distance_to(player.position), z0.speed_now, player.health, z0.hp, z0.grabs])
	if _zt > 60.0 or player.dead or z0.state == Zombie.State.DEAD:
		print("ZOMBIETEST done php=%.0f zombie_dead=%s grabs=%d" % [player.health, str(z0.state == Zombie.State.DEAD), z0.grabs])
		print("ZOMBIETEST failures=", 0 if (z0.state == Zombie.State.DEAD and not player.dead) else 1)
		get_tree().quit()


var needs := Needs.new()
var rifle_up := false
var deer: Array[Deer] = []
var _deertest := false
var _dt := 0.0
var _dt_spawned := false
var _dt_last := -1
const RIFLE_DAMAGE := 100.0
var _shot_damage := RIFLE_DAMAGE   # damage of the rifle that fired the last bullet (RifleDB)
var _reload_t := 0.0                # >0 while a reload is running
var _reload_full := false


## Fill the equipped rifle from loose ammo. Magazine rifles swap in one go (tactical / empty clip);
## the lever rifle is loaded round by round. Tests (autostart) finish instantly.
func _start_reload() -> void:
	if inv == null or player.dead or _reload_t > 0.0 or not rifle_up: return
	var rid := inv.rifle_id()
	if rid == '': return
	var cap := RifleDB.mag(rid)
	var have := inv.rifle_loaded()
	if have >= mini(cap, inv.count('ammo')):
		_say('Magazine full' if inv.count('ammo') > 0 else 'No ammo')
		return
	var single := String(RifleDB.spec(rid).get('reload', 'magazine')) == 'single'
	var clip := 'reload_insert' if single else ('reload_tactical' if have > 0 else 'reload_empty')
	var dur: float = viewmodel._rifle.clip_length(clip) if viewmodel != null and viewmodel._rifle != null else 2.4
	if single: dur = maxf(dur, .9) * float(mini(cap, inv.count('ammo')) - have) * .6 + .5
	if viewmodel != null: viewmodel.play_weapon_clip(clip)
	_reload_t = 0.001 if instant_bullets else dur
	_say('Reloading %s' % inv.name_of(rid))


func _reload_update(delta: float) -> void:
	if _reload_t <= 0.0: return
	if not rifle_up or player.dead or inv.rifle_id() == '':
		_reload_t = 0.0; return
	_reload_t -= delta
	if _reload_t <= 0.0:
		_reload_t = 0.0
		inv.set_loaded(mini(RifleDB.mag(inv.rifle_id()), inv.count('ammo')))
		noise_bus.emit_noise(player.position, 8.0, player)


func _spawn_deer(n: int, center: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var made := 0
	var tries := 0
	while made < n and tries < 300:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(60.0, 260.0)
		var x := center.x + cos(a) * r
		var z := center.y + sin(a) * r
		if absf(x) > 950.0 or absf(z) > 950.0:
			continue
		var h: float = terrain.data.get_height(Vector3(x, 0, z))
		if is_nan(h):
			continue
		_add_deer(Vector3(x, h, z), made)
		made += 1

func _spawn_route_deer(n:int) -> void:
	# The old spawn was centered on the ground cabin, almost a kilometre from
	# the lookout assignment. Seed natural prey in two off-trail habitat areas.
	var path:Array=fire_lookout.site.path.points_world_xyz
	if path.size()<3:return
	var rng:=RandomNumberGenerator.new();rng.seed=opening_state.seed_value+31
	var made:=0
	for attempt in 500:
		if made>=n:break
		var index:=clampi(int(path.size()*(.34 if made%2==0 else .72)),1,path.size()-2)
		var row:Array=path[index];var prev:Array=path[index-1];var next:Array=path[index+1]
		var along:=Vector2(next[0]-prev[0],next[2]-prev[2]).normalized()
		var side:=Vector2(-along.y,along.x)*(1.0 if rng.randf()<.5 else -1.0)
		var point:=Vector2(row[0],row[2])+side*rng.randf_range(45,135)+along*rng.randf_range(-75,75)
		if absf(point.x)>950 or absf(point.y)>950:continue
		if point.distance_to(Vector2(fire_lookout.position.x,fire_lookout.position.z))<80:continue
		var height:float=terrain.data.get_height(Vector3(point.x,0,point.y))
		if is_nan(height) or not is_nan(ice.ice_at(point.x,point.y)):continue
		var grade:=0.0
		for axis:Vector2 in [Vector2(2,0),Vector2(-2,0),Vector2(0,2),Vector2(0,-2)]:
			var sampled:float=terrain.data.get_height(Vector3(point.x+axis.x,0,point.y+axis.y))
			if is_nan(sampled):grade=INF;break
			grade=maxf(grade,absf(sampled-height)/2)
		if grade>.50:continue
		if forest!=null:point=forest.resolve_trunks(point.x,point.y,.65)
		var p:=_ground(point.x,point.y)
		_add_deer(p,3000+made);made+=1
	print("OPENING_PREY spawned=",made," requested=",n," seed=",opening_state.seed_value)


func _add_deer(p: Vector3, idx: int) -> Deer:
	if p.y>-400:p.y=RoadNet.lift(p.y,p.x,p.z)
	var d := Deer.new()
	add_child(d)
	d.global_position = p
	d.setup(terrain, snow, player, forest, noise_bus, 2000 + idx)
	deer.append(d)
	return d


## Six of the eight rifles lie in the world on a fresh game (two more only in fishing-hut crates).
## Pickups are saved like any dropped item, so they are placed once and never duplicated on load.
func _place_rifle_caches() -> void:
	var spots: Array = []
	if cabins.size() > 1: spots.append(['ranger_box_rifle', cabins[1].to_global(Vector3(2.2, Cabin.FLOOR_LOCAL_Y + .01, .3))])
	if cabins.size() > 3: spots.append(['brush_lever_rifle', cabins[3].to_global(Vector3(2.2, Cabin.FLOOR_LOCAL_Y + .01, .3))])
	if cabins.size() > 2: spots.append(['timber_bolt_carbine', cabins[cabins.size() - 1].to_global(Vector3(2.2, Cabin.FLOOR_LOCAL_Y + .01, .3))])
	if not stores.is_empty(): spots.append(['north_service_rifle', (stores[0] as Store).loot_world_pos(0)])
	if not huts.is_empty(): spots.append(['ridge_scout_rifle', (huts[0] as Hut).tackle_world_pos() + Vector3(.35, .01, .35)])
	if huts.size() > 1: spots.append(['expedition_rifle', (huts[huts.size() - 1] as Hut).tackle_world_pos() + Vector3(.35, .01, .35)])
	for s: Array in spots:
		var pickup:=ItemPickup.spawn(self, String(s[0]), 1, s[1] as Vector3)
		if pickup.id=="north_service_rifle" and not stores.is_empty():(stores[0] as Store).support_rifle(pickup)
	print('RIFLE_CACHES ', spots.map(func(s: Array) -> String: return String(s[0])))
	if cabins.size() > 1:   # leather work gloves on a cabin floor (W7): hands you can keep a trigger finger in
		ItemPickup.spawn(self, 'work_gloves', 1, cabins[1].to_global(Vector3(1.4, Cabin.FLOOR_LOCAL_Y + .01, -.6)))


func _shoot() -> void:
	if _reload_t > 0.0:
		return
	var rid := inv.rifle_id()
	if inv.count('ammo') == 0 and not player.god:
		_attack_cd = 0.4
		viewmodel.dry()
		_say('Click. No ammo')
		return
	if inv.rifle_loaded() <= 0 and not player.god:
		_start_reload()   # empty magazine with rounds in the pack: reload instead of firing
		return
	var ld := inv.rifle_loaded()
	inv.remove('ammo')   # no-op while god (Inventory.infinite)
	if not player.god: inv.set_loaded(ld - 1)
	_shot_damage = RifleDB.value(rid, 'damage', RIFLE_DAMAGE)
	_attack_cd = RifleDB.value(rid, 'cycle_s', 1.2)
	viewmodel.flash_mult = _flash_mult(rid)
	viewmodel.fire()
	noise_bus.emit_noise(player.position, NoiseBus.RADIUS_GUNSHOT * RifleDB.value(rid, 'noise', 1.0) * float(RifleDB.muzzle(rid).get('noise_mult', 1.0)), player)
	audio.gunshot(rid)
	var eye := player.cam.global_position
	var dir := _shot_dir()
	_bullet_crack = RifleDB.moderated(rid) and RifleDB.supersonic(rid)
	player.pitch += lerpf(0.022, 0.014, player.aim_k) * RifleDB.value(rid, 'recoil', 1.0)  # recoil kick, player pulls it back down
	player.yaw += randf_range(-0.004, 0.004)
	_spawn_bullet(eye, dir)


# ---- Ballistics: a real projectile (muzzle speed + gravity), rifle zeroed at ZERO_M. Resolved a few metres per
# frame so a moving target can walk out of the way. Tests resolve the whole flight inside the shot.
const MUZZLE_V := 760.0
const ZERO_M := 100.0
const GRAV := 9.8
const BULLET_RANGE := 600.0
var bullets: Array = []
var instant_bullets: bool = "autostart" in OS.get_cmdline_user_args()


## Muzzle flash strength: a moderator traps it, a brake throws it sideways (bigger, brighter).
func _flash_mult(rid: String) -> float:
	if RifleDB.moderated(rid): return 0.0
	return 1.4 if RifleDB.report_class(rid) == 'magnum_brake' else 1.0

## A moderated SUPERSONIC bullet still cracks along its path (the can only quiets the muzzle). Zombies near the
## path hear the crack and go to look THERE: the real misdirection of a suppressed rifle. (An open shot's blast
## carries 150 m and points straight back at you, so it gets no crack events.)
const CRACK_EVERY_M := 25.0
const CRACK_R := 20.0
const CRACK_TO_M := 160.0
const IMPACT_R := 10.0
var _bullet_crack := false
var crack_log: Array = []   # tests: where the last bullet cracked

func _spawn_bullet(eye: Vector3, dir: Vector3) -> void:
	var d := dir
	var rt := dir.cross(Vector3.UP)
	if rt.length() > 0.01:
		d = dir.rotated(rt.normalized(), 0.5 * GRAV * ZERO_M / (MUZZLE_V * MUZZLE_V))
	var b := {'p': eye, 'v': d * MUZZLE_V, 'dist': 0.0, 't': 0.0, 'crack': _bullet_crack, 'next_crack': CRACK_EVERY_M}
	crack_log = []
	_bullet_crack = false
	if instant_bullets:
		var res := {}
		while res.is_empty():
			res = _step_bullet(b, 0.01)
		_bullet_result(res)
	else:
		bullets.append(b)


## Advance one bullet by dt. {} while still flying, else the HitZones result / {'gone': true}.
func _step_bullet(b: Dictionary, dt: float) -> Dictionary:
	var p0: Vector3 = b['p']
	var v: Vector3 = b['v']
	v.y -= GRAV * dt
	var seg := v * dt
	var sl := seg.length()
	var r := HitZones.trace(get_tree(), terrain, forest, p0, seg / sl, sl, ['hostile', 'prey','resident'], _building_list())
	var d0 := float(b['dist'])
	b['v'] = v
	b['p'] = p0 + seg
	b['dist'] = d0 + sl
	b['t'] = float(b['t']) + dt
	while bool(b.get('crack', false)) and float(b['dist']) >= float(b['next_crack']) and float(b['next_crack']) <= CRACK_TO_M:
		var cp: Vector3 = p0 + (seg / sl) * (float(b['next_crack']) - d0)
		if noise_bus != null: noise_bus.emit_noise(cp, CRACK_R, null)
		crack_log.append(cp)
		b['next_crack'] = float(b['next_crack']) + CRACK_EVERY_M
	if not r.is_empty():
		r['pos'] = p0 + (seg / sl) * float(r.get('t', 0.0))
		r['t'] = d0 + float(r.get('t', 0.0))
		r['flight'] = float(b['t'])
		return r
	if float(b['dist']) > BULLET_RANGE or (b['p'] as Vector3).y < -80.0:
		return {'gone': true, 't': float(b['dist'])}
	return {}


func _bullets_update(delta: float) -> void:
	if bullets.is_empty():
		return
	var steps := maxi(1, ceili(delta / 0.02))
	var dt := delta / float(steps)
	for b in bullets.duplicate():
		var res := {}
		for i in steps:
			res = _step_bullet(b, dt)
			if not res.is_empty():
				break
		if not res.is_empty():
			bullets.erase(b)
			_bullet_result(res)


func _bullet_result(r: Dictionary) -> void:
	if r.has('node') and is_instance_valid(r['node']):
		var n: Node3D = r['node']
		var head := String(r['zone']) == 'head'
		n.call('hit', _shot_damage * float(r['mult']), player.position)
		audio.hit(n.global_position + Vector3(0, 1.0, 0))
		_hit_feedback(n, head)
		_impact_fx('flesh', r.get('pos', n.global_position + Vector3(0, 1.2, 0)))
		_say('Headshot!' if head else 'Shot hit (%s)' % String(r['zone']))
		last_shot = {'hit': true, 'zone': r['zone'], 't': r['t'], 'flight': r.get('flight', 0.0)}
	elif r.has('world'):
		if r.has('pos'):
			var ip: Vector3 = r['pos']
			var soft := ip.y - _ground_y(ip.x, ip.z) < 0.6
			_impact_fx('snow' if soft else 'wood', ip)
			if audio != null: audio.play_at('thud' if soft else 'chop', ip, -10.0 if soft else -4.0, randf_range(1.25, 1.45) if soft else randf_range(1.05, 1.2), 6.0, 120.0)
			if noise_bus != null: noise_bus.emit_noise(ip, IMPACT_R * (0.6 if soft else 1.0), null)   # the thwack where it lands
		_say('Bang. Hit the terrain')
		last_shot = {'hit': false, 'world': true, 't': r['t']}
	else:
		_say('Bang. Miss')
		last_shot = {'hit': false, 't': 0.0}


## Puff where a bullet lands: red droplets in flesh, snow kicked up from the ground, splinters from walls / trunks.
func _impact_fx(kind: String, pos: Vector3) -> void:
	var ps := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match kind:
		'flesh':
			m.albedo_color = Color(0.55, 0.04, 0.04)
			ps.amount = 12
			ps.initial_velocity_min = 1.0
			ps.initial_velocity_max = 3.0
		'snow':
			m.albedo_color = Color(0.92, 0.94, 1.0)
			ps.amount = 20
			ps.initial_velocity_min = 1.5
			ps.initial_velocity_max = 4.0
		_:
			m.albedo_color = Color(0.45, 0.32, 0.2)
			ps.amount = 10
			ps.initial_velocity_min = 2.0
			ps.initial_velocity_max = 5.0
	sm.material = m
	ps.mesh = sm
	ps.one_shot = true
	ps.explosiveness = 1.0
	ps.lifetime = 0.55
	ps.direction = Vector3.UP
	ps.spread = 70.0
	ps.gravity = Vector3(0, -9.0, 0)
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ps)
	ps.global_position = pos
	ps.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(ps):
			ps.queue_free())


var last_shot := {}
var aim_override := false  # tests hold the rifle aimed


func _deertest_step(delta: float) -> void:
	_dt += delta
	if not _dt_spawned:
		_dt_spawned = true
		inv = Inventory.new(body)
		inv.needs = needs
		inv.add('rifle')
		inv.add('ammo', 3)
		inv.add('knife')
		rifle_up = true
		aim_override = true
		var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
		var dp := player.position + fwd * 40.0
		dp.y = terrain.data.get_height(dp)
		_add_deer(dp, 1)
		player.pitch = deg_to_rad(0.0)
		print('DT deer at 40m')
	var d0: Deer = deer[0]
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _dt > 2.0 and d0.state != Deer.State.DEAD and _attack_cd <= 0.0 and inv.count('ammo') > 0:
		var to := d0.global_position + Vector3(0, 0.9, 0) - player.cam.global_position
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		_attack()
	if int(_dt) != _dt_last:
		_dt_last = int(_dt)
		print('DT t=%d state=%d dist=%.1f hp=%.0f ammo=%d' % [_dt_last, d0.state, d0.global_position.distance_to(player.position), d0.hp, inv.count('ammo')])
	if d0.state == Deer.State.DEAD and _dt > 3.0:
		player.position = d0.global_position + Vector3(1.0, 0.0, 0.0)
		player.yaw = PI * 0.5   # face the carcass (-x)
		player.pitch = 0.0
		_update_prompt()
		print('DEERTEST prompt=[%s]' % hud.prompt)
		if _cur.has('act'):
			(_cur['act'] as Callable).call()
		print('DEERTEST venison_raw=%d ammo=%d' % [inv.count('venison_raw'), inv.count('ammo')])
		for c2 in _cands_cache.duplicate():
			var tx := String(c2['text'])
			if tx.begins_with('Skin') or tx.begins_with('Gut'):
				(c2['act'] as Callable).call()
		print('DEERTEST hide=%d gut=%d knife_cond=%.2f' % [inv.count('deer_hide'), inv.count('gut'), inv.condition('knife')])
		var cal0 := needs.calories
		needs.calories = 500.0
		print('DEERTEST eat: ', inv.use('venison_raw'), ' cal ', needs.calories)
		print('DEERTEST failures=', 0 if (inv.count('venison_raw') >= 1 and inv.count('deer_hide') == 1 and inv.count('gut') == 1) else 1)
		get_tree().quit()
	elif _dt > 40.0:
		print('DEERTEST timeout state=%d' % d0.state)
		print('DEERTEST failures=1')
		get_tree().quit()

var campfires: Array[Campfire] = []
var _fire_cue_t := 0.0


var drill_chance := 0.7
var craft_job: Dictionary = {}   # {r, t, hp, pos}


func _fire_fuel_plan() -> Dictionary:
	if inv.count('wood') >= 2:
		return {'wood': 2, 'kindling': 0}
	if inv.count('wood') >= 1 and inv.count('kindling') >= 2:
		return {'wood': 1, 'kindling': 2}
	return {}


func _fire_site() -> Dictionary:
	if fire_lookout != null and fire_lookout.contains_room(player.position):
		return {"ok":false,"msg":"Use the lookout stove indoors"}
	for cb in cabins:
		if cb.contains_xz(player.position.x, player.position.z):
			return {'ok': false, 'msg': 'Not indoors. Use the stove'}
	for sb: Node in _stove_buildings():
		if bool(sb.call("contains_xz", player.position.x, player.position.z)):
			return {'ok': false, 'msg': 'Not indoors. Use the stove'}
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var p := player.position + fwd * 1.6
	var h: float = terrain.data.get_height(Vector3(p.x, 0, p.z))
	if is_nan(h):
		return {'ok': false, 'msg': 'No ground here'}
	for cf in campfires:
		if cf.global_position.distance_to(p) < 2.0:
			return {'ok': false, 'msg': 'Too close to another fire'}
	return {'ok': true, 'pos': Vector3(p.x, h, p.z)}


func _build_campfire() -> void:
	if player.dead:
		return
	var site: Dictionary = _fire_site()
	if not site['ok']:
		_say(String(site['msg']))
		return
	var plan: Dictionary = _fire_fuel_plan()
	if plan.is_empty():
		_say('Campfire needs 2 firewood (or 1 firewood + 2 kindling)')
		return
	if inv.count('matches') >= 1:
		var st: Dictionary = FireSource.try_start(inv, fire_start_ctx(site['pos'], int(plan['kindling']) > 0))
		if not bool(st.ok):
			inv.remove('matches')
			_say(String(st.msg) + ' Match used, the wood is still in your pack.')
			return
		_place_campfire(site['pos'], plan, true)
	elif inv.count('bow_drill') >= 1 and inv.count('tinder') >= 1:
		_act_begin({'text': 'Bow drill fire', 'label': 'Bow drill', 'hold': 12.0, 'kcal': 40.0, 'act': func() -> void: _drill_fire()})
	else:
		_say('Need a match, or a bow drill + tinder')


func _drill_fire() -> void:
	var site: Dictionary = _fire_site()
	var plan: Dictionary = _fire_fuel_plan()
	if not site['ok'] or plan.is_empty() or inv.count('bow_drill') < 1 or not inv.remove('tinder'):
		_say('Cannot make a fire here')
		return
	var dctx := fire_start_ctx(site['pos'], int(plan['kindling']) > 0)
	dctx['base'] = drill_chance; dctx['tinder'] = false  # tinder is the drill's requirement, already spent
	var dch := FireSource.start_chance(dctx) if drill_chance > 0.0 and drill_chance < 1.0 else drill_chance  # 0 / 1 = dev-forced outcome
	if randf() < dch:
		inv.wear('bow_drill', 0.08)
		_place_campfire(site['pos'], plan, false)
	else:
		inv.wear('bow_drill', 0.04)
		_say('The ember dies. Try again (tinder used up)')


func _place_campfire(p: Vector3, plan: Dictionary, use_match: bool) -> void:
	inv.remove('wood', int(plan['wood']))
	if int(plan['kindling']) > 0:
		inv.remove('kindling', int(plan['kindling']))
	if use_match:
		inv.remove('matches')
	var cf := Campfire.new()
	add_child(cf)
	cf.global_position = p
	cf.fuel_s = cf.fire.burn_s('wood') * float(plan['wood']) + cf.fire.burn_s('kindling') * float(plan['kindling'])
	campfires.append(cf)
	_say('Built a campfire')


func _cook_start(cf: Campfire) -> int:
	var n := 0
	while cf.is_lit() and cf.free_slots() > 0:
		var before: int = cf.fire.cooking.portions.size()
		cf.fire.cooking.begin(inv, true)
		if cf.fire.cooking.portions.size() == before:
			break
		n += 1
	return n


func _take_cooked(cf: Campfire) -> void:
	var taken: int = cf.fire.cooking.collect(inv)
	_say('Collected %d fire portions. Uncollected food stays by the fire.' % taken)


func _near_fire() -> bool:
	if opening!=null and opening.fire.is_lit() and fire_lookout.contains_room(player.position):return true  # same rule as cabins: lit stove, same room
	for cf in campfires:
		if cf.is_lit() and cf.global_position.distance_to(player.position) < 4.0:
			return true
	for cb in cabins:
		if cb.is_lit() and cb.contains_xz(player.position.x, player.position.z):
			return true
	for sb: Node in _stove_buildings():
		if (sb.get("stove") as Stove).fire.is_lit() and bool(sb.call("contains_xz", player.position.x, player.position.z)):
			return true
	return false


## Huts and stores carry a placed Stove (fire standard F5).
func _stove_buildings() -> Array:
	var out: Array = []
	for h in huts:
		if h.get("stove") != null: out.append(h)
	for s in stores:
		if s.get("stove") != null: out.append(s)
	out.append_array(greenhouses)
	return out


# ---- crafting jobs (timed, interruptible; started from the Gear screen Craft tab)
func craft_start(rid: String) -> String:
	if inv == null or player.dead:
		return 'Cannot craft now'
	if not craft_job.is_empty():
		return 'Already crafting'
	var r: Dictionary = RecipeDB.get_recipe(rid)
	if r.is_empty():
		return 'Unknown recipe'
	var why := RecipeDB.blocked(inv, r, _near_fire())
	if why != '':
		_say(why)
		return why
	if r.has('place') and not bool(_chest_site()['ok']):
		var why2 := String(_chest_site()['msg'])
		_say(why2)
		return why2
	craft_job = {'r': r, 't': 0.0, 'hp': player.health, 'pos': player.position}
	return ''


func craft_cancel(msg := '') -> void:
	craft_job = {}
	if msg != '':
		_say(msg)


func _craft_update(delta: float) -> void:
	if craft_job.is_empty():
		return
	var moved := Vector2(player.position.x - craft_job['pos'].x, player.position.z - craft_job['pos'].z).length() > 0.8
	if player.dead or player.struggling or moved or player.health < float(craft_job['hp']) - 0.01:
		craft_cancel('Crafting interrupted')
		return
	craft_job['t'] = float(craft_job['t']) + delta
	var r: Dictionary = craft_job['r']
	if float(craft_job['t']) < float(r['time_s']):
		return
	craft_job = {}
	var why := RecipeDB.blocked(inv, r, _near_fire())
	if why != '':
		_say(why)
		return
	var csite: Dictionary = {}
	if r.has('place'):
		csite = _chest_site()
		if not bool(csite['ok']):
			_say(String(csite['msg']))
			return
	for id in r['inputs'].keys():
		inv.remove(String(id), int(r['inputs'][id]))
	for tl in r.get('tools', []):
		_wear_tool(String(tl), 0.01)
	needs.calories = maxf(0.0, needs.calories - float(r.get('kcal', 5.0)))
	if float(r.get('noise', 0.0)) > 0.0:
		noise_bus.emit_noise(player.position, float(r['noise']), player)
	var parts: Array = []
	for id in r['out'].keys():
		_give_or_drop(String(id), int(r['out'][id]), player.position)
		parts.append('%d %s' % [int(r['out'][id]), inv.name_of(String(id))])
	if r.has('place') and String(r['place']) == 'snare':
		_add_snare(csite['pos'], float(csite['yaw']))
		parts.append('a set snare' + ('' if nearest_warren(csite['pos']) < 40.0 else ' (no rabbit sign nearby)'))
	elif r.has('place'):
		_add_chest(csite['pos'], float(csite['yaw']))
		parts.append('a storage chest')
	audio.play_at("rustle", player.position, -6.0, 1.0, 4.0, 40.0)
	_say('Crafted: ' + ', '.join(parts))


var _campfire_opt := false


var audio: GameAudio
var pause_menu: PauseMenu
var dev: DevMenu

var opts_pausetest := false
var pause_shot := ''


var _autosave_t := 0.0


# ---- Sleep: lie in a cabin bed. Clock runs fast, body rests, danger/cold/hits wake you. Hordes keep wandering.
const SLEEP_FADE := 1.1
var sleep_rate := 1200.0   # game seconds per real second while asleep (8 h ~ 24 s)
var _sl_on := false
var sleep_last := ''   # why the last sleep ended (tests, HUD)
var _sl: Dictionary = {}


## Room climate (F4): every enclosed building has an air temperature that warms
## with its stove and cools when it goes out or the door stands open.
## Each entry: {climate: RoomClimate, building: Object, inside: Callable(Vector3)->bool}.
var rooms: Array = []
var _rooms_unsettled: Array = []
func _build_rooms(saved: Array) -> void:
	rooms.clear()
	for cb: Cabin in cabins:
		var c := cb
		rooms.append({"climate": RoomClimate.new(6.0, c.fire, 30.0), "building": c, "inside": func(p: Vector3) -> bool: return c.contains_xz(p.x, p.z)})
	for st in stores:
		var s: Node3D = st
		rooms.append({"climate": RoomClimate.new(5.0, s.get("stove").fire if s.get("stove") != null else null, 24.0), "building": s, "inside": func(p: Vector3) -> bool: return s.contains_xz(p.x, p.z)})
	for hb in huts:
		var h: Node3D = hb
		rooms.append({"climate": RoomClimate.new(4.0, h.get("stove").fire if h.get("stove") != null else null, 34.0), "building": h, "inside": func(p: Vector3) -> bool: return h.contains_xz(p.x, p.z)})
	if collapse != null and collapse.clinic != null:
		var cl: Node3D = collapse.clinic
		rooms.append({"climate": RoomClimate.new(5.0), "building": cl, "inside": func(p: Vector3) -> bool: return cl.contains_xz(p.x, p.z)})
	for gb in greenhouses:
		var g: Greenhouse = gb
		var gc := RoomClimate.new(2.0, g.stove.fire, 30.0); gc.solar_c = 12.0; g.room = gc
		rooms.append({"climate": gc, "building": g, "inside": func(p: Vector3) -> bool: return g.contains_xz(p.x, p.z)})
	if opening != null and fire_lookout != null:
		rooms.append({"climate": RoomClimate.new(4.0, opening.fire, 32.0), "building": fire_lookout, "inside": func(p: Vector3) -> bool: return fire_lookout.contains_room(p)})
	_rooms_unsettled.clear()
	for i in rooms.size():
		if saved.size() == rooms.size() and saved[i] is float or (saved.size() == rooms.size() and saved[i] is int):
			(rooms[i].climate as RoomClimate).room_c = float(saved[i])
		else:
			_rooms_unsettled.append(rooms[i].climate)  # settle on the first frame, after fires restore

func _advance_rooms(gs: float) -> void:
	var outside := clock.ambient_c()
	var day := 1.0 - sky_rig.gameplay_night_factor if sky_rig != null else 0.0
	for g: Greenhouse in greenhouses:
		g.light = Farming.light_factor(day, weather.overcast if weather != null else 0.0)
		if g.room != null: g.room.sun = g.light
	for c: RoomClimate in _rooms_unsettled: c.settle(outside)
	_rooms_unsettled.clear()
	for r: Dictionary in rooms:
		var c: RoomClimate = r.climate
		c.leak = RoomClimate.leak_of(r.building)
		c.advance(gs, outside)
	for g: Greenhouse in greenhouses:
		g.advance(gs, g.room.room_c if g.room != null else outside)

func room_at(p: Vector3) -> RoomClimate:
	for r: Dictionary in rooms:
		if (r.inside as Callable).call(p): return r.climate
	return null

func air_at(p: Vector3) -> float:
	var r := room_at(p)
	return r.room_c if r != null else clock.ambient_c()

## Air the body feels: the room's air indoors, the weather outside.
func air_c() -> float:
	var r := room_at(player.position)
	return r.room_c if r != null else clock.ambient_c()


func _sleep_block_reason() -> String:
	if body.core < 35.8:
		return "Too cold to sleep: warm up first"
	if player.injury.bleeding():
		return "Can't sleep while bleeding"
	if opening != null and opening.is_refuge(player.position): return ""
	for h in get_tree().get_nodes_in_group('hostile'):
		var n := h as Node3D
		if n != null and not bool(n.call('is_dead')) and n.global_position.distance_to(player.position) < 45.0:
			return "Can't sleep: something is close"
	if pop != null:
		var nh: Dictionary = pop.nearest_horde(player.position)
		if not nh.is_empty() and float(nh["dist"]) < 90.0:
			return "Can't sleep: a horde is close"
	return ""

func _sleep_items(cb: Node3D) -> Array:
	var bp: Vector3 = cb.call("bed_world_pos")
	var out: Array = []
	var why := _sleep_block_reason()
	if why != "":
		out.append({"pos": bp, "r": 1.9, "text": why, "act": func() -> void: _say(why)})
		return out
	out.append({"pos": bp, "r": 1.9, "text": "Rest on the bed (2 h)", "hold": 1.2, "dbias": 0.0, "act": func() -> void: _sleep_begin(cb, 2.0)})
	out.append({"pos": bp, "r": 1.9, "text": "Sleep (8 h)", "hold": 1.2, "dbias": 0.01, "act": func() -> void: _sleep_begin(cb, 8.0)})
	var h := clock.hour
	if h >= 17.0 or h < 5.0:
		var until := minf(fposmod(6.0 - h, 24.0), 12.0)
		out.append({"pos": bp, "r": 1.9, "text": "Sleep until dawn (06:00)", "hold": 1.2, "dbias": 0.02, "act": func() -> void: _sleep_begin(cb, until)})
	return out


func _sleep_begin(cb: Node3D, hours: float) -> void:
	if _sl_on or player.dead:
		return
	_sl_on = true
	player.sleeping = true
	_sl = {"cb": cb, "hours": hours, "phase": 0, "t": 0.0, "stand": player.position, "pitch": player.pitch, "yaw": player.yaw,
		"scale0": clock.time_scale, "hp0": player.health, "cal0": needs.calories, "water0": needs.water, "hits0": player.hits_taken,
		"chk": 0.0, "armed": false, "start_s": 0.0, "target": 0.0, "msg": ""}


func _sleep_quality() -> float:
	var q := lerpf(1.0,.6,body.wetness)
	if needs.calories < Needs.HUNGRY:
		q *= 0.4
	if needs.water < 45.0:
		q *= 0.6
	if body.core < 36.5:
		q *= 0.5
	if player.injury.symptomatic():
		q = 0.0
	return q


func _sleep_update(delta: float) -> void:
	if player.dead:
		_sleep_restore_clock()
		_sl_on = false
		hud.sleep_fade = 0.0
		hud.sleep_text = ""
		player.sleeping = false
		return
	var cb: Node3D = _sl["cb"]
	_sl["t"] = float(_sl["t"]) + delta
	var t := float(_sl["t"])
	match int(_sl["phase"]):
		0:
			hud.sleep_fade = clampf(t / SLEEP_FADE, 0.0, 1.0)
			if t >= SLEEP_FADE:
				_sl["phase"] = 1
				_sl["t"] = 0.0
				_sl["start_s"] = clock.total_game_s
				_sl["target"] = clock.total_game_s + float(_sl["hours"]) * 3600.0
				player.position = cb.call("bed_lie_pos")
				player.pitch = -0.6
				clock.time_scale = sleep_rate
				needs.rest_mult = 0.75
		1:
			_sleep_tick(delta, cb)
		_:
			hud.sleep_fade = 1.0 - clampf(t / SLEEP_FADE, 0.0, 1.0)
			if t >= SLEEP_FADE:
				hud.sleep_fade = 0.0
				hud.sleep_text = ""
				player.sleeping = false
				_sl_on = false
				if _safe_to_save() and out_path == '':
					save_game()


func _sleep_tick(delta: float, cb: Node3D) -> void:
	if opening != null and not opening.dispatch_for_player(clock.total_game_s).is_empty():
		_sleep_wake("Your personal walkie wakes you: dispatch is calling")
		return
	var gs := delta * sleep_rate
	if opening != null:
		var call_at: float=opening.next_dispatch_wake(clock.total_game_s,clock.total_game_s+gs)
		if is_finite(call_at): gs=call_at-clock.total_game_s
	player.stamina = 100.0
	player.exhausted = false
	player.position = cb.call("bed_lie_pos")
	if pop != null:
		pop.catch_up(maxf(0.0, gs / clock.base_time_scale - delta))
	hud.sleep_text = "Sleeping...  %s     (E to wake)" % clock.time_string()
	var key := Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE)
	if not key:
		_sl["armed"] = true
	var why := ""
	if bool(_sl["armed"]) and key:
		why = "You wake up"
	_sl["chk"] = float(_sl["chk"]) + delta
	if why == "" and float(_sl["chk"]) >= 0.25:
		_sl["chk"] = 0.0
		why = _sleep_wake_reason()
	if why == "" and clock.total_game_s >= float(_sl["target"]):
		why = "You wake rested"
	if why != "":
		_sleep_wake(why)


func _sleep_wake_reason() -> String:
	if player.hits_taken != int(_sl["hits0"]):
		return "Jolted awake: something hurt you"
	if body.core < 35.4:
		return "Woke shivering: too cold"
	if needs.damage_per_s() > 0.0:
		return "Woke: starving or dying of thirst"
	if player.injury.bleeding():
		return "Woke: you are bleeding"
	if opening != null and opening.is_refuge(player.position): return ""
	for h in get_tree().get_nodes_in_group('hostile'):
		var n := h as Node3D
		if n != null and not bool(n.call('is_dead')) and n.global_position.distance_to(player.position) < 30.0:
			return "Woke: something is outside"
	if pop != null:
		var nh: Dictionary = pop.nearest_horde(player.position)
		if not nh.is_empty() and float(nh["dist"]) < 60.0:
			return "Woke: a horde is moaning outside"
	return ""


func _sleep_restore_clock() -> void:
	clock.time_scale = float(_sl.get("scale0", clock.base_time_scale))
	needs.rest_mult = 1.0


func _sleep_wake(why: String) -> void:
	sleep_last = why
	_sleep_restore_clock()
	var hrs := (clock.total_game_s - float(_sl["start_s"])) / 3600.0
	player.position = _sl["stand"]
	player.pitch = float(_sl["pitch"])
	player.yaw = float(_sl["yaw"])
	_sl["phase"] = 2
	_sl["t"] = 0.0
	hud.sleep_text = ""
	_say("%s. Slept %.1f h: +%d health, -%d kcal, -%d water." % [why, hrs, int(player.health - float(_sl["hp0"])), int(float(_sl["cal0"]) - needs.calories), int(float(_sl["water0"]) - needs.water)])

func _safe_to_save() -> bool:
	if player.dead or player.airborne or inv == null or _sl_on:
		return false
	if opening != null and opening.is_refuge(player.position): return true
	for h in get_tree().get_nodes_in_group('hostile'):
		var n := h as Node3D
		if n != null and not bool(n.call('is_dead')) and n.global_position.distance_to(player.position) < 45.0:
			return false
	return true


func save_game() -> bool:
	if inv == null or player.dead or player.airborne or _sl_on:
		return false
	return SaveGame.write(_save_data())


## In-memory snapshot also supports non-destructive save/load verification.
## Dev/test: run the real story clock forward to a calendar beat (day 1 = arrival,
## hour may be fractional). Only the story systems tick (clock, lookout power and
## radio, route, outbreak cohorts, work order); body needs are left as they are.
func story_skip_to(day: int, hour: float) -> bool:
	if opening_state == null or not opening_state.enabled: return false
	var target := opening_state.calendar_s(day, hour)
	if target <= clock.total_game_s + .5: return false
	var pace := clock.time_scale
	clock.time_scale = 1.0
	while clock.total_game_s < target - .001:
		var gs := clock.advance(minf(900.0, target - clock.total_game_s))
		if opening != null: opening.advance(gs)
		if first_week != null: first_week.update(gs)
		if collapse != null: collapse.update(gs)
		if town_life != null: town_life.update(gs)
	clock.time_scale = pace
	sky_rig.apply_hour(clock.hour)
	return true


func _save_data() -> Dictionary:
	var cabs: Array = []
	for cb in cabins:
		cabs.append({'fire': cb.fire.to_dict(), 'broken': cb.broken.duplicate(), 'wood': cb.wood_pile, 'looted': cb.crate_looted, 'door_open': cb.door_open, 'dboards': cb.door_boards, 'open': cb.openings.map(func(op: Opening) -> Dictionary: return op.to_dict())})
	var fires: Array = []
	for cf in campfires:
		fires.append({'x': cf.global_position.x, 'y': cf.global_position.y, 'z': cf.global_position.z, 'fire': cf.fire.to_dict()})
	var d := {
		'clock': clock.to_dict(),
		'weather': weather.to_dict(),
		'route_snow_cover':road.snow_cover,
		'atmosphere': (sky_rig as AtmosphereRig).to_dict() if sky_rig is AtmosphereRig else {},
		'player': {'x': player.position.x, 'z': player.position.z, 'yaw': player.yaw, 'pitch': player.pitch, 'hp': player.health, 'stam': player.stamina},
		'body': {'core': body.core, 'wet': body.wetness},
		'needs': {'cal': needs.calories, 'water': needs.water,'fatigue':needs.fatigue},
		'inv': {'counts': inv.counts, 'worn': inv.jacket(), 'extra': inv.extra, 'rifle_up': rifle_up, 'cond': inv.cond, 'age': inv.age, 'loaded': inv.loaded, 'active_rifle': inv.active_rifle, 'fitted': inv.fitted, 'light_on': inv.light_on, 'zero': inv.zero, 'light_charge': inv.light_charge, 'torch_on': inv.torch_on, 'torch_h': inv.torch_h, 'spares': inv.spares},
		'cabins': cabs,
		'huts': huts.map(func(h: Hut) -> Dictionary: return h.state_dict()),
		'holes': ice_holes.map(func(h: IceHole) -> Dictionary: return h.to_dict()),
		'chests': chests.map(func(c: StorageChest) -> Dictionary: return c.to_dict()),
		'stores': stores.map(func(s: Store) -> Dictionary: return s.state_dict()),
		'greenhouses': greenhouses.map(func(g: Greenhouse) -> Dictionary: return g.state_dict()),
		'frostbite': frostbite.to_dict(),
		'snares': snares.filter(func(s: Snare) -> bool: return is_instance_valid(s)).map(func(s: Snare) -> Dictionary: return s.to_dict()),
		'sheds': outbuildings.map(func(o: Outbuilding) -> int: return o.wood_left),
		'fires': fires,
		'wolves': _alive_list(wolves),
		'pickups': _pickup_list(),
		'bears': _alive_list(bears),
		'zombies': pop.all_alive(),
		'hordes': pop.horde_list(),
		'sleepers': pop.sleeper_list(),
		'injury': player.injury.to_dict(),
		'deer': _alive_list(deer),
		'felled': forest.felled.keys() if forest != null else [],
		'logs': _log_list(),
		'carcasses': _carcass_list(),
		'picked': plants.picked if plants != null else {},
	}
	if fire_lookout != null:
		d['lookout_door']=fire_lookout.door_to_dict()
		var elevated_location := fire_lookout.saved_location(player.position, player.eye_h)
		if not elevated_location.is_empty():
			d['lookout_location'] = elevated_location
	if opening != null: d['opening'] = opening.to_dict()
	if first_week!=null:d["first_week"]=first_week.to_dict()
	if collapse!=null:d["collapse"]=collapse.to_dict()
	if town_life!=null:d["town_life"]=town_life.to_dict()
	d["rooms"]=rooms.map(func(r:Dictionary)->float:return (r.climate as RoomClimate).room_c)
	d["forage"]=forage.map(func(f:ForageNode)->bool:return f.harvested)
	return d


func _pickup_list() -> Array:
	var out: Array = []
	for pk in get_tree().get_nodes_in_group('pickups'):
		var ip := pk as ItemPickup
		if ip != null and not ip.is_queued_for_deletion():
			out.append({'id': ip.id, 'n': ip.n, 'x': ip.global_position.x, 'y': ip.global_position.y, 'z': ip.global_position.z, 'c': ip.cond,'age_s':ip.age_s,'support':ip.support,'rs':ip.states})
	return out


func _alive_list(arr: Array) -> Array:
	var out: Array = []
	for a in arr:
		if is_instance_valid(a) and not bool(a.call('is_dead')):
			out.append({'x': a.global_position.x, 'z': a.global_position.z, 'hp': a.hp})
	return out


func _restore_creatures(sv: Dictionary) -> void:
	if plants != null:
		plants.apply_picked(sv.get('picked', {}))
	var ci := 0
	for e in sv.get('carcasses', []):
		var cp := _ground(float(e['x']), float(e['z']))
		var cn: Node3D = null
		match String(e['sp']):
			'deer':
				cn = _add_deer(cp, 800 + ci)
			'wolf':
				cn = _add_wolf(cp, 800 + ci, false)
			'bear':
				cn = _add_wolf(cp, 800 + ci, true)
		if cn != null:
			cn.call('hit', 99999.0, cp)
			cn.set_meta('done', e.get('done', {}))
			cn.set_meta('food_age_s',maxf(0,float(e.get('food_age_s',0))))
			cn.set_meta('scent_age_s',maxf(0,float(e.get('scent_age_s',Carcass.food_age(cn)/StorageChest.COLD_RATE))))
		ci += 1
	if forest != null:
		for info in forest.apply_felled(sv.get('felled', [])):
			WoodLog.make_stump(self, terrain, float(info['x']), float(info['z']), float(info['r']))
	for e in sv.get('logs', []):
		var wl := WoodLog.new()
		add_child(wl)
		wl.setup(terrain, float(e['x']), float(e['z']), Vector3(float(e['dx']), 0.0, float(e['dz'])), float(e['h']), float(e['r']))
	for e in sv.get('pickups', []):
		if Inventory.ITEMS.has(String(e['id'])):
			var pickup_pos := _ground(float(e['x']), float(e['z']))
			if e.has('y'): pickup_pos.y = float(e['y'])
			var pickup:=ItemPickup.spawn(self, String(e['id']), int(e['n']), pickup_pos, float(e.get('c', -1.0)),float(e.get('age_s',0)), e.get('rs', []) if e.get('rs', []) is Array else [])
			if pickup.id=="north_service_rifle" and not stores.is_empty():
				var shop:=stores[0] as Store
				if e.get('support',"")=="store_rifle" or shop.is_legacy_rifle_cache(pickup):shop.support_rifle(pickup)
	var i := 0
	for e in sv.get('wolves', []):
		var w := _add_wolf(_ground(float(e['x']), float(e['z'])), i)
		w.hp = float(e['hp'])
		i += 1
	i = 0
	for e in sv.get('bears', []):
		var br := _add_wolf(_ground(float(e['x']), float(e['z'])), 2000 + i, true)
		br.hp = float(e['hp'])
		i += 1
	i = 0
	player.injury.from_dict(sv.get('injury', {}))
	pop.restore_hordes(sv.get('hordes', []))
	pop.restore_sleepers(sv.get('sleepers', []))
	for e in sv.get('zombies', []):
		pop.add_virtual(_ground(float(e['x']), float(e['z'])))   # materialises by distance within a few ticks
		i += 1
	i = 0
	for e in sv.get('deer', []):
		var dr := _add_deer(_ground(float(e['x']), float(e['z'])), i)
		dr.hp = float(e['hp'])
		i += 1


func _ground(x: float, z: float) -> Vector3:
	var h: float = terrain.data.get_height(Vector3(x, 0, z))
	return Vector3(x, 0.0 if is_nan(h) else h, z)


func _apply_save(sv: Dictionary, launch_options: Dictionary = {}) -> void:
	road.snow_cover=clampf(float(sv.get("route_snow_cover",0)),0,1)
	var c: Dictionary = sv['clock']
	clock.restore(c)
	if launch_options.has("speed"):
		var requested_rate: float = float(launch_options.speed)
		if requested_rate > 0.0: clock.set_pace(requested_rate)
		else: clock.time_scale = 0.0
	if opening_state != null: opening_state.audio_clock_rate = clock.base_time_scale
	if opening_state != null: opening_state.align_calendar(clock.day,clock.hour,clock.total_game_s)
	if sv.has('weather'):
		weather.from_dict(sv.weather)
	if sky_rig is AtmosphereRig:
		(sky_rig as AtmosphereRig).from_dict(sv.get('atmosphere', {}))
	var p: Dictionary = sv['player']
	player.yaw = float(p['yaw'])
	player.pitch = float(p['pitch'])
	player.health = float(p['hp'])
	player.stamina = float(p['stam'])
	if fire_lookout != null:
		fire_lookout.restore_location(player, sv.get('lookout_location', {}))
		fire_lookout.restore_door(sv.get('lookout_door',{'open':true}))
	body.core = float(sv['body']['core'])
	body.wetness = float(sv['body']['wet'])
	needs.fatigue=clampf(float(sv['needs'].get('fatigue',0)),0,100)
	needs.calories = float(sv['needs']['cal'])
	needs.water = float(sv['needs']['water'])
	inv = Inventory.new(body)
	inv.needs = needs
	for k in sv['inv']['counts']:
		inv.add(String(k), int(sv['inv']['counts'][k]))
	for k in sv['inv'].get('age', {}):
		inv.age[String(k)] = float(sv['inv']['age'][k])
	for k in sv['inv'].get('cond', {}):
		inv.cond[String(k)] = float(sv['inv']['cond'][k])
	if String(sv['inv']['worn']) != '':
		inv.use(String(sv['inv']['worn']))
	var ex: Dictionary = sv['inv'].get('extra', {})
	for sl in ex:
		if Inventory.EXTRA_SLOTS.has(String(sl)) and inv.count(String(ex[sl])) > 0 and Inventory.slot_of(String(ex[sl])) == String(sl):
			inv.extra[String(sl)] = String(ex[sl])
	inv._recompute()
	for k in sv['inv'].get('loaded', {}):
		if Inventory.is_rifle(String(k)): inv.loaded[String(k)] = int(sv['inv']['loaded'][k])
	inv.active_rifle = String(sv['inv'].get('active_rifle', ''))
	var fsv: Dictionary = sv['inv'].get('fitted', {})
	for k in fsv:
		if Inventory.is_rifle(String(k)) and RifleDB.is_v3(String(k)) and fsv[k] is Dictionary:
			var fd: Dictionary = fsv[k]
			inv.fitted[String(k)] = {'mount': String(fd.get('mount', '')), 'optic': String(fd.get('optic', '')), 'light': String(fd.get('light', '')),
									 'muzzle': String(fd.get('muzzle', '')), 'light_h': float(fd.get('light_h', 0.0))}
	inv.light_on = bool(sv['inv'].get('light_on', false))
	var zsv: Dictionary = sv['inv'].get('zero', {})
	for k in zsv:
		if Inventory.is_rifle(String(k)) and zsv[k] is Array and (zsv[k] as Array).size() == 2: inv.zero[String(k)] = [float(zsv[k][0]), float(zsv[k][1])]
	var csv: Dictionary = sv['inv'].get('light_charge', {})
	for k in csv: inv.light_charge[String(k)] = float(csv[k])
	var spsv: Dictionary = sv['inv'].get('spares', {})
	for k in spsv:
		if Inventory.is_rifle(String(k)) and spsv[k] is Array:
			inv.spares[String(k)] = (spsv[k] as Array).filter(func(s) -> bool: return s is Dictionary).map(func(s) -> Dictionary: return inv._norm_state(String(k), s))
	inv.torch_on = bool(sv['inv'].get('torch_on', false))
	inv.torch_h = float(sv['inv'].get('torch_h', 6.0))
	rifle_up = bool(sv['inv']['rifle_up']) and inv.count('rifle') > 0
	var hsv: Array = sv.get('huts', [])
	for hi in range(mini(hsv.size(), huts.size())):
		huts[hi].restore_state(hsv[hi])
	frostbite.restore(sv.get('frostbite', {}))
	var gsv: Array = sv.get('greenhouses', [])
	for gi in range(mini(gsv.size(), greenhouses.size())):
		greenhouses[gi].restore_state(gsv[gi])
	var ssv: Array = sv.get('stores', [])
	for sj in range(mini(ssv.size(), stores.size())):
		stores[sj].restore_state(ssv[sj])
	_restore_holes(sv.get('holes', []))
	_restore_chests(sv.get('chests', []))
	var shs: Array = sv.get('sheds', [])
	for si in range(mini(shs.size(), outbuildings.size())):
		outbuildings[si].wood_left = int(shs[si])
	var cabs: Array = sv['cabins']
	for i in range(mini(cabs.size(), cabins.size())):
		var cb = cabins[i]
		if cabs[i].has('fire'):
			cb.fire.restore(cabs[i]['fire'])
		else:  # pre-standard save: separate stove fuel / kettle / pans
			cb.fire.restore({'fuel_s': float(cabs[i].get('stove', 0)), 'water': cabs[i].get('prepared_water', {}), 'cooking': cabs[i].get('cooking', {})})
		cb.refresh_fire()
		cb.apply_broken(cabs[i].get('broken', []))
		cb.wood_pile = int(cabs[i]['wood'])
		cb.crate_looted = bool(cabs[i]['looted'])
		cb.door_boards = int(cabs[i].get('dboards', 0))
		cb._build_door_planks()
		if cabs[i].has('open'):
			for k in range(mini(cb.openings.size(), cabs[i]['open'].size())):
				cb.openings[k].from_dict(cabs[i]['open'][k])
		if bool(cabs[i]['door_open']) != cb.door_open:
			cb.toggle_door()
	for f in sv['fires']:
		var cf := Campfire.new()
		add_child(cf)
		cf.global_position = Vector3(float(f['x']), float(f['y']), float(f['z']))
		if f.has('fire'):
			cf.fire.restore(f['fire'])
		else:  # pre-standard save
			cf.fire.restore({'fuel_s': float(f.get('fuel', 0)), 'water': f.get('prepared_water', {}), 'cooking': Campfire.legacy_cook(f.get('cook', []))})
		campfires.append(cf)

var _savetest := ''


func _print_state() -> void:
	print('STATE pos=(%.1f,%.1f) hp=%.0f cal=%.0f core=%.2f hour=%.2f wood=%d matches=%d worn=%s fires=%d fuel=%.0f wolves=%d zombies=%d deer=%d deer0hp=%.0f' % [player.position.x, player.position.z, player.health, needs.calories, body.core, clock.hour, inv.count('wood') if inv else -1, inv.count('matches') if inv else -1, inv.jacket() if inv else '?', campfires.size(), campfires[0].fuel_s if campfires.size() > 0 else -1.0, wolves.size(), zombies.size(), deer.size(), deer[0].hp if deer.size() > 0 else -1.0])


func _update_viewmodel() -> void:
	if viewmodel == null:
		return
	var m := 'fists'
	player.needs=needs
	viewmodel.game_clock=clock
	viewmodel.glove_item = String(inv.extra.get('hands', '')) if inv != null else ''
	viewmodel.hand_cold = clampf(float(frostbite.risk.get('hands', 0.0)) / 100.0 * 1.4 + maxf(0.0, -(body.feels_like if body != null else 0.0) - 4.0) / 30.0 * 0.45, 0.0, 1.0)
	if inv != null:
		if rifle_up and inv.count('rifle') > 0:
			m = 'rifle'
		elif inv.count('axe') > 0:
			m = 'axe'
		var rid := inv.rifle_id()
		if rid != '' and viewmodel.weapon_id != rid: viewmodel.weapon_id = rid
		if rid != '': player.aim_fovs = RifleDB.zoom(rid)
	viewmodel.mode = m


func _run_vmtest() -> void:
	inv = Inventory.new(body)
	inv.needs = needs
	if _vmtest != 'fists':
		inv.add('axe')
	if _vmtest == 'rifle':
		inv.add('rifle')
		inv.add('ammo', 5)
		rifle_up = true
	_update_viewmodel()
	viewmodel._cur = viewmodel.mode
	viewmodel._equip = 1.0
	var act := _opts_vmact
	if act == 'swing':
		viewmodel.swing(_vmtest == 'axe')
	elif act == 'fire':
		viewmodel.fire()
	elif act == 'aim':
		aim_override = true
		player.aim_k = 1.0

## Cold-start conditions at an outdoor fire (FireSource.start_chance): wind and
## snow now, shelter upwind (a trunk or wall within 2.5 m), tinder carried.
func fire_start_ctx(point: Vector3, kindling := false) -> Dictionary:
	return {"outdoors": true, "wind": weather.wind if weather != null else 0.0, "precip": weather.precip if weather != null else 0.0,
		"sheltered": _upwind_sheltered(point), "tinder": inv != null and inv.count("tinder") > 0, "kindling": kindling}

func _upwind_sheltered(point: Vector3) -> bool:
	if weather == null: return false
	var up := Vector3(-weather.wind_dir.x, 0.0, -weather.wind_dir.y).normalized()
	if forest != null and not (forest.nearest_tree(point, up, 2.5, true) as Dictionary).is_empty(): return true
	return HitZones.building_block(_building_list(), point + Vector3(0, 0.5, 0), up, 2.5) < 2.4

## The one interaction list for every FireSource: the lookout stove, cabin stoves,
## campfires and any future stove. Stoke with each carried fuel (longest first,
## mouse wheel picks), kettle, pans, drying rack. Entries carry a "tag".
func fire_actions(src: FireSource, point: Vector3, refresh: Callable = Callable(), r: float = 1.9, tol: float = 0.9, rack_point: Variant = null) -> Array:
	var out: Array = []
	var lbl := src.label()
	var options: Array = src.fuel_options(inv) if inv != null else []
	var verb := ("Light " if src.needs_starter() else ("Relight " if src.has_embers() else "Stoke ")) + lbl
	var after := func() -> void:
		if refresh.is_valid():
			refresh.call()
	if options.is_empty():
		out.append(_fire_entry(point, r, tol, "stoke", "%s • %s • no fuel carried" % [lbl.capitalize(), src.status()], 0.0, 0.0, func() -> void: _say("Carry firewood, planks, kindling or sticks to burn")))
	for i in options.size():
		var id: String = options[i]
		var tail := src.status()
		if src.needs_starter():
			tail = "needs a match"
			if src.exposed() and point.distance_to(player.position) < r + 1.0:
				var ch := FireSource.start_chance(fire_start_ctx(point, id == "kindling"))
				if ch < 0.995: tail += " • %d%% to catch" % roundi(ch * 100.0)
		var text := "%s • %s +%s • %s" % [verb, inv.name_of(id).to_lower(), FireSource.duration(src.burn_s(id)), tail]
		out.append(_fire_entry(point, r, tol, "stoke", text, src.hold_s(), 0.001 * i, func() -> void:
			var res: Dictionary = src.stoke(inv, id, fire_start_ctx(point, id == "kindling") if src.needs_starter() and src.exposed() else {})
			_say(String(res.msg))
			if bool(res.ok):
				audio.play_at("rustle", point, -8, 1, 3, 18)
			after.call()))
	var pot := src.water
	if src.is_lit() or pot.batch > 0 or pot.ready > 0:
		out.append(_fire_entry(point, r, tol, "water", pot.status(), 2.0 if pot.batch == 0 and pot.ready == 0 else (1.0 if pot.ready > 0 else 0.0), 0.01, func() -> void:
			if pot.ready > 0:
				var n := pot.collect(inv)
				_say("Collected %.1f L drinking water" % (n * 0.5) if n > 0 else "Make room in your pack; water stays in the kettle")
			elif pot.batch > 0:
				_say("Boiling progresses while the %s burns" % lbl)
			elif src.is_lit():
				_say(pot.begin(inv))
			else:
				_say("Light the %s first" % lbl)
			after.call()))
	var pans := src.cooking
	if src.is_lit() and pans.free_slots() > 0 and inv != null and inv.has_raw():
		out.append(_fire_entry(point, r, tol, "cook", "Cook raw food on the %s (%d free)" % [lbl, pans.free_slots()], 2.0, 0.02, func() -> void:
			_say(pans.begin(inv, src.is_lit()))
			after.call()))
	if inv != null and inv.count(PotCooking.POT) > 0 and src.is_lit() and pans.free_slots() > 0:
		var brews := PotCooking.ready_recipes(inv)
		if brews.is_empty():
			out.append(_fire_entry(point, r, tol, "pot", "Cook pot • needs drinking water + rose hips, birch bark, reishi or raw meat", 0.0, 0.025, func() -> void:
				_say(PotCooking.missing(inv, PotCooking.recipes()[0]))))
		for bi in brews.size():
			var rec: Dictionary = brews[bi]
			out.append(_fire_entry(point, r, tol, "pot", "Cook pot • %s • %d min" % [String(rec.name).to_lower(), int(rec.cook_min)], 2.0, 0.025 + 0.001 * bi, func() -> void:
				_say(PotCooking.begin(pans, inv, rec, src.is_lit(), lbl))
				after.call()))
	if not pans.portions.is_empty():
		out.append(_fire_entry(point, r, tol, "cook", pans.status(), 0.0, 0.03, func() -> void:
			var n := pans.collect(inv)
			_say("Collected %d portions; food left at the %s keeps aging" % [n, lbl] if n > 0 else "Food is still cooking, or your pack is full")
			after.call()))
	if src.rack != null:
		var rp: Vector3 = rack_point if rack_point != null else point
		var rack := src.rack
		var hold := 4.0 if rack.portions.is_empty() else (1.0 if rack.ready_count() > 0 else 0.0)
		out.append(_fire_entry(rp, r, tol, "rack", rack.status(), hold, 0.02, func() -> void:
			if rack.ready_count() > 0:
				var n := rack.collect(inv)
				_say("Collected %d rack portions" % n if n > 0 else "Pack full. Rack food remains in place and continues to age.")
			elif not rack.portions.is_empty():
				_say(rack.status())
			elif not src.is_lit():
				_say("Light the %s before starting the drying rack" % lbl)
			else:
				_say(rack.begin(inv))
			after.call()))
	return out


func _fire_entry(point: Vector3, r: float, tol: float, tag: String, text: String, hold: float, bias: float, act: Callable) -> Dictionary:
	return {"pos": point, "r": r, "tol": tol, "tag": tag, "text": text, "hold": hold, "dbias": bias, "act": act, "work": "reach"}


func _water_action(pot:PreparedWater,point:Vector3,lit:bool)->Dictionary:
	var text:=pot.status() if pot.batch>0 else ("Collect boiled water • %d bottles"%pot.ready if pot.ready>0 else "Boil snow in field bottles • 20 min")
	return {"pos":point,"r":1.9,"text":text,"hold":2.0 if pot.batch==0 and pot.ready==0 else 0.0,"act":func()->void:
		if pot.ready>0:_say("Collected %d bottles; %d remain at heat source"%[pot.collect(inv),pot.ready])
		elif pot.batch>0:_say(pot.status())
		elif lit:_say(pot.begin(inv))
		else:_say("Light the fire first")}

# ---- Gunsmith (weapon kit v3): fit / remove sights, mounts, lights and muzzle devices; zero at a bench.
var gunsmith: GunsmithScreen
var _wb_point := Vector3.INF
var _wb_done := false
func _workbench_point() -> Vector3:
	if not _wb_done:
		_wb_done = true
		var bench := fire_lookout.find_child("TechnicianWorkbench", true, false) as Node3D if fire_lookout != null else null
		if bench != null:
			var box := AABB(); var first := true
			for mi: MeshInstance3D in bench.find_children("*", "MeshInstance3D", true, false):
				var b := mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b); first = false
			if not first: _wb_point = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	return _wb_point

func at_workbench() -> bool:
	var wb := _workbench_point()
	return wb != Vector3.INF and player.position.distance_to(wb) < 2.6

func open_gunsmith(rid := '', bench := false) -> void:
	if inv == null: return
	if rid == '' or not RifleDB.is_v3(rid):
		for r: String in Inventory.RIFLE_IDS:
			if inv.count(r) > 0 and RifleDB.is_v3(r): rid = r; break
	if rid == '':
		_say('You have no rifle to work on'); return
	if gear != null and gear.is_open: gear.close()
	if gunsmith == null:
		gunsmith = GunsmithScreen.new(); add_child(gunsmith)
	gunsmith.open_for(self, inv, player, hud, rid, bench or at_workbench())

## Fit (aid) or remove (aid = "") one slot. Checks tools (a bench has them all), then works as a timed action.
func gunsmith_fit(rid: String, slot: String, aid: String, bench: bool) -> String:
	var cur := String(RifleDB.fitted(rid).get(slot, ''))
	var a := RifleDB.attachment(aid if aid != '' else cur)
	if a.is_empty(): return 'Nothing to do'
	if aid != '':
		if inv.count(aid) < 1: return "You don't have it"
		var why := RifleDB.fit_reason(rid, aid)
		if why != '': return why
	if not bench:
		for t in a.get('tools', []):
			if inv.count(String(t)) < 1: return 'Needs a %s, or a workbench' % inv.name_of(String(t)).to_lower()
	var mins := float(a.get('fit_min', 5))
	var verb := ('Fitting ' if aid != '' else 'Removing ') + String(a.get('name', 'part')) + ' (%d min)' % int(mins)
	if gunsmith != null: gunsmith.close()
	_act_begin({"text": verb, "hold": clampf(mins * 0.35, 1.5, 8.0), "auto": true, "work": "reach", "game_min": mins,
				"start": func() -> void: audio.play_at("cloth_wrap", player.position, -16, 1, 1, 6),
				"act": _gunsmith_fit_done.bind(rid, slot, aid, bench)})
	return ''

func _gunsmith_fit_done(rid: String, slot: String, aid: String, bench: bool) -> void:
	var why := inv.fit_attachment(rid, slot, aid, bench)
	if why != '': _say(why)
	elif slot in ['optic', 'mount'] and aid != '' and not bench: _say('Fitted. Zero it at a workbench: the first shots will be off')
	else: _say('Done')
	open_gunsmith(rid, bench)

## Zero the sights: at a bench, three rounds at a target board. Loud.
func gunsmith_zero(rid: String) -> String:
	if not at_workbench(): return 'Zero it at a workbench'
	if inv.count('ammo') < 3: return 'Needs three rounds'
	if gunsmith != null: gunsmith.close()
	_act_begin({"text": 'Zeroing ' + inv.name_of(rid) + ' (20 min)', "hold": 8.0, "auto": true, "work": "reach", "game_min": 20.0, "act": _gunsmith_zero_done.bind(rid)})
	return ''

func _gunsmith_zero_done(rid: String) -> void:
	for i in 3:   # three real shots from the bench, spaced like aimed fire
		get_tree().create_timer(0.15 + 1.6 * i).timeout.connect(func() -> void: if audio != null: audio.gunshot(rid))
	for i in 3: inv.remove('ammo')
	if inv.loaded.has(rid): inv.loaded[rid] = mini(int(inv.loaded[rid]), inv.count('ammo'))
	inv.zero[rid] = [0.0, 0.0]
	noise_bus.emit_noise(player.position, NoiseBus.RADIUS_GUNSHOT * RifleDB.value(rid, 'noise', 1.0) * float(RifleDB.muzzle(rid).get('noise_mult', 1.0)), player)
	_say('Zeroed: three shots in a hand-width group')
	open_gunsmith(rid, true)

func gear_maintain(id:String)->void:
	if opening==null or player.position.distance_to(opening.home_point(Vector3(.95,.88,-1.35)))>2.6:
		_say("Return to the lookout desk to maintain your gear");return
	var why:=FieldMaintenance.reason(inv,id)
	if why!="":_say(why);return
	gear.close()
	_act_begin({"text":"Maintaining "+inv.name_of(id),"hold":6.0,"auto":true,"work":"reach","start":func()->void:audio.play_at("stone_hone" if id in ["axe","knife"] else "cloth_wrap",player.position,-13,1,1,8),"act":func()->void:_say(FieldMaintenance.complete(inv,id))})
