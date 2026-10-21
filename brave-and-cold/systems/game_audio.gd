class_name GameAudio
extends Node
## Mixes ambience (wind, muffled when sheltered), footsteps, gunshots, hits and creature voices.

const AMBIENT_BUS := "Ambient"
const WORLD_BUS := "World"   # everything heard in the world (hearing loss applies); menu/UI sounds stay on Master

var detail_enabled := false
var _detail_rng := RandomNumberGenerator.new()
var _detail_timer := 24.0
const WOOD_STEP := preload("res://assets/environment_detail/audio/step_wood.wav")
const ICE_STEP := preload("res://assets/environment_detail/audio/step_ice.wav")
const SURFACE_STEPS := {
	"wood":[preload("res://assets/environment_detail/audio/surface_foley/step_wood_0.wav"),preload("res://assets/environment_detail/audio/surface_foley/step_wood_1.wav"),preload("res://assets/environment_detail/audio/surface_foley/step_wood_2.wav"),preload("res://assets/environment_detail/audio/surface_foley/step_wood_3.wav")],
	"ice":[preload("res://assets/environment_detail/audio/surface_foley/step_ice_0.wav"),preload("res://assets/environment_detail/audio/surface_foley/step_ice_1.wav"),preload("res://assets/environment_detail/audio/surface_foley/step_ice_2.wav")]
}
var _last_surface_step:Dictionary={}
const WOOD_CREAK := preload("res://assets/environment_detail/audio/timber_creak.wav")
const WINDOW_RATTLE := preload("res://assets/environment_detail/audio/window_rattle.wav")
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
	_detail_rng.seed = 8173
	_ensure_world_bus()
	get_tree().node_added.connect(_on_node_added)
	for cls in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:   # built before audio setup
		for n in get_tree().root.find_children("*", cls, true, false): _on_node_added(n)
	if AudioServer.get_bus_index(AMBIENT_BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, AMBIENT_BUS)
		AudioServer.set_bus_send(idx, WORLD_BUS)
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(idx, _lp)
	else:
		_lp = AudioServer.get_bus_effect(AudioServer.get_bus_index(AMBIENT_BUS), 0) as AudioEffectLowPassFilter
		AudioServer.set_bus_send(AudioServer.get_bus_index(AMBIENT_BUS), WORLD_BUS)
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
	var phase := weather._t if detail_enabled and weather != null else _t
	var gust := 0.5 + 0.5 * sin(phase * 0.23) * sin(phase * 0.071 + 1.0)
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
	if detail_enabled: _detail_ambience(delta, ws)
	_creatures(delta)
	_hearing(delta)


func _on_step(tier: int, radius: float) -> void:
	var set_id := 0 if tier <= 1 else (1 if tier <= 3 else 2)
	_step_n += 1
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.get_stream("step%d%d" % [set_id, _step_n % 3])
	if detail_enabled:
		if player._on_spatial_surface():
			p.stream = _surface_step("wood")
		else:
			var on_floor := false
			for cabin in player.cabins:
				if cabin.contains_xz(player.position.x, player.position.z):
					on_floor = true; break
			if on_floor: p.stream = _surface_step("wood")
			elif player.ice != null:
				var height: float = player.ice.ice_at(player.position.x,player.position.z)
				if not is_nan(height) and absf(player.position.y-player.eye_h-height)<.7:
					p.stream = _surface_step("ice")
	p.volume_db = lerpf(-36.0, -17.0, clampf((radius - 3.0) / 15.0, 0.0, 1.0))
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

func _surface_step(material:String)->AudioStream:
	var streams:Array=SURFACE_STEPS[material]
	var last:=int(_last_surface_step.get(material,-1))
	var pick:=_detail_rng.randi_range(0,streams.size()-2) if last>=0 else _detail_rng.randi_range(0,streams.size()-1)
	if last>=0 and pick>=last:pick+=1
	_last_surface_step[material]=pick
	return streams[pick]


