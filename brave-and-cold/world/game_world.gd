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
var road: RoadNet
var huts: Array = []
var trailnet: TrailNet
var colliders: Array = []
var hut_sites: Array = []
var body := BodyTemperature.new()
var snow := SnowField.new()
var noise_bus := NoiseBus.new()
var player: Player
var hud: Hud
var forest: ForestScatter
var footprints: Footprints
var cabins: Array[Cabin] = []
var out_path := ""
var walk_secs := 0.0
var _t := 0.0
var _frames := 0
var wind := 3.0
var _walk_started := false
var _ft: Array[float] = []


func _ready() -> void:
	Settings.load_all()
	var opts := _args()
	_build_environment()
	terrain = Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.assets = load("res://data/terrain/terrain_assets.tres")
	terrain.data_directory = MAP
	add_child(terrain)
	terrain.material.auto_shader = false
	terrain.material.set_shader_param("blend_sharpness", 0.1)
	terrain.material.set_shader_param("enable_macro_variation", true)
	terrain.material.set_shader_param("macro_variation1", Color(0.88, 0.93, 1.0))
	terrain.material.set_shader_param("macro_variation2", Color(1.0, 0.97, 0.98))
	road = RoadNet.new()
	add_child(road)
	trailnet = TrailNet.new()
	add_child(trailnet)
	if opts.get('road', '1') == '1':
		road.plan()
	if road.points.size() > 40 and opts.get('huts', '1') == '1':
		var wimg := MapIO.load_png('res://data/maps/valley_b/water_mask.png')
		wimg.convert(Image.FORMAT_L8)
		hut_sites = Hut.find_sites(terrain, road, wimg, int(opts.get('hutn', 5)))
		print('HUT_SITES ', hut_sites.size(), ' ', hut_sites)
		for hs in hut_sites:
			var hp := Vector2(float(hs['x']), float(hs['z']))
			var hyaw := deg_to_rad(float(hs['yaw']))
			trailnet.add_trail(_road_edge_toward(hp), hp + Vector2(sin(hyaw), cos(hyaw)) * 1.8, 11)
	if opts.get("trees", "1") == "1":
		forest = ForestScatter.new()
		add_child(forest)
		forest.exclude = func(x: float, z: float) -> bool:
			for hs in hut_sites:
				if absf(x - float(hs['x'])) < 7.0 and absf(z - float(hs['z'])) < 7.0:
					return true
			return road.is_near(x, z) or trailnet.is_near(x, z)
		forest.build(terrain)
	road.build_mesh(terrain)
	road.build_props(terrain)
	var w := WaterSurfaces.new()
	add_child(w)
	w.build()
	snow.build("res://data/maps/valley_b")
	clock.hour = float(opts.get("hour", 16.5))
	clock.time_scale = float(opts.get("speed", clock.time_scale))
	Cabin.game_scale = clock.time_scale
	sky_rig = SkyRig.new()
	add_child(sky_rig)
	sky_rig.setup(sun, env, sky_mat)
	sky_rig.weather = weather
	if opts.has('weather'):
		var wi := ['clear', 'cloudy', 'flurry', 'snow', 'blizzard'].find(String(opts['weather']).to_lower())
		if wi >= 0:
			weather.lock_state(wi)
	sky_rig.clouds = CloudLayer.new()
	add_child(sky_rig.clouds)
	sky_rig.apply_hour(clock.hour)
	player = Player.new()
	add_child(player)
	player.setup(terrain, snow, body, noise_bus)
	snowfall = SnowFall.new()
	add_child(snowfall)
	snowfall.follow = player
	snowfall.weather = weather
	player.forest = forest
	sky_rig.clouds.follow = player
	sky_rig.apply_hour(clock.hour)
	footprints = Footprints.new()
	add_child(footprints)
	player.footprints = footprints
	viewmodel = Viewmodel.new()
	viewmodel.player = player
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
	if loading:
		sp = Vector2(float(sv['player']['x']), float(sv['player']['z']))
	player.place(sp.x, sp.y)
	_place_cabin(home)
	_build_huts()
	if not opts.has("wolftest") and not opts.has("zombietest") and not opts.has("deertest"):
		if loading:
			_restore_creatures(sv)
		else:
			_spawn_wolves(int(opts.get("wolves", 3)), home, 70.0, 140.0)
			_spawn_bears(int(opts.get("bears", 2)), home, 150.0, 320.0)
		if not loading:
			_spawn_zombies(int(opts.get("zombies", 10)), home)
			_spawn_deer(int(opts.get("deer", 6)), home)
	player.cabins = colliders
	if opts.has('hutpos') and not huts.is_empty():
		var hu0: Hut = huts[clampi(int(opts['hutpos']), 0, huts.size() - 1)]
		var hwp: Vector3 = hu0.to_global(Vector3(float(opts.get('hutx', 0.0)), 0.0, float(opts.get('hutd', 6.0))))
		player.place(hwp.x, hwp.z)
		var hdir: Vector3 = hu0.global_position - hwp
		opts['yaw'] = rad_to_deg(atan2(-hdir.x, -hdir.z))
		opts['pitch'] = -4.0
	if not cabins.is_empty():
		if opts.has("stove"):
			cabins[0].add_wood()
		if opts.has("dooropen"):
			cabins[0].toggle_door()
		if opts.has("cabinpos"):
			var lp := String(opts["cabinpos"]).split(",")
			var wp: Vector3 = cabins[0].to_global(Vector3(float(lp[0]), 0.0, float(lp[1])))
			player.place(wp.x, wp.z)
			var st: Vector3 = cabins[0].stove_world_pos()
			player.yaw = atan2(-(st.x - wp.x), -(st.z - wp.z))
			player.pitch = deg_to_rad(-12.0)
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
		_apply_save(sv)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player, body, snow, clock)
	hud.weather = weather
	hud.visible = not opts.has('nohud')
	gear = GearScreen.new()
	add_child(gear)
	_loot = opts.has('loot')
	_gear_opt = opts.has('gear')
	_gear_sel = String(opts.get('gearsel', ''))
	_geartest = opts.has('geartest')
	opts_dropdemo = opts.has('dropdemo')
	audio = GameAudio.new()
	add_child(audio)
	audio.setup(player, self, wind)
	audio.weather = weather
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


