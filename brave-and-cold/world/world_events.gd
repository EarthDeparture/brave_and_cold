class_name WorldEvents
extends Node
## Plan A4 pass 1: the world changes on its own (L5).
##  * E1 Cabins get ransacked: from D4, 1-2 a day, only while unobserved (player > 120 m and not looking). Crate
##    emptied, furniture broken or toppled, the door forced or left open, stove dead, boot trails to and from the
##    door, sometimes blood or a dropped rag. FAIRNESS: never a cabin the player claimed (10 game min inside, or a
##    chest in it) in the last 3 game days, never the start cabin, never a resident's home while they still live there.
##  * E3 Distant events (D3+, 0-3 a day, 2 h apart, seeded): another survivor shooting 500-1500 m off (real far
##    gunshot clips in their true direction + a noise lure there; the site keeps casings, a cold fire pit, boot
##    prints, a small stash, 30% a dead survivor), a red flare over a ridge at night (light lure), wolves taking a deer
##    (howls from there, then a kill the ravens find).
##  * E4/E5 live in StoreLights (grid fluorescents, the outage pop, aurora flicker + buzz + light lure).
## Deterministic from the run seed and the day; own RNG (never the global randf stream). Saved.

const FIRST_DAY := 3
const RANSACK_FROM := 4
const CLAIM_DAYS := 3.0
const CLAIM_DWELL_S := 600.0
const UNOBSERVED_R := 120.0
const DAY_S := 86400.0
const SPACING_H := 2.0

var world: Node
var enabled := true
var seed_base := 0
var rolled_day := 0
var events: Array = []          # {kind, day, at_h, done}
var claims := {}                # cabin index -> game_s last claimed
var ransacked := {}             # cabin index -> day
var pending: Array = []         # [{i, day, at_h}] ransacks waiting for an unobserved moment
var told := {}                  # cabin index -> said "Someone has been through here."
var sites: Array = []           # {kind, x, z, seed, dead} props rebuilt on load (pickups are saved by the world)
var fire := {}                  # one cabin fire per run: {day, at_h, i, start_s}
var history: Array = []         # [game_s, text] what happened, for tests / debug
var _dwell := {}
var _shots: Array = []          # [real_t, dir, dist, site]
var _flares: Array = []         # {node, light, t, site}
var _t := 0.0
var _last_game_s := -1.0
var _chest_t := 0.0
var rng := RandomNumberGenerator.new()


func setup(w: Node, run_seed: int) -> void:
	world = w
	seed_base = run_seed
	rng.seed = hash([run_seed, "a4_sfx"])
	var r := _seeded(4242)
	fire = {"day": r.randi_range(4, 6), "at_h": r.randf_range(21.0, 23.5), "i": -1, "start_s": -1.0}
	for arg: String in OS.get_cmdline_user_args():
		if arg == "noevents": enabled = false


func _now() -> float:
	return float(world.clock.total_game_s)


func _player() -> Node3D:
	return world.get("player")


# ------------------------------------------------------------------ schedule
func _seeded(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_base, salt, "a4"])
	return r


## The day's plan: 0-3 distant events at least 2 h apart, and 1-2 ransack targets from D4. Same seed + day = same day.
func roll_day(day: int) -> void:
	rolled_day = maxi(rolled_day, day)
	if day < FIRST_DAY:
		return
	var r := _seeded(day)
	var n := r.randi_range(0, 3)
	var hours: Array = []
	for k in n:
		var kind: String = ["shots", "shots", "flare", "wolfkill"][r.randi_range(0, 3)]
		var lo := 8.0 if kind == "shots" else 20.5
		var hi := 21.0 if kind == "shots" else 23.5
		for attempt in 8:
			var h := r.randf_range(lo, hi)
			var ok := true
			for e in hours: if absf(float(e) - h) < SPACING_H: ok = false
			if ok:
				hours.append(h)
				events.append({"kind": kind, "day": day, "at_h": h, "done": false})
				break
	if day >= RANSACK_FROM:
		var cands: Array = []
		for i in range(1, world.cabins.size()):
			if not ransacked.has(i): cands.append(i)
		for k in r.randi_range(1, 2):
			if cands.is_empty(): break
			var j := r.randi_range(0, cands.size() - 1)
			pending.append({"i": cands[j], "day": day, "at_h": r.randf_range(9.0, 20.0)})
			cands.remove_at(j)


