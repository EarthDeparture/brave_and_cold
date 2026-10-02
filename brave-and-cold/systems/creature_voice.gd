class_name CreatureVoice
extends Node3D
## Every sound ONE creature makes lives on this node, which is a child of the creature: it travels and turns with the
## model, so the 3D listener hears it from the body, not from where it stood when the sound began.
## Falloff is physical: `unit` is the distance (m) where the sound is at its set volume, 6 dB quieter per doubling beyond.
## Walls and hills between creature and listener muffle it (volume + low-pass), see GameAudio.occlusion().

const VOICES := 2

static var occlusion_fn: Callable = Callable()   # (Vector3) -> Vector2(extra_db, cutoff_hz); set by GameAudio

var head_h := 1.6
var occ_db := 0.0
var occ_cut := 5000.0
var _occ_t := 0.0
var _voices: Array[AudioStreamPlayer3D] = []
var _foot: AudioStreamPlayer3D
var _base := {}        # player -> volume before occlusion
var last_say := ""     # debug / tests
var say_count := 0
var step_count := 0


func _ready() -> void:
	name = "Voice"
	position = Vector3(0.0, head_h, 0.0)
	for i in VOICES:
		_voices.append(_mk())
	_foot = _mk()
	_foot.position = Vector3(0.0, -head_h + 0.05, 0.0)   # feet, not head
	_occ_t = randf() * 0.3


func _mk() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.max_db = 6.0
	add_child(p)
	return p


func _play(p: AudioStreamPlayer3D, id: String, db: float, pitch: float, unit: float, maxd: float) -> void:
	p.stream = Sfx.get_stream(id)
	p.pitch_scale = pitch
	p.unit_size = unit
	p.max_distance = maxd
	_base[p] = db
	p.volume_db = db + occ_db
	p.attenuation_filter_cutoff_hz = occ_cut
	p.play()


## A call / grunt / roar. Cuts off the older of the two voice players if both are busy.
func say(id: String, db: float = 0.0, pitch: float = 1.0, unit: float = 5.0, maxd: float = 110.0) -> void:
	var pick: AudioStreamPlayer3D = _voices[0]
	for v in _voices:
		if not v.playing:
			pick = v
			break
	_play(pick, id, db, pitch, unit, maxd)
	last_say = id
	say_count += 1


func step(id: String, db: float, pitch: float, unit: float = 3.0, maxd: float = 45.0) -> void:
	_play(_foot, id, db, pitch, unit, maxd)
	step_count += 1


func is_voiced() -> bool:
	for v in _voices:
		if v.playing:
			return true
	return false


func _process(delta: float) -> void:
	_occ_t -= delta
	if _occ_t > 0.0:
		return
	_occ_t = 0.3
	var tdb := 0.0
	var tcut := 5000.0
	if occlusion_fn.is_valid():
		var r: Vector2 = occlusion_fn.call(global_position)
		tdb = r.x
		tcut = r.y
	occ_db = lerpf(occ_db, tdb, 0.6)
	occ_cut = lerpf(occ_cut, tcut, 0.6)
	for p in _base.keys():
		if is_instance_valid(p):
			(p as AudioStreamPlayer3D).volume_db = float(_base[p]) + occ_db
			(p as AudioStreamPlayer3D).attenuation_filter_cutoff_hz = occ_cut
		else:
			_base.erase(p)
