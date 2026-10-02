class_name GameAudio
extends Node
## Mixes ambience (wind, muffled when sheltered), footsteps, gunshots, hits and creature voices.

const AMBIENT_BUS := "Ambient"

var player: Player
var world: Node
var wind_speed := 3.0
var _wind: AudioStreamPlayer
var _wind2: AudioStreamPlayer
var weather: Weather
var _lp: AudioEffectLowPassFilter
var _wind_db := -60.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _zstate: Dictionary = {}
var _wstate: Dictionary = {}
var _zgroan: Dictionary = {}
var _step_n := 0
var _step_player: AudioStreamPlayer


func setup(p: Player, w: Node, wind: float) -> void:
	var t0 := Time.get_ticks_msec()
	for id in ['wind', 'fire', 'gunshot', 'thud', 'groan', 'howl', 'growl', 'chop', 'crash', 'rustle', 'slice', 'glass', 'hammer', 'step00', 'step01', 'step02', 'step10', 'step11', 'step12', 'step20', 'step21', 'step22']:
		Sfx.get_stream(id)
	print('AUDIO_INIT ms=', Time.get_ticks_msec() - t0)
	player = p
	world = w
	wind_speed = wind
	_rng.randomize()
	if AudioServer.get_bus_index(AMBIENT_BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, AMBIENT_BUS)
		AudioServer.set_bus_send(idx, "Master")
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(idx, _lp)
	else:
		_lp = AudioServer.get_bus_effect(AudioServer.get_bus_index(AMBIENT_BUS), 0) as AudioEffectLowPassFilter
	_wind = AudioStreamPlayer.new()
	_wind.stream = Sfx.get_stream("wind")
	_wind.bus = AMBIENT_BUS
	_wind.volume_db = -60.0
	add_child(_wind)
	_wind.play(_rng.randf() * 20.0)
	_wind2 = AudioStreamPlayer.new()
	_wind2.stream = Sfx.get_stream('wind')
	_wind2.bus = AMBIENT_BUS
	_wind2.volume_db = -60.0
	_wind2.pitch_scale = 0.5
	add_child(_wind2)
	_wind2.play(_rng.randf() * 20.0)
	_step_player = AudioStreamPlayer.new()
	add_child(_step_player)
	p.stepped.connect(_on_step)


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	var sheltered := player.is_sheltered()
	var gust := 0.5 + 0.5 * sin(_t * 0.23) * sin(_t * 0.071 + 1.0)
	var ws := wind_speed
	if weather != null:
		ws = weather.wind
	var wn := clampf(ws / 20.0, 0.0, 1.0)
	var target := lerpf(-30.0, -5.0, sqrt(wn)) + 2.5 * gust
	var cutoff := lerpf(9000.0, 20000.0, wn)
	var low_db := lerpf(-60.0, -9.0, clampf((ws - 5.0) / 14.0, 0.0, 1.0))
	if sheltered:
		target -= 10.0
		low_db -= 6.0
		cutoff = 650.0
	_wind_db = lerpf(_wind_db, target, clampf(delta * 1.5, 0.0, 1.0))
	_wind.volume_db = _wind_db
	_wind.pitch_scale = lerpf(0.85, 1.3, wn) + 0.04 * gust
	_wind2.volume_db = lerpf(_wind2.volume_db, low_db, clampf(delta * 1.2, 0.0, 1.0))
	_wind2.pitch_scale = 0.45 + 0.25 * wn
	if _lp != null:
		_lp.cutoff_hz = lerpf(_lp.cutoff_hz, cutoff, clampf(delta * 3.0, 0.0, 1.0))
	_creatures(delta)