func _process(delta: float) -> void:
	if world == null or world.get("clock") == null or not enabled:
		return
	_t += delta
	var now := _now()
	var gd := 0.0 if _last_game_s < 0.0 else maxf(0.0, now - _last_game_s)
	_last_game_s = now
	var day: int = world.clock.day
	while rolled_day < day:
		roll_day(rolled_day + 1)
	_claims(gd, delta)
	var hour: float = world.clock.hour
	for e in events:
		if e.done: continue
		if int(e.day) < day or (int(e.day) == day and hour >= float(e.at_h)):
			e.done = true
			var asleep := bool(world.get("_sl_on"))
			var late := int(e.day) < day or hour > float(e.at_h) + 1.0
			fire_event(String(e.kind), not (asleep or late))
	for pr in pending.duplicate():
		if int(pr.day) > day or (int(pr.day) == day and hour < float(pr.at_h)): continue
		var i: int = pr.i
		if ransacked.has(i) or i >= world.cabins.size():
			pending.erase(pr); continue
		if claimed(i):   # fairness: the player's own place is never touched (the target is dropped, not delayed)
			pending.erase(pr); _note("spared claimed cabin %d" % i); continue
		if _observed(world.cabins[i].global_position): continue
		pending.erase(pr)
		ransack(i)
	if int(fire.get("i", -1)) < 0 and day >= int(fire.day) and day <= int(fire.day) + 2:
		if (day > int(fire.day) or hour >= float(fire.at_h)) and (hour >= 20.5 or hour < 4.5):
			_try_fire()
	_update_shots()
	_update_flares(delta)


# ------------------------------------------------------------------ E1 claims + ransack
func _claims(gd: float, delta: float) -> void:
	var p := _player()
	if p == null: return
	var now := _now()
	for i in world.cabins.size():
		var cb: Cabin = world.cabins[i]
		if cb.contains_xz(p.global_position.x, p.global_position.z):
			_dwell[i] = float(_dwell.get(i, 0.0)) + gd
			if float(_dwell[i]) >= CLAIM_DWELL_S: claims[i] = now
			if ransacked.has(i) and not told.has(i):
				told[i] = true
				world._say("Someone has been through here.")
		else:
			_dwell[i] = 0.0
	_chest_t -= delta
	if _chest_t <= 0.0:   # a chest of yours inside makes the cabin yours
		_chest_t = 5.0
		var chs = world.get("chests")
		if chs != null:
			for c in chs:
				for i in world.cabins.size():
					if world.cabins[i].contains_xz(c.global_position.x, c.global_position.z): claims[i] = now


func claimed(i: int) -> bool:
	if i == 0: return true   # the start cabin
	var tl = world.get("town_life")
	if tl != null and tl.get("homes") != null:   # a resident's home while they still live there
		for id in (tl.homes as Dictionary):
			if tl.homes[id] == world.cabins[i]:
				var a = (tl.actors as Dictionary).get(id)
				if a != null and is_instance_valid(a) and a.phase <= TownResidentState.Phase.WORRIED and not a.infected and not a.is_dead(): return true
	return _now() - float(claims.get(i, -1e12)) < CLAIM_DAYS * DAY_S


func _observed(pos: Vector3) -> bool:
	var p := _player()
	if p == null: return false
	var d := p.global_position.distance_to(pos)
	if d < UNOBSERVED_R: return true
	var cam: Camera3D = p.get("cam")
	return d < 320.0 and cam != null and cam.is_position_in_frustum(pos + Vector3(0, 2, 0))


