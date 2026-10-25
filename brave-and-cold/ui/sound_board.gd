class_name SoundBoard
extends Control
## Dev sound board (plan A0): audition every ambient / weapon clip the way the game plays it, and leave a verdict.
##  * Near: dry 2D.  100 / 300 / 800 m: placed 100 m out in the chosen direction (front / left / right / behind
##    the camera) with the level of the real distance, exactly like AmbientLife._play_far.
##  * Scenes: the in-game layered events (howl chorus, owl duet, raven take-off, aurora static).
##  * Verdict per clip: keep / replace + a note, saved to user://sound_review.json (Troy's listening notes reach
##    the next session as a file).

const DIRS := ["res://assets/audio/ambient/", "res://assets/audio/weapons/"]
const REVIEW_PATH := "user://sound_review.json"
const DIRECTIONS := {"front": 0.0, "left": 90.0, "right": -90.0, "behind": 180.0}

var world: Node
var clips: Array[String] = []        # res:// paths
var review: Dictionary = {}           # clip name -> {"verdict": "keep"/"replace"/"", "note": ""}
var direction := "front"
var last_player: Node = null          # tests
var _list: VBoxContainer
var _dir_btns: Dictionary = {}


static func list_clips() -> Array[String]:
	var out: Array[String] = []
	for d in DIRS:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			var n := f.trim_suffix(".import").trim_suffix(".remap")
			if n.ends_with(".wav") and not out.has(d + n):
				out.append(d + n)
	out.sort()
	return out


func setup(w: Node) -> void:
	world = w
	clips = list_clips()
	_load_review()
	_build()


func _build() -> void:
	var pnl := UiKit.panel(8.0)
	pnl.custom_minimum_size = Vector2(560, 0)
	add_child(pnl)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	pnl.add_child(outer)
	outer.add_child(UiKit.label("SOUND BOARD  -  %d clips  -  verdicts save to %s" % [clips.size(), REVIEW_PATH], 14, DZ.ACCENT))
	var drow := HFlowContainer.new()
	outer.add_child(drow)
	drow.add_child(UiKit.label("Far from:", 13, DZ.DIM))
	for k in DIRECTIONS:
		var key: String = k
		_dir_btns[key] = _btn(drow, key, func() -> void: _set_dir(key))
	_set_dir("front")
	var srow := HFlowContainer.new()
	outer.add_child(srow)
	srow.add_child(UiKit.label("Scenes:", 13, DZ.DIM))
	_btn(srow, "Howl chorus", func() -> void: scene("howl"))
	_btn(srow, "Owl duet", func() -> void: scene("owl"))
	_btn(srow, "Ravens take off", func() -> void: scene("ravens"))
	_btn(srow, "Aurora static on/off", func() -> void: scene("static"))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(540, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	sc.add_child(_list)
	for c in clips:
		_row(c)


func _row(path: String) -> void:
	var name := path.get_file().get_basename()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_list.add_child(row)
	var l := UiKit.label(name, 12, DZ.TEXT)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	_btn(row, "near", func() -> void: play_near(path))
	for d in [100.0, 300.0, 800.0]:
		var dist: float = d
		_btn(row, "%d" % int(dist), func() -> void: play_far(path, dist))
	var r: Dictionary = review.get(name, {"verdict": "", "note": ""})
	var keep := _btn(row, "keep", func() -> void: set_verdict(name, "keep"))
	var rep := _btn(row, "replace", func() -> void: set_verdict(name, "replace"))
	keep.set_meta("clip", name); rep.set_meta("clip", name)
	_paint_verdict(keep, rep, String(r.verdict))
	var note := LineEdit.new()
	note.placeholder_text = "note"
	note.text = String(r.note)
	note.custom_minimum_size = Vector2(120, 0)
	note.add_theme_font_size_override("font_size", 12)
	note.text_submitted.connect(func(t: String) -> void: set_note(name, t))
	note.focus_exited.connect(func() -> void: set_note(name, note.text))
	row.add_child(note)
	row.set_meta("keep", keep); row.set_meta("rep", rep)


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", DZ.font())
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", DZ.TEXT)
	b.custom_minimum_size = Vector2(0, 22)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _paint_verdict(keep: Button, rep: Button, v: String) -> void:
	keep.add_theme_color_override("font_color", Color(0.55, 0.85, 0.45) if v == "keep" else DZ.DIM)
	rep.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35) if v == "replace" else DZ.DIM)