# ------------------------------------------------------------ rifle reports (weapons W7)
# Layers from tools/audio/gen_gunshots.py: blast (open per report class, or moderated), the bullet's supersonic
# crack (only added on top of a MODERATED supersonic shot - an open blast already contains it), the environment
# tail (outdoor echo / cabin), and the action foley. All files peak at -1 dBFS; the mix lives here (dB, relative to
# the open hunting rifle). Real figures at the shooter's ear: .22 ~140 dB, rifle 155-165, moderated .22 subsonic
# ~117, moderated centrefire ~135-140 plus a crack the can cannot stop. Compressed for a game, order preserved.
const WEAP_DIR := "res://assets/audio/weapons/"
const SHOT_BASE_DB := -2.0
const REPORT_DB := {   # blast gain by class (rms-matched: see tools/audio/gunshot_report.txt)
	"rimfire": -4.0, "intermediate": 0.0, "medium": 0.0, "magnum_brake": -0.7,
	"sup_rimfire": -27.0, "sup_centre": -20.5,
}
const CRACK_DB := -10.0                 # supersonic crack over a moderated blast
const TAIL_DB := {"out": -3.0, "in": -6.0}
const TAIL_SUP_DB := -20.0              # a moderated blast excites ~20 dB less echo
const TAIL_CRACK_DB := -12.0            # what you hear echo back from a moderated supersonic shot: the crack
const MECH_DB := -14.0
const POP_DB := 4.0                     # first-round pop: a cold can full of air burns it, louder and brighter
const POP_REST_S := 90.0
var _wcache: Dictionary = {}
var _last_var: Dictionary = {}
var _last_sup_shot: Dictionary = {}     # rifle id -> ticks (ms) of its last moderated shot
var last_report: Dictionary = {}        # what the last shot played (tests / debug)


func weapon_stream(name: String) -> AudioStream:
	if _wcache.has(name): return _wcache[name]
	var path := WEAP_DIR + name + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path): s = load(path)
	elif FileAccess.file_exists(path): s = AudioStreamWAV.load_from_file(path)
	_wcache[name] = s
	return s


func _variant(base: String, n: int) -> String:
	var v := _rng.randi_range(0, n - 1)
	if n > 1 and v == int(_last_var.get(base, -1)): v = (v + 1) % n
	_last_var[base] = v
	return "%s_%d" % [base, v]


func _play2d(name: String, db: float, pitch := 1.0, delay := 0.0) -> AudioStreamPlayer:
	var s := weapon_stream(name)
	if s == null: return null
	var p := AudioStreamPlayer.new()
	p.stream = s; p.volume_db = db; p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	if delay > 0.0: get_tree().create_timer(delay).timeout.connect(func() -> void: if is_instance_valid(p): p.play())
	else: p.play()
	return p


## The player's own shot. `rid` picks the report class; a fitted moderator swaps the blast, drops the echo and
## (supersonic rounds) adds the crack; indoors a cabin slap replaces the outdoor echo. Unmoderated shots dull your
## hearing for a moment (`deafen`), more so under a roof.
func gunshot(rid := "") -> void:
	var cls := RifleDB.report_class(rid) if rid != "" else "medium"
	var sup := rid != "" and RifleDB.moderated(rid)
	var supersonic := RifleDB.supersonic(rid) if rid != "" else true
	var indoor := player != null and player.is_sheltered()
	var pitch := _rng.randf_range(0.97, 1.03)
	var blast := ("sup_rimfire" if cls == "rimfire" else "sup_centre") if sup else cls
	var db: float = SHOT_BASE_DB + float(REPORT_DB.get(blast, 0.0))
	var pop := false
	if sup:
		var now := Time.get_ticks_msec()
		pop = now - int(_last_sup_shot.get(rid, -1000000)) > int(POP_REST_S * 1000.0)
		_last_sup_shot[rid] = now
		if pop: db += POP_DB; pitch *= 1.03
	var bname := _variant("blast_" + blast, 3)
	if weapon_stream(bname) == null:   # kit not generated: the old procedural shot
		var p := AudioStreamPlayer.new(); p.stream = Sfx.get_stream("gunshot"); p.volume_db = -2.0
		p.finished.connect(p.queue_free); add_child(p); p.play()
		last_report = {"blast": "procedural"}; return
	_play2d(bname, db, pitch)
	var layers := [bname]
	if sup and supersonic:
		var cn := _variant("crack", 3); _play2d(cn, SHOT_BASE_DB + CRACK_DB, _rng.randf_range(0.98, 1.02)); layers.append(cn)
	var tail_db: float = SHOT_BASE_DB + float(TAIL_DB["in" if indoor else "out"])
	if indoor:
		_play2d("tail_in", tail_db + (TAIL_SUP_DB if sup else 0.0), pitch); layers.append("tail_in")
	elif sup:
		if supersonic: _play2d("tail_crack_out", SHOT_BASE_DB + TAIL_CRACK_DB, 1.0, 0.0); layers.append("tail_crack_out")
		var tn := _variant("tail_out", 2); _play2d(tn, tail_db + TAIL_SUP_DB - (8.0 if cls == "rimfire" else 0.0), pitch); layers.append(tn)
	else:
		var tn2 := _variant("tail_out", 2); _play2d(tn2, tail_db + (-6.0 if cls == "rimfire" else 0.0), pitch); layers.append(tn2)
	if RifleDB.action(rid) == "semi": _play2d("semi_clack", SHOT_BASE_DB + MECH_DB - 2.0, _rng.randf_range(0.95, 1.05), 0.012); layers.append("semi_clack")
	if not sup: deafen((1.6 if indoor else 1.0) * (0.55 if cls == "rimfire" else 1.0) * (1.25 if cls == "magnum_brake" else 1.0))
	last_report = {"rid": rid, "class": cls, "blast": blast, "moderated": sup, "supersonic": supersonic, "indoor": indoor, "pop": pop, "db": db, "layers": layers}