func ransack(i: int) -> void:
	var cb: Cabin = world.cabins[i]
	var r := _seeded(9000 + i * 31 + int(world.clock.day))
	cb.crate_looted = true
	cb.wood_pile = mini(cb.wood_pile, r.randi_range(0, 2))
	cb.fire.set_fuel(0.0)
	cb.refresh_fire()
	var hit := 0
	for id: String in Cabin.FURNITURE:
		var x := r.randf()
		if x < 0.15: cb.break_furniture(id); hit += 1
		elif x < 0.8 or hit == 0: cb.topple_furniture(id); hit += 1
	cb.scatter_litter(r.randi())
	var dr := r.randf()
	if dr < 0.3: cb.break_door()
	elif not cb.door_open: cb.toggle_door()   # looters leave it open (was a 25% chance to leave it shut: flaky test, not the design)
	var door := cb.door_world_pos()
	var a_in := r.randf() * TAU
	var a_out := a_in + r.randf_range(1.2, 5.0)
	var tracks: AnimalTracks = world.get("animal_tracks")
	if tracks != null:
		var age := r.randf_range(0.5, 5.0) * 3600.0
		_boot_line(tracks, door + Vector3(cos(a_in), 0, sin(a_in)) * 140.0, door, age + 600.0, r)
		_boot_line(tracks, door, door + Vector3(cos(a_out), 0, sin(a_out)) * 140.0, age, r)
		if r.randf() < 0.15:
			for k in 3: tracks.log.add(TrackLog.K.BLOOD, door.x + r.randf_range(-1.5, 1.5), door.z + r.randf_range(0.5, 3.0), r.randf() * TAU, 0.2, 0, 0, age, age)
		tracks._dirty = true
	if r.randf() < 0.25:
		var dp := door + Vector3(cos(a_out), 0, sin(a_out)) * r.randf_range(3.0, 9.0)
		dp.y = world._ground_y(dp.x, dp.z) + 0.05
		ItemPickup.spawn(world, "rag", 1, dp)
	ransacked[i] = int(world.clock.day)
	_note("ransacked cabin %d" % i)


func _boot_line(tracks: AnimalTracks, a: Vector3, b: Vector3, age: float, r: RandomNumberGenerator) -> void:
	var d := b - a; d.y = 0.0
	var L := d.length()
	if L < 1.0: return
	var dir := d / L
	var yaw := atan2(-dir.x, -dir.z)
	var right := Vector3(dir.z, 0, -dir.x)
	var s := 0.0
	var left := false
	var band_from := 0.0
	var snow: SnowField = world.get("snow")
	while s < L:
		var p := a + dir * s + right * sin(s * 0.05 + r.randf() * 0.2) * 0.6
		left = not left
		var q := p + right * (0.12 if left else -0.12)
		var ag := age + (L - s) / 1.3   # walked at 1.3 m/s: the far end is older
		if snow == null or snow.tier_at(q.x, q.z) > 0:
			tracks.log.add(TrackLog.K.BOOT, q.x, q.z, yaw + r.randf_range(-0.1, 0.1), 1.0, 0, 7, ag, ag)
		if s - band_from >= AnimalTracks.BAND_EVERY:
			var m := a + dir * ((s + band_from) * 0.5)
			tracks.log.add(TrackLog.K.BAND, m.x, m.z, yaw, s - band_from, 68, int(TrackLog.K.BOOT), ag, ag)
			band_from = s
		s += 0.72


# ------------------------------------------------------------------ E2 the cabin fire
## The farthest unclaimed cabin 300 m+ from the player (never the start cabin or a lived-in home). Retried every
## frame through the night until one qualifies.
func _try_fire() -> void:
	var p := _player()
	if p == null: return
	var best := -1
	var best_d := 300.0
	for i in range(1, world.cabins.size()):
		var cb: Cabin = world.cabins[i]
		if cb.burned or claimed(i): continue
		var d := p.global_position.distance_to(cb.global_position)
		if d >= best_d and d < 2500.0:
			best = i; best_d = d
	if best >= 0:
		start_fire(best, _now())


func start_fire(i: int, t0: float) -> void:
	fire.i = i
	fire.start_s = t0
	var cf := CabinFire.new(); cf.name = "CabinFire"
	cf.setup(world, world.cabins[i], t0)
	_note("cabin %d caught fire" % i)


func burning() -> CabinFire:
	var i := int(fire.get("i", -1))
	return world.cabins[i].on_fire if i >= 0 and i < world.cabins.size() else null


