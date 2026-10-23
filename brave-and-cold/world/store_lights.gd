class_name StoreLights
extends Node3D
## Plan A4 E4/E5: the general store's ceiling fluorescents.
##  * Grid alive and 06:00-22:00: on (cool white, a faint ballast hum).
##  * The grid dies (LookoutAssignment.grid_fail_s): buzz-and-pop, two stutters, dark. From then only fires and
##    lamps light the town.
##  * Aurora above 0.5 with the grid down (TLD aurora electrics): the dead tubes try to strike - ticks, stuttering
##    flashes, sometimes holding lit for seconds with a loud buzz. Lit flicker is a light lure (NoiseBus) every 10 s:
##    aurora nights are dangerous in town.

const AURORA_ON := 0.5
var world: Node
var store: Node3D
var force_grid = null         # tests: true / false overrides the real grid
var force_aurora := -1.0      # tests
var level := 0.0              # current brightness 0..1 (tests)
var mode := "off"             # on / off / aurora / dying
var lure_count := 0
var _tubes: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _buzz: AudioStreamPlayer3D
var _sfx: AudioStreamPlayer3D
var _was_grid := true
var _die_t := -1.0
var _strike_t := 0.0
var _hold := 0.0
var _lure_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(w: Node, s: Node3D, seed_v: int) -> void:
	world = w
	store = s
	_rng.seed = seed_v
	s.add_child(self)
	position = Vector3.ZERO
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.85, 0.87, 0.88)
	_mat.emission_enabled = true
	_mat.emission = Color(0.88, 0.94, 1.0)
	_mat.emission_energy_multiplier = 0.0
	var housing := StandardMaterial3D.new(); housing.albedo_color = Color(0.55, 0.55, 0.52); housing.roughness = 0.7
	for z in [-0.75, 0.75]:
		var h := MeshInstance3D.new()
		var hb := BoxMesh.new(); hb.size = Vector3(1.32, 0.05, 0.16)
		h.mesh = hb; h.material_override = housing
		add_child(h); h.position = Vector3(0, 2.62, z)   # hung 30 cm under the eaves line, in view
		var t := MeshInstance3D.new()
		var tb := CylinderMesh.new(); tb.top_radius = 0.018; tb.bottom_radius = 0.018; tb.height = 1.22; tb.radial_segments = 8
		t.mesh = tb; t.material_override = _mat
		add_child(t); t.position = Vector3(0, 2.575, z); t.rotation.z = PI / 2
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tubes.append(t)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.90, 0.95, 1.0); _light.omni_range = 8.5; _light.light_energy = 0.0
	_light.omni_attenuation = 0.8
	_light.shadow_enabled = false
	add_child(_light); _light.position = Vector3(0, 2.4, 0)
	_buzz = AudioStreamPlayer3D.new()
	_buzz.stream = _loop("res://assets/audio/ambient/fluoro_buzz.wav")
	_buzz.unit_size = 2.0; _buzz.max_distance = 20.0; _buzz.volume_db = -80.0
	add_child(_buzz); _buzz.position = Vector3(0, 2.8, 0)
	_sfx = AudioStreamPlayer3D.new(); _sfx.unit_size = 3.0; _sfx.max_distance = 45.0
	add_child(_sfx); _sfx.position = Vector3(0, 2.8, 0)
	_was_grid = grid()


static func _loop(path: String) -> AudioStream:
	var s = load(path)
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
		return w
	return s


func grid() -> bool:
	if force_grid != null: return bool(force_grid)
	var st = world.get("opening_state") if world != null else null
	return st == null or st.grid_alive()


func aurora() -> float:
	if force_aurora >= 0.0: return force_aurora
	var al = world.get("ambient_life") if world != null else null
	return float(al.aurora) if al != null else 0.0


func _play(name: String, db: float) -> void:
	_sfx.stream = load("res://assets/audio/ambient/%s.wav" % name)
	_sfx.volume_db = db
	_sfx.pitch_scale = _rng.randf_range(0.94, 1.06)
	_sfx.play()


func _process(delta: float) -> void:
	if world == null or world.get("clock") == null: return
	var g := grid()
	var hour: float = world.clock.hour
	if _was_grid and not g:   # the outage: buzz-and-pop, two stutters, dark
		_die_t = 0.0
		if level > 0.1: _play("elec_pop", 0.0)
	_was_grid = g
	var want := 0.0
	var buzz_db := -80.0
	if _die_t >= 0.0:
		mode = "dying"
		_die_t += delta
		want = 1.0 if fmod(_die_t, 0.28) < 0.09 and _die_t < 0.9 else 0.0
		if _die_t > 1.0: _die_t = -1.0
	elif g:
		mode = "on" if hour >= 6.0 and hour < 22.0 else "off"
		want = 1.0 if mode == "on" else 0.0
		buzz_db = -26.0 if mode == "on" else -80.0
	elif aurora() > AURORA_ON:
		mode = "aurora"
		var k := clampf((aurora() - AURORA_ON) / (1.0 - AURORA_ON), 0.0, 1.0)
		_strike_t -= delta
		if _hold > 0.0:
			_hold -= delta
			want = 0.55 + 0.35 * _rng.randf()   # a struck tube, unstable
			buzz_db = -12.0
		elif _strike_t <= 0.0:
			_strike_t = _rng.randf_range(0.15, 2.5) / (0.4 + k)
			if _rng.randf() < 0.5: _play("fluoro_tick", -6.0)
			if _rng.randf() < 0.25 + 0.35 * k: _hold = _rng.randf_range(0.4, 3.5) * (0.5 + k)
			want = _rng.randf_range(0.3, 1.0)
			buzz_db = -16.0
		if want > 0.2:
			_lure_t -= delta
			if _lure_t <= 0.0:
				_lure_t = 10.0
				lure_count += 1
				var bus = world.get("noise_bus")
				if bus != null: bus.emit_light(global_position + Vector3(0, 2, 0), 40.0, self)
	else:
		mode = "off"
	level = want if mode != "on" else move_toward(level, want, delta * 4.0)
	if mode != "on": level = want
	_mat.emission_energy_multiplier = 6.0 * level
	_light.light_energy = 2.6 * level
	if buzz_db > -79.0:
		if not _buzz.playing: _buzz.play()
		_buzz.volume_db = buzz_db
	elif _buzz.playing:
		_buzz.stop()