func _on_step(tier: int, radius: float) -> void:
	var set_id := 0 if tier <= 1 else (1 if tier <= 3 else 2)
	_step_n += 1
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.get_stream("step%d%d" % [set_id, _step_n % 3])
	p.volume_db = lerpf(-36.0, -17.0, clampf((radius - 3.0) / 15.0, 0.0, 1.0))
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func gunshot() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.get_stream("gunshot")
	p.volume_db = -2.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func play_at(id: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0, unit: float = 12.0, maxd: float = 260.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = Sfx.get_stream(id)
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = unit
	p.max_distance = maxd
	p.finished.connect(p.queue_free)
	world.add_child(p)
	p.global_position = pos
	p.play()


func hit(pos: Vector3) -> void:
	play_at("thud", pos, 0.0, _rng.randf_range(0.85, 1.15), 8.0, 80.0)


var _horde_t := 3.0
var _wired: Dictionary = {}     # creature instance id -> true (signals connected)
var _last_pos: Dictionary = {}  # id -> Vector3
var _stride: Dictionary = {}    # id -> metres walked since the last footfall
var _prune_t := 30.0
const HEAR_R := 110.0           # nothing farther than this is voiced at all (creature voices are muffled to nothing anyway)
const STEP_R := 50.0


## Extra dB and low-pass cutoff for a sound source at `pos` as heard from the player's head: walls (door and
## windows respected like bullets and zombie eyes), then hills / trunks.
func occlusion(pos: Vector3) -> Vector2:
	var eye := player.cam.global_position
	var to := pos - eye
	var d := to.length()
	if d < 1.5:
		return Vector2(0.0, 5000.0)
	var dir := to / d
	var db := 0.0
	var cut := 5000.0
	var blds: Array = world.call("_building_list")
	if HitZones.building_block(blds, eye, dir, d) < d - 0.2:
		db -= 9.0
		cut = 800.0
	if HitZones.world_block(player.terrain, world.get("forest"), eye, dir, d) < d - 0.2:
		db -= 4.0
		cut = minf(cut, 2200.0)
	return Vector2(db, cut)


func voice_of(n: Node3D, head: float) -> CreatureVoice:
	var v := n.get_node_or_null("Voice") as CreatureVoice
	if v == null:
		v = CreatureVoice.new()
		v.head_h = head
		n.add_child(v)
		if not CreatureVoice.occlusion_fn.is_valid():
			CreatureVoice.occlusion_fn = Callable(self, "occlusion")
	return v


func _wire(n: Node3D, v: CreatureVoice, kind: String) -> void:
	var id := n.get_instance_id()
	if _wired.has(id):
		return
	_wired[id] = true
	match kind:
		"zombie":
			n.connect("attacked", func() -> void: v.say("grunt", 3.0, _rng.randf_range(0.9, 1.1), 4.0, 70.0))
			n.connect("damaged", func() -> void: v.say("grunt", 0.0, _rng.randf_range(0.7, 0.85), 4.0, 60.0))
			n.connect("died", func() -> void: v.say("zdeath", 3.0, _rng.randf_range(0.9, 1.1), 5.0, 90.0))
		"wolf":
			n.connect("attacked", func() -> void: v.say("growl", 5.0, _rng.randf_range(1.2, 1.4), 5.0, 100.0))
			n.connect("damaged", func() -> void: v.say("yelp", 4.0, _rng.randf_range(0.95, 1.1), 6.0, 110.0))
			n.connect("died", func() -> void: v.say("yelp", 4.0, _rng.randf_range(0.6, 0.7), 6.0, 110.0))
		"bear":
			n.connect("attacked", func() -> void: v.say("roar", 8.0, _rng.randf_range(1.0, 1.15), 9.0, 200.0))
			n.connect("damaged", func() -> void: v.say("roar", 4.0, _rng.randf_range(1.25, 1.4), 9.0, 180.0))
			n.connect("died", func() -> void: v.say("roar", 6.0, _rng.randf_range(0.6, 0.7), 9.0, 180.0))
		"deer":
			n.connect("damaged", func() -> void: v.say("yelp", 2.0, _rng.randf_range(0.55, 0.65), 5.0, 90.0))
			n.connect("died", func() -> void: v.say("yelp", 2.0, _rng.randf_range(0.4, 0.5), 5.0, 90.0))


## Footfalls come from the creature's own movement: one every `stride` metres, loudness by speed, from the feet.
func _footsteps(n: Node3D, v: CreatureVoice, id: int, kind: String, crawling: bool) -> void:
	var p := n.global_position
	var last: Vector3 = _last_pos.get(id, p)
	_last_pos[id] = p
	var moved := Vector2(p.x - last.x, p.z - last.z).length()
	if moved > 3.0 or moved < 0.002:
		return   # teleport / spawn jump / standing still
	var acc: float = float(_stride.get(id, 0.0)) + moved
	var stride := 1.15
	var db := -19.0
	var pitch := 0.8
	var set_id := 1
	match kind:
		"zombie":
			stride = 0.85 if crawling else 1.15
			db = -27.0 if crawling else -19.0
			pitch = 0.65 if crawling else 0.8
		"wolf":
			stride = 1.5
			db = -23.0
			pitch = 1.3
			set_id = 0
		"bear":
			stride = 1.7
			db = -12.0
			pitch = 0.55
		"deer":
			stride = 1.6
			db = -21.0
			pitch = 1.45
			set_id = 0
	if acc >= stride:
		acc -= stride
		_step_n += 1
		var sp := moved / maxf(get_process_delta_time(), 0.001)
		v.step("step%d%d" % [set_id, _step_n % 3], db + clampf((sp - 1.0) * 1.5, -3.0, 5.0), pitch * _rng.randf_range(0.92, 1.08))
	_stride[id] = acc


func _creatures(delta: float) -> void:
	_horde_t -= delta
	if _horde_t <= 0.0:
		_horde_t = _rng.randf_range(6.0, 11.0)
		var pop = world.get("pop")
		if pop != null:
			var hi: Dictionary = pop.nearest_horde(player.position)
			if not hi.is_empty() and float(hi["dist"]) > 70.0 and float(hi["dist"]) < 320.0:
				var vol := clampf(float(hi["size"]) / 30.0, 0.4, 1.6)
				var dd: float = minf(float(hi["dist"]), 120.0)
				var gp: Vector3 = player.position + (hi["dir"] as Vector3) * dd + Vector3(0, 1.6, 0)
				play_at("groan", gp, 0.0 + 6.0 * vol, _rng.randf_range(0.65, 0.85), 18.0, 380.0)   # a crowd has no single body to attach to
	_prune_t -= delta
	if _prune_t <= 0.0:
		_prune_t = 30.0
		for dct in [_zstate, _wstate, _zgroan, _wired, _last_pos, _stride]:
			for k in (dct as Dictionary).keys():
				if not is_instance_id_valid(int(k)):
					(dct as Dictionary).erase(k)
	for z in world.get("zombies"):
		if not is_instance_valid(z):
			continue
		var d: float = z.global_position.distance_to(player.position)
		if d > HEAR_R:
			continue
		var id: int = z.get_instance_id()
		var v := voice_of(z, 1.6)
		_wire(z, v, "zombie")
		var st: int = z.state
		if _zstate.get(id, -1) != st and st == Zombie.State.CHASE and d < 70.0:
			v.say("groan", 6.0, _rng.randf_range(1.05, 1.25), 6.0, 140.0)
		_zstate[id] = st
		if st != Zombie.State.DEAD and st != Zombie.State.SLEEP:
			if d < STEP_R:
				_footsteps(z, v, id, "zombie", bool(z.crawling))
			var cd: float = _zgroan.get(id, _rng.randf_range(4.0, 14.0)) - delta
			if cd <= 0.0:
				v.say("groan", 3.0, _rng.randf_range(0.8, 1.0), 5.0, 110.0)
				cd = _rng.randf_range(9.0, 22.0)
			_zgroan[id] = cd
	for w in world.get("wolves"):
		if not is_instance_valid(w):
			continue
		var wd: float = w.global_position.distance_to(player.position)
		if wd > 450.0:
			continue
		var wid: int = w.get_instance_id()
		var wv := voice_of(w, 0.9)
		_wire(w, wv, "wolf")
		var wst: int = w.state
		if _wstate.get(wid, -1) != wst:
			if wst == Wolf.State.ALERT and wd < 400.0:
				wv.say("howl", 10.0, _rng.randf_range(0.95, 1.1), 16.0, 450.0)
			elif wst == Wolf.State.CHASE and wd < 120.0:
				wv.say("growl", 6.0, _rng.randf_range(0.9, 1.1), 5.0, 130.0)
		_wstate[wid] = wst
		if wd < STEP_R:
			_footsteps(w, wv, wid, "wolf", false)
	for bw in world.get("bears"):
		if not is_instance_valid(bw):
			continue
		var bd: float = bw.global_position.distance_to(player.position)
		if bd > 250.0:
			continue
		var bid: int = bw.get_instance_id()
		var bv := voice_of(bw, 1.3)
		_wire(bw, bv, "bear")
		var bst: int = bw.state
		if _wstate.get(bid, -1) != bst:
			if (bst == Wolf.State.ALERT or bst == Wolf.State.CHASE) and bd < 200.0:
				bv.say("roar", 10.0, _rng.randf_range(0.9, 1.05), 10.0, 230.0)
		_wstate[bid] = bst
		if bd < STEP_R:
			_footsteps(bw, bv, bid, "bear", false)
	for dr in world.get("deer"):
		if not is_instance_valid(dr):
			continue
		var dd2: float = dr.global_position.distance_to(player.position)
		if dd2 > 150.0:
			continue
		var did: int = dr.get_instance_id()
		var dv := voice_of(dr, 1.1)
		_wire(dr, dv, "deer")
		var dst: int = dr.state
		if _wstate.get(did, -1) != dst and dst == Deer.State.ALERT:
			dv.say("snort", 5.0, _rng.randf_range(0.9, 1.1), 6.0, 100.0)
		_wstate[did] = dst
		if dst != Deer.State.DEAD and dd2 < STEP_R:
			_footsteps(dr, dv, did, "deer", false)