# ------------------------------------------------------------------ E3 distant events
func fire_event(kind: String, audible := true) -> void:
	var r := _seeded(int(_now()) + kind.length() * 7919)
	match kind:
		"shots":
			var site := pick_site(r, 500.0, 1500.0)
			if site == Vector3.INF: return
			var dead := r.randf() < 0.3
			_build_site("camp", site, r.randi(), dead, true)
			if audible:
				var n := r.randi_range(3, 8)
				var t := _t
				for k in n:
					_shots.append([t, site])
					t += r.randf_range(0.6, 2.2) if r.randf() < 0.6 else r.randf_range(5.0, 22.0)
			else:
				_emit_site_noise(site)
			_note("shots at %.0f m%s" % [_dist(site), "" if audible else " (unheard)"])
		"flare":
			var site2 := pick_site(r, 1000.0, 2000.0)
			if site2 == Vector3.INF: return
			if audible: _launch_flare(site2)
			_note("flare at %.0f m%s" % [_dist(site2), "" if audible else " (unseen)"])
		"wolfkill":
			var site3 := pick_site(r, 400.0, 900.0)
			if site3 == Vector3.INF: return
			var al = world.get("ambient_life")
			if audible and al != null:
				var dir := site3 - _player().global_position
				al._play_far("howl_far_%d" % r.randi_range(0, 3), dir, dir.length(), -3.0, true)
				al._play_far("howl_far_%d" % r.randi_range(0, 3), dir.rotated(Vector3.UP, 0.15), dir.length() + 40.0, -6.0, true)
			_build_site("kill", site3, r.randi(), false, true)
			_note("wolves took a deer at %.0f m" % _dist(site3))


func _dist(p: Vector3) -> float:
	return _player().global_position.distance_to(p) if _player() != null else 0.0


## A ground point d_lo..d_hi from the player, on snow, clear of buildings.
func pick_site(r: RandomNumberGenerator, d_lo: float, d_hi: float) -> Vector3:
	var pp := _player().global_position
	var snow: SnowField = world.get("snow")
	for attempt in 16:
		var a := r.randf() * TAU
		var d := r.randf_range(d_lo, d_hi)
		var p := pp + Vector3(cos(a), 0, sin(a)) * d
		var h: float = world._ground_y(p.x, p.z)
		if is_nan(h) or absf(h) > 5000.0: continue
		if snow != null and snow.tier_at(p.x, p.z) <= 0: continue
		var clear := true
		for cb in world.cabins:
			if cb.global_position.distance_to(Vector3(p.x, cb.global_position.y, p.z)) < 60.0: clear = false
		if not clear: continue
		var flat := true   # a camp / kill on gentle ground (a fire pit on a 30 degree slope reads wrong)
		for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			if absf(float(world._ground_y(p.x + o.x, p.z + o.y)) - h) > 0.8: flat = false
		if not flat: continue
		p.y = h
		return p
	return Vector3.INF


func _emit_site_noise(site: Vector3) -> void:
	var bus: NoiseBus = world.get("noise_bus")
	if bus != null: bus.emit_noise(site, 150.0, self)


func _update_shots() -> void:
	var al = world.get("ambient_life")
	var k := 0
	for s in _shots.duplicate():
		if _t < float(s[0]): continue
		_shots.erase(s)
		var site: Vector3 = s[1]
		if al != null:
			var dir := site - _player().global_position
			al._play_far("shot_far_%d" % rng.randi_range(0, 3), dir, dir.length(), 4.0, true)
		if k % 3 == 0: _emit_site_noise(site)
		k += 1