func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			d[kv[0]] = kv[1]
	return d


func _build_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_bias = 0.15
	sun.shadow_normal_bias = 3.0
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_sky_affect = 0.6
	env.fog_aerial_perspective = 0.5
	env.ssao_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(delta: float) -> void:
	if hud == null:
		return
	_frames += 1
	_update_viewmodel()
	_t += delta
	# time / lighting
	var gs := clock.advance(delta)
	weather.advance(delta, gs)
	wind = weather.wind
	clock.weather_offset_c = weather.temp_off
	sky_rig.apply_hour(clock.hour)
	var night := clampf(1.0 - sun.light_energy / 0.7, 0.0, 1.0)
	Zombie.night_factor = night
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_autosave_t += delta
	if _autosave_t > 120.0 and out_path == '' and walk_secs == 0.0 and not _selftest and not _wolftest and not _zombietest and not _deertest:
		_autosave_t = 0.0
		if _safe_to_save() and save_game():
			_say('Autosaved')
	for cb in cabins:
		cb.set_night(night)
	# survival
	snow.advance(delta)
	var fw := player.fire_w
	for cb in cabins:
		fw = maxf(fw, cb.heat_at(player.position.x, player.position.z))
	for cf in campfires:
		cf.advance(gs)
		fw = maxf(fw, cf.heat_at(player.position.x, player.position.z))
	body.metabolism_mult = needs.metabolism_mult()
	body.update(gs, clock.ambient_c(), wind, player.is_sheltered(), fw, player.activity, 0.0 if player.is_sheltered() else weather.precip * 0.05, false)
	needs.update(gs, player.activity, body.core)
	var sd := needs.damage_per_s()
	if sd > 0.0 and not player.dead:
		player.hurt(sd * delta, 'Died of thirst' if needs.water <= 0.0 else 'Starved to death')
	if body.core <= BodyTemperature.FATAL:
		player.hurt(9999.0, "Froze to death")
	_update_prompt()
	if out_path != "" and _frames == 40:
		get_viewport().get_texture().get_image().save_png(out_path)
		print("SHOT_SAVED ", out_path, " hour=", clock.hour, " pos=", player.position, " yaw=", player.yaw)
		get_tree().quit()
	if _force_death and _frames == 35:
		player.hurt(999.0, "Mauled by a wolf")
	if _zombietest and _frames > 30:
		_zombietest_step(delta)
	if opts_pausetest and _frames == 40:
		opts_pausetest = false
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