func _set_dir(k: String) -> void:
	direction = k
	for key in _dir_btns:
		(_dir_btns[key] as Button).add_theme_color_override("font_color", DZ.ACCENT if key == k else DZ.TEXT)


# ------------------------------------------------------------------ playback
func _cam() -> Node3D:
	var p = world.get("player") if world != null else null
	if p != null and p.get("cam") != null:
		return p.cam
	return get_viewport().get_camera_3d()


func play_near(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
	last_player = p
	return p


## Same model as AmbientLife._play_far: the source sits 100 m out in its true direction (panning), attenuation off,
## level falls 20 log10(d / 100) dB with the real distance. The far clips already carry air absorption and reverb;
## a dry weapon clip played "far" here also gets a gentle low-pass so it is not misleadingly bright.
func play_far(path: String, dist: float) -> AudioStreamPlayer3D:
	var cam := _cam()
	var origin := cam.global_position if cam != null else Vector3.ZERO
	var fwd := -cam.global_basis.z if cam != null else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var dir := fwd.rotated(Vector3.UP, deg_to_rad(float(DIRECTIONS[direction])))
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.volume_db = -3.0 - 20.0 * log(maxf(dist, 100.0) / 100.0) / log(10.0)
	if not path.contains("/ambient/"):
		p.attenuation_filter_cutoff_hz = clampf(9000.0 * 100.0 / dist, 1200.0, 9000.0)
		p.attenuation_filter_db = -18.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = origin + dir * 100.0
	p.play()
	last_player = p
	return p


func scene(id: String) -> void:
	var al = world.get("ambient_life") if world != null else null
	match id:
		"howl":
			if al != null: al.howl_chorus()
		"owl":
			if al != null: al.owl_call()
		"ravens":
			var cam := _cam()
			var pos := (cam.global_position if cam != null else Vector3.ZERO) + (-cam.global_basis.z if cam != null else Vector3.FORWARD) * 20.0
			if al != null:
				al._play("wings_0", pos, -4.0, 6.0, 90.0)
				al._play("raven_1", pos + Vector3(0, 3, 0), 2.0, 18.0, 420.0)
		"static":
			if al != null:
				al.force_aurora = -1.0 if al.force_aurora >= 0.0 else 1.0
				var op = world.get("opening")
				if op != null and op.get("state") != null and al.force_aurora >= 0.0:
					op.state.receiver_on = true


# ------------------------------------------------------------------ verdicts
func set_verdict(clip: String, v: String) -> void:
	var r: Dictionary = review.get(clip, {"verdict": "", "note": ""})
	r.verdict = "" if r.verdict == v else v
	review[clip] = r
	_save_review()
	for row in _list.get_children():
		var k: Button = row.get_meta("keep", null)
		if k != null and String(k.get_meta("clip", "")) == clip:
			_paint_verdict(k, row.get_meta("rep"), String(r.verdict))


func set_note(clip: String, t: String) -> void:
	var r: Dictionary = review.get(clip, {"verdict": "", "note": ""})
	if String(r.note) == t:
		return
	r.note = t
	review[clip] = r
	_save_review()


func _save_review() -> void:
	var f := FileAccess.open(REVIEW_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(review, "  "))


func _load_review() -> void:
	if not FileAccess.file_exists(REVIEW_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(REVIEW_PATH))
	if d is Dictionary:
		review = d