## Site props (casings, fire pit, a dead survivor's blood; or a wolf kill). `fresh` adds the pickups, crumbs and the
## carcass; a reload passes fresh = false (those are saved by the world / track log) and rebuilds only the props.
func _build_site(kind: String, p: Vector3, sd: int, dead: bool, fresh: bool) -> void:
	var r := RandomNumberGenerator.new(); r.seed = sd
	var root := Node3D.new(); root.name = "EventSite"; root.add_to_group("event_sites")
	world.add_child(root)
	root.global_position = p
	root.set_meta("kind", kind)
	if fresh: sites.append({"kind": kind, "x": p.x, "z": p.z, "seed": sd, "dead": dead})
	var tracks: AnimalTracks = world.get("animal_tracks")
	if kind == "camp":
		var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.36, 0.36, 0.38); stone.roughness = 0.95
		var ash := StandardMaterial3D.new(); ash.albedo_color = Color(0.07, 0.065, 0.06); ash.roughness = 1.0
		var brass := StandardMaterial3D.new(); brass.albedo_color = Color(0.72, 0.55, 0.24); brass.metallic = 0.85; brass.roughness = 0.35
		for k in 8:
			var m := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.11; sm.height = 0.14; sm.radial_segments = 8; sm.rings = 4
			m.mesh = sm; m.material_override = stone
			var a := TAU * k / 8.0
			root.add_child(m)
			m.position = Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45)
			m.position.y = world._ground_y(p.x + m.position.x, p.z + m.position.z) - p.y + 0.03
			m.rotation = Vector3(r.randf(), r.randf() * TAU, 0)
			m.scale = Vector3(r.randf_range(0.8, 1.3), 0.8, r.randf_range(0.8, 1.3))
		var pit := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.36; cm.bottom_radius = 0.38; cm.height = 0.03
		pit.mesh = cm; pit.material_override = ash
		root.add_child(pit); pit.position = Vector3(0, 0.0, 0)
		for k in 2 + r.randi_range(0, 2):   # charred sticks
			var st := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.05, 0.05, r.randf_range(0.3, 0.5))
			st.mesh = bm; st.material_override = ash
			root.add_child(st); st.position = Vector3(r.randf_range(-0.12, 0.12), 0.04, r.randf_range(-0.12, 0.12)); st.rotation.y = r.randf() * TAU
		var nc := r.randi_range(3, 8)
		for k in nc:
			var c := MeshInstance3D.new()
			var cy := CylinderMesh.new(); cy.top_radius = 0.0045; cy.bottom_radius = 0.0045; cy.height = 0.052; cy.radial_segments = 8
			c.mesh = cy; c.material_override = brass
			root.add_child(c)
			c.position = Vector3(r.randf_range(-2.2, 2.2), 0.01, r.randf_range(-2.2, 2.2))
			c.position.y = world._ground_y(p.x + c.position.x, p.z + c.position.z) - p.y + 0.006
			c.rotation = Vector3(PI / 2, r.randf() * TAU, 0)
		root.set_meta("casings", nc)
		if fresh:
			var pk := p + Vector3(0.9, 0, -0.6); pk.y = world._ground_y(pk.x, pk.z) + 0.05
			ItemPickup.spawn(world, "ammo", r.randi_range(2, 5), pk)
			if dead:
				var bp := p + Vector3(-1.6, 0, 1.1); bp.y = world._ground_y(bp.x, bp.z) + 0.05
				ItemPickup.spawn(world, "beans", 1, bp)
				ItemPickup.spawn(world, "bandage", 1, bp + Vector3(0.3, 0, 0.2))
				ItemPickup.spawn(world, "rag", 2, bp + Vector3(-0.2, 0, 0.35))
			if tracks != null:
				var age := 300.0
				for k in 24:   # milling round the fire
					var a := r.randf() * TAU
					var rr := r.randf_range(0.8, 2.6)
					tracks.log.add(TrackLog.K.BOOT, p.x + cos(a) * rr, p.z + sin(a) * rr, r.randf() * TAU, 1.0, 0, 8, age, age)
				var a_in := r.randf() * TAU
				_boot_line(tracks, p + Vector3(cos(a_in), 0, sin(a_in)) * 90.0, p, age + 1800.0, r)
				if dead:
					for k in 6: tracks.log.add(TrackLog.K.BLOOD, p.x - 1.6 + r.randf_range(-0.8, 0.8), p.z + 1.1 + r.randf_range(-0.8, 0.8), r.randf() * TAU, r.randf_range(0.25, 0.6), 0, 0, age, age)
					tracks.log.add(TrackLog.K.BED, p.x - 1.6, p.z + 1.1, r.randf() * TAU, 1.0, 0, 0, age, age)
				else:
					var a_out := a_in + r.randf_range(1.5, 4.5)
					_boot_line(tracks, p, p + Vector3(cos(a_out), 0, sin(a_out)) * 120.0, age - 200.0, r)
				tracks._dirty = true
	elif kind == "kill" and fresh:
		if world.has_method("_add_deer"):
			var d: Deer = world._add_deer(p, 700 + r.randi_range(0, 99))
			if d != null:
				d.hp = 0.0
				d._die()
		if tracks != null:
			for k in 30:
				var a := r.randf() * TAU
				var rr := r.randf_range(0.5, 4.0)
				tracks.log.add(TrackLog.K.WOLF, p.x + cos(a) * rr, p.z + sin(a) * rr, r.randf() * TAU, 1.0, 1, 900 + k % 3)
			for k in 5: tracks.log.add(TrackLog.K.BLOOD, p.x + r.randf_range(-1.5, 1.5), p.z + r.randf_range(-1.5, 1.5), r.randf() * TAU, r.randf_range(0.25, 0.55))
			tracks._dirty = true