func _build_huts() -> void:
	for hs in hut_sites:
		var h := Hut.new()
		add_child(h)
		if h.setup(terrain, float(hs['x']), float(hs['z']), float(hs['yaw'])):
			huts.append(h)
			print('HUT at ', Vector2(float(hs['x']), float(hs['z'])))
		else:
			h.queue_free()
	colliders = []
	colliders.append_array(cabins)
	colliders.append_array(huts)
	if not cabins.is_empty() and road.points.size() > 2:
		var cyaw := deg_to_rad(cabins[0].rotation_degrees.y)
		var cp := Vector2(cabins[0].position.x, cabins[0].position.z)
		trailnet.add_trail(_road_edge_toward(cp), cp + Vector2(sin(cyaw), cos(cyaw)) * 3.9, 23)
	trailnet.build_mesh(terrain)


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
	_say(inv.use(id))


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
	if id == inv.equipped_body and n >= inv.count(id):
		inv.use(id)
	if id == 'rifle' and n >= inv.count(id):
		rifle_up = false
	var nm := inv.name_of(id)
	if not inv.remove(id, n):
		return
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var p := player.position + fwd * 1.3
	var h: float = player.ground_at(p.x, p.z)
	if is_nan(h):
		h = player.position.y - player.eye_h
	ItemPickup.spawn(self, id, n, Vector3(p.x, h, p.z))
	_say('Dropped %s%s' % [nm, ' x%d' % n if n > 1 else ''])


func take_pickup(node: Node) -> void:
	var p := node as ItemPickup
	if p == null or inv == null or p.is_queued_for_deletion():
		return
	if not inv.can_add(p.id, p.n):
		_say('Your pack is full')
		return
	inv.add(p.id, p.n)
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
	var c6 := inv.equipped_body == '' and inv.count('parka') == 0 and is_equal_approx(body.warmth, 0.25)
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
	await _sim_drag(gear._pack_rect(0).get_center(), gear._slot_rect('body').get_center())
	var u2ok := inv.equipped_body == 'parka'
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