## Action foley from the viewmodel's cycle (bolt_up/back/fwd/down, lever_open/close).
const MECH_TRIM := {"dry_click": 8.0, "gate_close": 4.0, "mag_release": -2.0, "bolt_release": 2.0}
var last_mech := ""
func mech(event: String) -> void:
	last_mech = event
	_play2d(event, SHOT_BASE_DB + MECH_DB + float(MECH_TRIM.get(event, 0.0)), _rng.randf_range(0.96, 1.04))


# ------------------------------------------------------------ hearing (temporary threshold shift)
# A bare muzzle blast next to your head dulls everything for a second or two and leaves a faint ring; under a roof
# it is worse. A moderated shot does not. Low-pass on the Master bus + a quiet 5.6 kHz ring tone.
var hearing_dose := 0.0                 # 0..1.5, decays
var _hear_lp: AudioEffectLowPassFilter
var _ring: AudioStreamPlayer
const HEAR_RECOVER_S := 1.6


## World bus right after Master (a bus may only send toward Master), holding the hearing low-pass.
static func _ensure_world_bus() -> void:
	if AudioServer.get_bus_index(WORLD_BUS) != -1: return
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, WORLD_BUS)
	AudioServer.set_bus_send(1, "Master")


## Any in-world player that lands on Master goes to the World bus (radio, fires, creatures, foley), so a
## gunshot's hearing dip dulls the world but never the menu clicks (those are named UiSound_*).
func _on_node_added(n: Node) -> void:
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D:
		if String(n.name).begins_with("UiSound_"): return
		if String(n.get("bus")) == "Master": n.set("bus", WORLD_BUS)


func deafen(amount: float) -> void:
	hearing_dose = minf(1.5, hearing_dose + 0.7 * amount)


func _hearing(delta: float) -> void:
	if _hear_lp == null:
		_ensure_world_bus()
		var wb := AudioServer.get_bus_index(WORLD_BUS)
		for i in AudioServer.get_bus_effect_count(wb):   # one per session, not one per world
			if AudioServer.get_bus_effect(wb, i) is AudioEffectLowPassFilter: _hear_lp = AudioServer.get_bus_effect(wb, i)
		if _hear_lp == null:
			_hear_lp = AudioEffectLowPassFilter.new(); AudioServer.add_bus_effect(wb, _hear_lp)
		_hear_lp.cutoff_hz = 20500.0
	hearing_dose = maxf(0.0, hearing_dose - delta / HEAR_RECOVER_S * (0.6 + 0.4 * hearing_dose))
	var k := clampf(hearing_dose, 0.0, 1.0)
	_hear_lp.cutoff_hz = lerpf(20500.0, 1100.0, pow(k, 0.7))
	if k > 0.05:
		if _ring == null:
			_ring = AudioStreamPlayer.new(); _ring.stream = _ring_stream(); add_child(_ring)
			_ring.bus = "Master"   # the ring is inside your ear: not dulled by the dip it belongs to
			_ring.play()
		_ring.volume_db = lerpf(-60.0, -30.0, k)
	elif _ring != null:
		_ring.queue_free(); _ring = null


func _exit_tree() -> void:
	if _hear_lp != null: _hear_lp.cutoff_hz = 20500.0   # never leave the menu muffled
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added): get_tree().node_added.disconnect(_on_node_added)