func _launch_flare(site: Vector3) -> void:
	var n := Node3D.new(); n.name = "Flare"
	world.add_child(n)
	n.global_position = site
	var m := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.fixed_size = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _glow_tex()
	mat.albedo_color = Color(1.0, 0.25, 0.12)
	mat.no_depth_test = false
	m.mesh = q; m.material_override = mat
	m.scale = Vector3.ONE * 0.04
	n.add_child(m)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.28, 0.15); l.omni_range = 110.0; l.light_energy = 3.0; l.omni_attenuation = 1.6
	l.light_volumetric_fog_energy = 0.04   # a faint pink haze round it, not a red dome over the valley
	n.add_child(l)
	_flares.append({"node": n, "mesh": m, "light": l, "t": 0.0, "site": site})
	var bus: NoiseBus = world.get("noise_bus")
	if bus != null: bus.emit_light(site, 108.0, self)


var _glow: ImageTexture
func _glow_tex() -> ImageTexture:
	if _glow == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(pow(1.0 - d, 2.2) + 0.6 * exp(-d * d * 30.0), 0.0, 1.0)))
		_glow = ImageTexture.create_from_image(img)
	return _glow


## Rises ~80 m in 3 s, hangs and sinks over ~40 s with a flicker, then burns out.
func _update_flares(delta: float) -> void:
	for f in _flares.duplicate():
		f.t = float(f.t) + delta
		var t: float = f.t
		var h := 80.0 * (1.0 - pow(1.0 - clampf(t / 3.0, 0.0, 1.0), 2.0)) - maxf(0.0, t - 3.0) * 1.5
		var k := clampf((46.0 - t) / 4.0, 0.0, 1.0) * (0.85 + 0.15 * sin(t * 23.0) * sin(t * 7.3))
		(f.node as Node3D).global_position = (f.site as Vector3) + Vector3(0, h, 0)
		(f.light as OmniLight3D).light_energy = 3.0 * k
		((f.mesh as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = k
		if t > 46.0:
			(f.node as Node).queue_free()
			_flares.erase(f)


func flares_active() -> int:
	return _flares.size()


func _note(s: String) -> void:
	history.append([_now(), s])
	if history.size() > 60: history.pop_front()


# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	var bf := burning()
	if bf != null: fire.start_s = bf.start_s   # the live fire is the truth
	return {"v": 1, "rolled": rolled_day, "events": events.duplicate(true), "claims": claims.duplicate(),
		"ransacked": ransacked.duplicate(), "pending": pending.duplicate(true), "told": told.duplicate(), "sites": sites.duplicate(true),
		"fire": fire.duplicate()}


func from_dict(d: Dictionary) -> void:
	if int(d.get("v", 0)) != 1: return
	rolled_day = int(d.get("rolled", 0))
	events = d.get("events", [])
	claims = {}
	var dc: Dictionary = d.get("claims", {})
	for k in dc: claims[int(k)] = float(dc[k])
	ransacked = {}
	var dr: Dictionary = d.get("ransacked", {})
	for k in dr: ransacked[int(k)] = int(dr[k])
	told = {}
	for k in (d.get("told", {}) as Dictionary): told[int(k)] = true
	pending = []
	for pr in d.get("pending", []): pending.append({"i": int(pr.i), "day": int(pr.day), "at_h": float(pr.at_h)})
	if d.has("fire"):
		var f: Dictionary = d.fire
		fire = {"day": int(f.get("day", 5)), "at_h": float(f.get("at_h", 22.0)), "i": -1, "start_s": -1.0}
		if int(f.get("i", -1)) >= 0 and int(f.i) < world.cabins.size() and world.cabins[int(f.i)].on_fire == null:
			start_fire(int(f.i), float(f.start_s))   # stages derive from time: resumes mid-blaze, or as a cold shell
	sites = []
	for n in get_tree().get_nodes_in_group("event_sites"): n.queue_free()
	for s in d.get("sites", []):
		var p := Vector3(float(s.x), world._ground_y(float(s.x), float(s.z)), float(s.z))
		sites.append(s)
		_build_site(String(s.kind), p, int(s.seed), bool(s.dead), false)