func _update_prompt() -> void:
	if inv == null:
		inv = Inventory.new(body)
		inv.add("wood", 2)
		inv.add("matches", 1)
		inv.needs = needs
	_ensure_gear()
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var cands: Array = []
	for hu in huts:
		if not hu.crate_looted:
			var hh: Hut = hu
			var hd: float = hh.tackle_world_pos().distance_to(player.position)
			if hd < 1.8:
				cands.append({'d': hd, 'text': 'Search tackle box', 'act': func() -> void:
					hh.crate_looted = true
					inv.add('matches', 2)
					inv.add('beans', 1)
					inv.add('flare', 1)
					_say('Found: 2 matches, beans, flare')})
	for cb in cabins:
		var stove_text := "Add wood to stove (%d)" % inv.count("wood")
		if not cb.is_lit():
			stove_text = "Light stove (wood + match)"
		if inv.count("wood") == 0:
			stove_text = "Stove needs wood"
		var items: Array[Dictionary] = [
			{"pos": cb.door_world_pos(), "r": 2.0, "text": "Door is broken" if cb.door_broken else ("Close door" if cb.door_open else "Open door"), "act": cb.toggle_door},
			{"pos": cb.stove_world_pos(), "r": 1.7, "text": stove_text, "act": func() -> void:
				if inv.count("wood") == 0:
					_say("No firewood")
				elif not cb.is_lit():
					if inv.remove("matches"):
						inv.remove("wood")
						cb.add_wood()
						_say("Struck a match: the stove catches")
					else:
						_say("No matches")
				else:
					inv.remove("wood")
					cb.add_wood()
					_say("Added firewood")},
			{"pos": cb.stove_world_pos(), "r": 1.7, "text": "Cook meat", "hide": not (cb.is_lit() and inv.count('venison_raw') > 0), "act": func() -> void:
				var n := inv.cook_all()
				_say('Cooked %d venison' % n)},
			{"pos": cb.stove_world_pos(), "r": 1.7, "text": "Drink melted snow", "hide": not cb.is_lit() or needs.water > 95.0, "act": func() -> void:
				needs.drink(35.0)
				_say('Drank melted snow (+35 water)')},
			{"pos": cb.woodpile_world_pos(), "r": 1.9, "text": "Take firewood (%d left)" % cb.wood_pile, "act": func() -> void:
				if cb.take_firewood():
					inv.add("wood")
					_say("+1 firewood")},
		]
		if not cb.crate_looted:
			items.append({"pos": cb.crate_world_pos(), "r": 1.7, "text": "Search crate", "act": func() -> void:
				cb.crate_looted = true
				inv.add("matches", 4)
				inv.add("flare", 1)
				inv.add("parka")
				inv.add("axe")
				inv.add("sweater")
				inv.add("rifle")
				inv.add("ammo", 6)
				inv.add("beans", 2)
				_say("Found: hatchet, rifle + 6 rounds, parka, sweater, matches, beans")})
		for it in items:
			if it.get('hide', false):
				continue
			var to: Vector3 = it["pos"] - player.position
			var d := to.length()
			if d > float(it["r"]):
				continue
			var flat := Vector3(to.x, 0.0, to.z)
			if flat.length() > 0.6 and flat.normalized().dot(fwd) < 0.5:
				continue
			it["d"] = d
			cands.append(it)
	for cf in campfires:
		var cd: float = cf.global_position.distance_to(player.position)
		if cd < 2.6:
			var cfire: Campfire = cf
			var ctext := 'Add log to fire (%d)' % inv.count('wood')
			if inv.count('wood') == 0:
				ctext = 'Fire needs wood'
			cands.append({"d": cd, "text": ctext, "act": func() -> void:
				if inv.remove('wood'):
					cfire.add_wood()
					_say('Added log: %d min of fuel' % int(cfire.fuel_s / 60.0))
				else:
					_say('No firewood')})
			if cfire.is_lit() and inv.count('venison_raw') > 0 and cd < 1.8:
				cands.append({"d": cd - 0.01, "text": "Cook meat over fire", "act": func() -> void:
					_say('Cooked %d venison' % inv.cook_all())})
			if cfire.is_lit() and needs.water < 90.0 and cd < 1.8:
				cands.append({"d": cd + 0.01, "text": "Melt snow and drink", "act": func() -> void:
					needs.drink(35.0)
					_say('Drank melted snow (+35 water)')})
	for dr in deer:
		if is_instance_valid(dr) and dr.state == Deer.State.DEAD and not dr.harvested:
			var dd: float = dr.global_position.distance_to(player.position)
			if dd < 2.4:
				cands.append({"d": dd, "text": "Harvest deer (+%d venison)" % Deer.MEAT_YIELD, "act": func() -> void:
					dr.harvested = true
					inv.add('venison_raw', Deer.MEAT_YIELD)
					dr.queue_free()
					_say('Harvested %d raw venison' % Deer.MEAT_YIELD)})
	for pk in get_tree().get_nodes_in_group("pickups"):
		var ip := pk as ItemPickup
		if ip == null:
			continue
		var pto := ip.global_position - player.position
		pto.y = 0.0
		var pd := pto.length()
		if pd < 2.4 and (pd < 0.9 or pto.normalized().dot(fwd) > 0.3):
			var pick: ItemPickup = ip
			cands.append({"d": pd + 0.5, "text": "Take %s%s" % [inv.name_of(ip.id), " x%d" % ip.n if ip.n > 1 else ""], "act": func() -> void: take_pickup(pick)})
	cands.sort_custom(func(x, y) -> bool: return float(x["d"]) < float(y["d"]))
	if cands.size() > 7:
		cands.resize(7)
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
	if inv.equipped_body != "":
		info += "  [%s]" % inv.name_of(inv.equipped_body)
	for cb in cabins:
		if cb.is_lit():
			info += "   Stove: %.0f min left" % (cb.stove_fuel_s / 60.0)
	info += '   Cal %d (%s)  Water %d%% (%s)' % [int(needs.calories), needs.hunger_state(), int(needs.water), needs.thirst_state()]
	if inv.count('rifle') > 0:
		info += '   [%s] ammo %d' % ['RIFLE' if rifle_up else 'hatchet', inv.count('ammo')]
	hud.info = info
	hud.rifle_up = rifle_up
	hud.kills = _count_kills()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE and pause_menu != null and not pause_menu.visible:
		pause_menu.open()
		return
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
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if _n_actions > 1:
			var stepv := -1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			_sel_idx = posmod(_sel_idx + stepv, _n_actions)
			hud.action_sel = _sel_idx
			_sel_text = String(hud.actions[_sel_idx]).split(" (")[0]
			_cur = _cands_cache[_sel_idx]
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_attack()
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_E and not _cur.is_empty():
		(_cur["act"] as Callable).call()
	elif e.keycode == KEY_V and inv != null:
		_throw_flare()
	elif e.keycode == KEY_B and inv != null:
		_build_campfire()
	elif e.keycode == KEY_X and inv != null and inv.count('rifle') > 0:
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