func _ring_stream() -> AudioStreamWAV:
	var rate := 22050; var n := rate   # one second, looped
	var d := PackedByteArray(); d.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := sin(TAU * 5600.0 * t) * 0.8 + sin(TAU * 5600.0 * 1.0021 * t) * 0.2   # slow beating, like the real thing
		d.encode_s16(i * 2, int(v * 12000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.data = d
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
	return w


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
	v.kind = kind
	var id := n.get_instance_id()
	if _wired.has(id):
		return
	_wired[id] = true
	match kind:
		"zombie":
			n.connect("attacked", func() -> void: v.say("grunt", 3.0, _rng.randf_range(0.9, 1.1), 4.0, 70.0, "attack"))
			n.connect("damaged", func() -> void: v.say("grunt", 0.0, _rng.randf_range(0.7, 0.85), 4.0, 60.0, "hurt"))
			n.connect("died", func() -> void: v.say("zdeath", 3.0, _rng.randf_range(0.9, 1.1), 5.0, 90.0, "death"))
		"wolf":
			n.connect("attacked", func() -> void: v.say("growl", 5.0, _rng.randf_range(1.2, 1.4), 5.0, 100.0, "attack"))
			n.connect("damaged", func() -> void: v.say("yelp", 4.0, _rng.randf_range(0.95, 1.1), 6.0, 110.0, "hurt"))
			n.connect("died", func() -> void: v.say("yelp", 4.0, _rng.randf_range(0.6, 0.7), 6.0, 110.0, "death"))
		"bear":
			n.connect("attacked", func() -> void: v.say("roar", 8.0, _rng.randf_range(1.0, 1.15), 9.0, 200.0, "roar"))
			n.connect("damaged", func() -> void: v.say("roar", 4.0, _rng.randf_range(1.25, 1.4), 9.0, 180.0, "hurt"))
			n.connect("died", func() -> void: v.say("roar", 6.0, _rng.randf_range(0.6, 0.7), 9.0, 180.0, "death"))
		"deer":
			n.connect("damaged", func() -> void: v.say("yelp", 2.0, _rng.randf_range(0.55, 0.65), 5.0, 90.0, "hurt"))
			n.connect("died", func() -> void: v.say("yelp", 2.0, _rng.randf_range(0.4, 0.5), 5.0, 90.0, "death"))


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
			v.say("groan", 6.0, _rng.randf_range(1.05, 1.25), 6.0, 140.0, "alert")
		_zstate[id] = st
		if st != Zombie.State.DEAD and st != Zombie.State.SLEEP:
			if d < STEP_R:
				_footsteps(z, v, id, "zombie", bool(z.crawling))
			var cd: float = _zgroan.get(id, _rng.randf_range(4.0, 14.0)) - delta
			if cd <= 0.0:
				v.say("groan", 3.0, _rng.randf_range(0.8, 1.0), 5.0, 110.0, "idle")
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
				wv.say("howl", 10.0, _rng.randf_range(0.95, 1.1), 16.0, 450.0, "howl")
			elif wst == Wolf.State.CHASE and wd < 120.0:
				wv.say("growl", 6.0, _rng.randf_range(0.9, 1.1), 5.0, 130.0, "growl")
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
				bv.say("roar", 10.0, _rng.randf_range(0.9, 1.05), 10.0, 230.0, "roar")
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
			dv.say("snort", 5.0, _rng.randf_range(0.9, 1.1), 6.0, 100.0, "snort")
		_wstate[did] = dst
		if dst != Deer.State.DEAD and dd2 < STEP_R:
			_footsteps(dr, dv, did, "deer", false)

## Sparse building response follows the same weather wind as foliage and powder.
## A separate RNG avoids altering creature voice selection.
func _detail_ambience(delta: float, wind: float) -> void:
	_detail_timer -= delta
	if _detail_timer>0: return
	_detail_timer = _detail_rng.randf_range(20.0,42.0)
	var tower: FireLookout = world.fire_lookout
	if tower == null or wind<5.0: return
	var local := tower.to_local(player.global_position)
	if absf(local.x)>8.0 or absf(local.z)>8.0 or absf(local.y-FireLookout.DECK_Y)>5.0: return
	var rattle := _detail_rng.randf()<.35
	var sound := AudioStreamPlayer3D.new()
	sound.stream = WINDOW_RATTLE if rattle else WOOD_CREAK
	sound.volume_db = lerpf(-31.0,-23.0,clampf(wind/20.0,0,1))
	sound.unit_size = 3.0
	sound.max_distance = 14.0
	sound.pitch_scale = _detail_rng.randf_range(.88,1.10)
	sound.finished.connect(sound.queue_free)
	world.add_child(sound)
	sound.global_position = tower.to_global(Vector3(2.55 if rattle else -2.7,FireLookout.DECK_Y+1.7,-1.0))
	sound.play()
