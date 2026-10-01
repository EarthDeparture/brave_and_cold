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


func _creatures(delta: float) -> void:
	for z in world.get("zombies"):
		if not is_instance_valid(z):
			continue
		var id: int = z.get_instance_id()
		var st: int = z.state
		var d: float = z.global_position.distance_to(player.position)
		if _zstate.get(id, -1) != st and st == Zombie.State.CHASE and d < 70.0:
			play_at("groan", z.global_position + Vector3(0, 1.6, 0), 4.0, _rng.randf_range(1.05, 1.25), 10.0, 120.0)
		_zstate[id] = st
		if st != Zombie.State.DEAD and d < 45.0:
			var cd: float = _zgroan.get(id, _rng.randf_range(4.0, 14.0)) - delta
			if cd <= 0.0:
				play_at("groan", z.global_position + Vector3(0, 1.6, 0), 0.0, _rng.randf_range(0.8, 1.0), 10.0, 100.0)
				cd = _rng.randf_range(9.0, 22.0)
			_zgroan[id] = cd
	for w in world.get("wolves"):
		if not is_instance_valid(w):
			continue
		var wid: int = w.get_instance_id()
		var wst: int = w.state
		if _wstate.get(wid, -1) != wst:
			var wd: float = w.global_position.distance_to(player.position)
			if wst == Wolf.State.ALERT and wd < 160.0:
				play_at("howl", w.global_position + Vector3(0, 1.0, 0), 6.0, _rng.randf_range(0.95, 1.1), 40.0, 400.0)
			elif wst == Wolf.State.CHASE and wd < 120.0:
				play_at("growl", w.global_position + Vector3(0, 0.8, 0), 4.0, _rng.randf_range(0.9, 1.1), 10.0, 120.0)
		_wstate[wid] = wst
	for bw in world.get("bears"):
		if not is_instance_valid(bw):
			continue
		var bid: int = bw.get_instance_id()
		var bst: int = bw.state
		if _wstate.get(bid, -1) != bst:
			var bd: float = bw.global_position.distance_to(player.position)
			if (bst == Wolf.State.ALERT or bst == Wolf.State.CHASE) and bd < 120.0:
				play_at("growl", bw.global_position + Vector3(0, 1.2, 0), 8.0, _rng.randf_range(0.5, 0.62), 12.0, 160.0)
		_wstate[bid] = bst