func _spawn_zombies(n: int, center: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var made := 0
	var tries := 0
	while made < n and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(50.0, 240.0)
		var cx := center.x + cos(a) * r
		var cz := center.y + sin(a) * r
		var group := mini(3, n - made)
		for k in range(group):
			var x := cx + rng.randf_range(-5.0, 5.0)
			var z := cz + rng.randf_range(-5.0, 5.0)
			if absf(x) > 950.0 or absf(z) > 950.0:
				continue
			var h: float = terrain.data.get_height(Vector3(x, 0, z))
			if is_nan(h):
				continue
			_add_zombie(Vector3(x, h, z), 500 + made)
			made += 1


func _add_zombie(p: Vector3, idx: int) -> Zombie:
	var z := Zombie.new()
	add_child(z)
	z.global_position = p
	z.rotation.y = randf() * TAU
	z.setup(terrain, snow, player, forest, colliders, noise_bus, idx)
	zombies.append(z)
	return z


func _attack() -> void:
	if _attack_cd > 0.0 or player.dead or inv == null:
		return
	if rifle_up and inv.count('rifle') > 0:
		_shoot()
		return
	var axe := inv.count("axe") > 0
	_attack_cd = 0.9 if axe else 0.7
	viewmodel.swing(axe)
	var dmg := AXE_DAMAGE if axe else FIST_DAMAGE
	noise_bus.emit_noise(player.position, NoiseBus.RADIUS_AXE if axe else 10.0, player)
	await get_tree().create_timer(0.27 if axe else 0.14).timeout  # damage lands at swing impact, not at click
	if player.dead:
		return
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var best: Node3D = null
	var bd := 2.1
	for h in get_tree().get_nodes_in_group("hostile"):
		var n := h as Node3D
		var to := n.global_position - player.position
		to.y = 0.0
		var d := to.length()
		if d < bd and (d < 0.6 or fwd.dot(to / maxf(d, 0.001)) > 0.5):
			bd = d
			best = n
	if best != null:
		best.call("hit", dmg, player.position)
		audio.hit(best.global_position + Vector3(0, 1.0, 0))
		_say("Hit!")
	else:
		_say("Swing")


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
		get_tree().quit()


var needs := Needs.new()
var rifle_up := false
var deer: Array[Deer] = []
var _deertest := false
var _dt := 0.0
var _dt_spawned := false
var _dt_last := -1
const RIFLE_DAMAGE := 100.0


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


func _add_deer(p: Vector3, idx: int) -> Deer:
	var d := Deer.new()
	add_child(d)
	d.global_position = p
	d.setup(terrain, snow, player, forest, noise_bus, 2000 + idx)
	deer.append(d)
	return d


func _shoot() -> void:
	if inv.count('ammo') == 0:
		_attack_cd = 0.4
		viewmodel.dry()
		_say('Click. No ammo')
		return
	inv.remove('ammo')
	_attack_cd = 1.2
	viewmodel.fire()
	noise_bus.emit_noise(player.position, NoiseBus.RADIUS_GUNSHOT, player)
	audio.gunshot()
	var eye := player.position + Vector3(0, 1.6, 0)
	var dir := Vector3(-sin(player.yaw) * cos(player.pitch), sin(player.pitch), -cos(player.yaw) * cos(player.pitch)).normalized()
	var best: Node3D = null
	var bt := 120.0
	var groups := ['hostile', 'prey']
	for g in groups:
		for h in get_tree().get_nodes_in_group(g):
			var n := h as Node3D
			if n == null:
				continue
			if n.has_method('is_dead') and n.call('is_dead'):
				continue
			var c := n.global_position + Vector3(0, 0.9, 0)
			var t := (c - eye).dot(dir)
			if t < 1.0 or t > bt:
				continue
			if (eye + dir * t).distance_to(c) < 0.8:
				bt = t
				best = n
	if best != null:
		best.call('hit', RIFLE_DAMAGE, player.position)
		audio.hit(best.global_position + Vector3(0, 1.0, 0))
		_say('Shot hit')
	else:
		_say('Bang. Miss')


func _deertest_step(delta: float) -> void:
	_dt += delta
	if not _dt_spawned:
		_dt_spawned = true
		inv = Inventory.new(body)
		inv.needs = needs
		inv.add('rifle')
		inv.add('ammo', 3)
		rifle_up = true
		var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
		var dp := player.position + fwd * 40.0
		dp.y = terrain.data.get_height(dp)
		_add_deer(dp, 1)
		player.pitch = deg_to_rad(0.0)
		print('DT deer at 40m')
	var d0: Deer = deer[0]
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if _dt > 2.0 and d0.state != Deer.State.DEAD and _attack_cd <= 0.0 and inv.count('ammo') > 0:
		var to := d0.global_position + Vector3(0, 0.9, 0) - (player.position + Vector3(0, 1.6, 0))
		player.yaw = atan2(-to.x, -to.z)
		player.pitch = atan2(to.y, Vector2(to.x, to.z).length())
		_attack()
	if int(_dt) != _dt_last:
		_dt_last = int(_dt)
		print('DT t=%d state=%d dist=%.1f hp=%.0f ammo=%d' % [_dt_last, d0.state, d0.global_position.distance_to(player.position), d0.hp, inv.count('ammo')])
	if d0.state == Deer.State.DEAD and _dt > 3.0:
		player.position = d0.global_position + Vector3(1.0, 0.0, 0.0)
		_update_prompt()
		print('DEERTEST prompt=[%s]' % hud.prompt)
		if _cur.has('act'):
			(_cur['act'] as Callable).call()
		print('DEERTEST venison_raw=%d ammo=%d' % [inv.count('venison_raw'), inv.count('ammo')])
		var cal0 := needs.calories
		needs.calories = 500.0
		print('DEERTEST eat: ', inv.use('venison_raw'), ' cal ', needs.calories)
		get_tree().quit()
	elif _dt > 40.0:
		print('DEERTEST timeout state=%d' % d0.state)
		get_tree().quit()

var campfires: Array[Campfire] = []


func _build_campfire() -> void:
	if player.dead:
		return
	for cb in cabins:
		if cb.contains_xz(player.position.x, player.position.z):
			_say('Not indoors. Use the stove')
			return
	if inv.count('wood') < 2 or inv.count('matches') < 1:
		_say('Campfire needs 2 firewood + 1 match')
		return
	var fwd := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var p := player.position + fwd * 1.6
	var h: float = terrain.data.get_height(Vector3(p.x, 0, p.z))
	if is_nan(h):
		return
	for cf in campfires:
		if cf.global_position.distance_to(p) < 2.0:
			_say('Too close to another fire')
			return
	inv.remove('wood', 2)
	inv.remove('matches')
	var cf := Campfire.new()
	add_child(cf)
	cf.global_position = Vector3(p.x, h, p.z)
	cf.add_wood(2)
	campfires.append(cf)
	_say('Built a campfire')

var _campfire_opt := false


var audio: GameAudio
var pause_menu: PauseMenu
var dev: DevMenu

var opts_pausetest := false
var pause_shot := ''


var _autosave_t := 0.0


func _safe_to_save() -> bool:
	if player.dead or inv == null:
		return false
	for h in get_tree().get_nodes_in_group('hostile'):
		var n := h as Node3D
		if n != null and not bool(n.call('is_dead')) and n.global_position.distance_to(player.position) < 45.0:
			return false
	return true


func save_game() -> bool:
	if inv == null or player.dead:
		return false
	var cabs: Array = []
	for cb in cabins:
		cabs.append({'stove': cb.stove_fuel_s, 'wood': cb.wood_pile, 'looted': cb.crate_looted, 'door_open': cb.door_open})
	var fires: Array = []
	for cf in campfires:
		fires.append({'x': cf.global_position.x, 'y': cf.global_position.y, 'z': cf.global_position.z, 'fuel': cf.fuel_s})
	var d := {
		'clock': {'hour': clock.hour, 'day': clock.day, 'total': clock.total_game_s},
		'player': {'x': player.position.x, 'z': player.position.z, 'yaw': player.yaw, 'pitch': player.pitch, 'hp': player.health, 'stam': player.stamina},
		'body': {'core': body.core, 'wet': body.wetness},
		'needs': {'cal': needs.calories, 'water': needs.water},
		'inv': {'counts': inv.counts, 'worn': inv.equipped_body, 'rifle_up': rifle_up},
		'cabins': cabs,
		'fires': fires,
		'wolves': _alive_list(wolves),
		'pickups': _pickup_list(),
		'bears': _alive_list(bears),
		'zombies': _alive_list(zombies),
		'deer': _alive_list(deer),
	}
	return SaveGame.write(d)


func _pickup_list() -> Array:
	var out: Array = []
	for pk in get_tree().get_nodes_in_group('pickups'):
		var ip := pk as ItemPickup
		if ip != null and not ip.is_queued_for_deletion():
			out.append({'id': ip.id, 'n': ip.n, 'x': ip.global_position.x, 'z': ip.global_position.z})
	return out


func _alive_list(arr: Array) -> Array:
	var out: Array = []
	for a in arr:
		if is_instance_valid(a) and not bool(a.call('is_dead')):
			out.append({'x': a.global_position.x, 'z': a.global_position.z, 'hp': a.hp})
	return out


func _restore_creatures(sv: Dictionary) -> void:
	for e in sv.get('pickups', []):
		if Inventory.ITEMS.has(String(e['id'])):
			ItemPickup.spawn(self, String(e['id']), int(e['n']), _ground(float(e['x']), float(e['z'])))
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
	for e in sv.get('zombies', []):
		var z := _add_zombie(_ground(float(e['x']), float(e['z'])), 500 + i)
		z.hp = float(e['hp'])
		i += 1
	i = 0
	for e in sv.get('deer', []):
		var dr := _add_deer(_ground(float(e['x']), float(e['z'])), i)
		dr.hp = float(e['hp'])
		i += 1


func _ground(x: float, z: float) -> Vector3:
	var h: float = terrain.data.get_height(Vector3(x, 0, z))
	return Vector3(x, 0.0 if is_nan(h) else h, z)


func _apply_save(sv: Dictionary) -> void:
	var c: Dictionary = sv['clock']
	clock.hour = float(c['hour'])
	clock.day = int(c['day'])
	clock.total_game_s = float(c['total'])
	var p: Dictionary = sv['player']
	player.yaw = float(p['yaw'])
	player.pitch = float(p['pitch'])
	player.health = float(p['hp'])
	player.stamina = float(p['stam'])
	body.core = float(sv['body']['core'])
	body.wetness = float(sv['body']['wet'])
	needs.calories = float(sv['needs']['cal'])
	needs.water = float(sv['needs']['water'])
	inv = Inventory.new(body)
	inv.needs = needs
	for k in sv['inv']['counts']:
		inv.add(String(k), int(sv['inv']['counts'][k]))
	if String(sv['inv']['worn']) != '':
		inv.use(String(sv['inv']['worn']))
	rifle_up = bool(sv['inv']['rifle_up']) and inv.count('rifle') > 0
	var cabs: Array = sv['cabins']
	for i in range(mini(cabs.size(), cabins.size())):
		var cb = cabins[i]
		cb.stove_fuel_s = float(cabs[i]['stove'])
		cb.wood_pile = int(cabs[i]['wood'])
		cb.crate_looted = bool(cabs[i]['looted'])
		if bool(cabs[i]['door_open']) != cb.door_open:
			cb.toggle_door()
	for f in sv['fires']:
		var cf := Campfire.new()
		add_child(cf)
		cf.global_position = Vector3(float(f['x']), float(f['y']), float(f['z']))
		cf.fuel_s = float(f['fuel'])
		campfires.append(cf)

var _savetest := ''


func _print_state() -> void:
	print('STATE pos=(%.1f,%.1f) hp=%.0f cal=%.0f core=%.2f hour=%.2f wood=%d matches=%d worn=%s fires=%d fuel=%.0f wolves=%d zombies=%d deer=%d deer0hp=%.0f' % [player.position.x, player.position.z, player.health, needs.calories, body.core, clock.hour, inv.count('wood') if inv else -1, inv.count('matches') if inv else -1, inv.equipped_body if inv else '?', campfires.size(), campfires[0].fuel_s if campfires.size() > 0 else -1.0, wolves.size(), zombies.size(), deer.size(), deer[0].hp if deer.size() > 0 else -1.0])


func _update_viewmodel() -> void:
	if viewmodel == null:
		return
	var m := 'fists'
	if inv != null:
		if rifle_up and inv.count('rifle') > 0:
			m = 'rifle'
		elif inv.count('axe') > 0:
			m = 'axe'
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
