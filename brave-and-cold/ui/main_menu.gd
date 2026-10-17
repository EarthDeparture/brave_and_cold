extends Control
## Title screen (TLD-style): live-looking backdrops rendered from the current game
## (tests/visual/capture_menu_bg.gd) that drift and crossfade, soft two-layer snowfall,
## a quiet serif title, plain text menu items, Continue with the save's day and time,
## a confirm before New Game overwrites a save, a Controls page, and fades in and out.
## Command-line hooks kept for tooling: menushot=<png>, autostart, autocontinue.

const GAME := "res://world/game_world.tscn"
const BACKDROPS := ["res://assets/ui/menu_bg_greenhouse.jpg", "res://assets/ui/menu_bg_lookout.jpg", "res://assets/ui/menu_bg_hamlet.jpg"]
const HOLD_S := 42.0
const FADE_S := 5.0
const TEXT := MenuStyle.TEXT
const BRIGHT := MenuStyle.BRIGHT
const MUTED := MenuStyle.MUTED
const OCHRE := MenuStyle.OCHRE
const TIPS := [
	"A fire on embers relights without a match. Feed it before it goes cold.",
	"Wind snuffs matches. Light a campfire in the lee of a trunk or a wall.",
	"Wet boots freeze toes. Dry your clothes by a stove before a long walk.",
	"Food keeps far longer in a cold box outside than in a warm cabin.",
	"Firelight carries at night. The dead come to light.",
	"A snare by a rabbit warren checks itself every hour.",
	"Tea warms you from the inside. Rose hips grow along the road.",
]

var _layers: Array[TextureRect] = []
var _cur := 0
var _main: VBoxContainer
var _items: Array[Button] = []
var _options: OptionsPanel
var _controls: Control
var _confirm: Control
var _loading: Control
var _black: ColorRect
var _wind: AudioStreamPlayer
var _starting := false

func _ready() -> void:
	Settings.load_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new(); base.color = Color(0.02, 0.025, 0.035); base.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(base)
	_add_backdrops()
	_add_grade()
	_add_snow(140, Vector2(1.2, 2.6), Vector2(40, 80), 0.45, 14.0)    # far, small, slow
	_add_snow(36, Vector2(4.0, 8.0), Vector2(90, 160), 0.30, 8.0)     # near, big, soft
	_build_main()
	_build_controls()
	_build_confirm()
	_options = OptionsPanel.new()
	_column(_options)
	_options.visible = false
	_options.closed.connect(_show_main)
	add_child(_options)
	_build_loading()
	_black = ColorRect.new(); _black.color = Color.BLACK; _black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_black)
	create_tween().tween_property(_black, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	_main.modulate.a = 0.0
	create_tween().tween_property(_main, "modulate:a", 1.0, 1.4).set_delay(0.7)
	MenuStyle.quiet_until_ms = Time.get_ticks_msec() + 700  # no tick for the opening auto-focus
	_wind = AudioStreamPlayer.new(); _wind.stream = Sfx.get_stream("wind"); _wind.volume_db = -40.0; add_child(_wind); _wind.play()
	create_tween().tween_property(_wind, "volume_db", -16.0, 2.5)
	if not _items.is_empty(): _items[0].grab_focus.call_deferred()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("menushot="):
			_black.modulate.a = 0.0; _main.modulate.a = 1.0
			var page := ""
			for b in OS.get_cmdline_user_args():
				if b.begins_with("menupage="): page = b.substr(9)
				if b.begins_with("menubg="): _show_backdrop(int(b.substr(7)), true)
			if page == "controls": _show_controls()
			elif page == "confirm": _confirm.visible = true; _main.visible = false
			elif page == "loading": _main.visible = false; _loading.visible = true
			elif page == "options": _show_options()
			await get_tree().create_timer(1.2).timeout
			get_viewport().get_texture().get_image().save_png(a.substr(9))
			print("MENU_SHOT")
			get_tree().quit()
		elif a == "autostart":
			_new_game_now()
		elif a == "autocontinue":
			_continue()

# --- backdrop ---------------------------------------------------------------

func _add_backdrops() -> void:
	var paths := BACKDROPS.filter(func(p: String) -> bool: return ResourceLoader.exists(p))
	for p: String in paths:
		var tr := TextureRect.new(); tr.texture = load(p)
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate.a = 0.0; tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr); _layers.append(tr)
	if _layers.is_empty(): return
	_cur = randi() % _layers.size()
	_layers[_cur].modulate.a = 1.0
	_drift(_layers[_cur])
	if _layers.size() > 1:
		var t := Timer.new(); t.wait_time = HOLD_S; t.autostart = true; add_child(t)
		t.timeout.connect(func() -> void: _show_backdrop((_cur + 1) % _layers.size()))

func _show_backdrop(i: int, instant := false) -> void:
	if _layers.is_empty() or i == _cur: return
	i = clampi(i, 0, _layers.size() - 1)
	var old := _layers[_cur]; var nxt := _layers[i]
	move_child(nxt, old.get_index())   # new layer under the old one, old fades out over it
	nxt.modulate.a = 1.0; _drift(nxt)
	if instant: old.modulate.a = 0.0
	else: create_tween().tween_property(old, "modulate:a", 0.0, FADE_S).set_trans(Tween.TRANS_SINE)
	_cur = i

## Slow push-in toward the subject (right third), like a held camera breathing.
func _drift(tr: TextureRect) -> void:
	var size := get_viewport_rect().size
	tr.pivot_offset = Vector2(size.x * 0.66, size.y * 0.5)
	tr.scale = Vector2.ONE
	create_tween().tween_property(tr, "scale", Vector2(1.06, 1.06), HOLD_S + FADE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Vignette, a darker wash behind the menu column, and fine animated grain.
func _add_grade() -> void:
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float grain = 0.035;
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 c = (uv - vec2(0.55, 0.5)) * vec2(1.15, 1.0);
	float vig = smoothstep(0.35, 0.95, length(c));
	float column = (1.0 - smoothstep(0.0, 0.48, uv.x)) * 0.55;
	float floor_shade = smoothstep(0.62, 1.0, uv.y) * 0.35;
	float a = clamp(vig * 0.75 + column + floor_shade, 0.0, 0.85);
	float n = (hash(floor(FRAGCOORD.xy) + floor(TIME * 24.0)) - 0.5) * grain;
	COLOR = vec4(vec3(0.012, 0.016, 0.026) + n, a + abs(n));
}"""
	var m := ShaderMaterial.new(); m.shader = sh; r.material = m
	add_child(r)

static func _flake_tex() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new(); t.gradient = g; t.width = 32; t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL; t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(0.5, 0.0)
	return t

func _add_snow(amount: int, size: Vector2, speed: Vector2, alpha: float, life: float) -> void:
	var w := get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.texture = _flake_tex()
	p.amount = amount; p.lifetime = life; p.preprocess = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(w.x * 0.75, 10)
	p.position = Vector2(w.x * 0.45, -30)
	p.direction = Vector2(0.28, 1.0); p.spread = 10.0
	p.gravity = Vector2(14, 0)
	p.initial_velocity_min = speed.x; p.initial_velocity_max = speed.y
	p.scale_amount_min = size.x / 32.0; p.scale_amount_max = size.y / 32.0
	p.color = Color(0.92, 0.95, 1.0, alpha)
	p.angular_velocity_min = -20.0; p.angular_velocity_max = 20.0
	add_child(p)

# --- type -------------------------------------------------------------------

## Body face (bundled Barlow Regular); names are only the missing-file fallback.
static func _font(names: Array, weight: int, spacing: int) -> Font: return MenuStyle.font(MenuStyle.BODY_FILE, names, weight, spacing)
static func _title_font() -> Font: return MenuStyle.title_font()
static func _menu_font() -> Font: return MenuStyle.item_font()
func _text(s: String, font: Font, size: int, col: Color) -> Label: return MenuStyle.text(s, font, size, col)

func _item(s: String, act: Callable, note := "") -> Button:
	var b := MenuStyle.item(s, act)
	if note != "": b.set_meta("note", note)
	return b

# --- pages ------------------------------------------------------------------

func _build_main() -> void:
	_main = VBoxContainer.new()
	_column(_main)
	_main.add_theme_constant_override("separation", 6)
	add_child(_main)
	_main.add_child(_text("BRAVE AND COLD", _title_font(), 54, Color(0.92, 0.91, 0.87)))
	var rule := ColorRect.new(); rule.color = Color(OCHRE, 0.75); rule.custom_minimum_size = Vector2(250, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; _main.add_child(rule)
	var tag := _text("SURVIVE THE COLD  ·  SURVIVE THE DEAD", _font(["Bahnschrift", "Segoe UI", "Arial"], 300, 4), 15, MUTED)
	_main.add_child(tag)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 56); _main.add_child(gap)
	if SaveGame.exists():
		_items.append(_item("Continue", _continue, _save_note()))
	_items.append(_item("New Game", _new_game))
	_items.append(_item("Options", _show_options))
	_items.append(_item("Controls", _show_controls))
	_items.append(_item("Quit", _quit))
	for b in _items:
		_main.add_child(b)
		if b.has_meta("note"):   # the save's day / time, tucked under Continue
			var n := _text(String(b.get_meta("note")), _font(["Bahnschrift", "Segoe UI", "Arial"], 300, 1), 15, MUTED)
			var m := MarginContainer.new(); m.add_theme_constant_override("margin_left", 26); m.add_theme_constant_override("margin_top", -8)
			m.add_theme_constant_override("margin_bottom", 8); m.add_child(n); _main.add_child(m)
	var build := _text("Pre-alpha build", _menu_font(), 13, Color(MUTED, 0.7))
	build.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build.grow_horizontal = Control.GROW_DIRECTION_BEGIN; build.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build.offset_right = -36.0; build.offset_bottom = -28.0
	add_child(build)

## Left column anchored from the top: 16% down, 6% in (scales with the window).
func _column(c: Control) -> void:
	c.anchor_left = 0.0; c.anchor_top = 0.16; c.anchor_right = 0.0; c.anchor_bottom = 0.16
	c.offset_left = get_viewport_rect().size.x * 0.0625; c.offset_top = 0.0
	c.grow_horizontal = Control.GROW_DIRECTION_END; c.grow_vertical = Control.GROW_DIRECTION_END

## "Day 2 · 14:30 · saved Oct 16, 21:04" from the save itself.
func _save_note() -> String:
	var sv := SaveGame.read()
	var parts: Array = []
	var ck: Dictionary = sv.get("clock", {}) if sv.get("clock", {}) is Dictionary else {}
	if ck.has("day"): parts.append("Day %d" % int(ck.day))
	if ck.has("hour"):
		var h := float(ck.hour); parts.append("%02d:%02d" % [int(h) % 24, int(fmod(h, 1.0) * 60.0)])
	var mt := FileAccess.get_modified_time(SaveGame.PATH)
	if mt > 0:
		var d := Time.get_datetime_dict_from_unix_time(mt + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
		var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		parts.append("saved %s %d, %02d:%02d" % [months[int(d.month) - 1], int(d.day), int(d.hour), int(d.minute)])
	return "   ·   ".join(parts)

func _page(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	_column(box)
	box.add_theme_constant_override("separation", 8)
	box.add_child(_text(title, _title_font(), 44, Color(0.92, 0.91, 0.87)))
	var rule := ColorRect.new(); rule.color = Color(OCHRE, 0.75); rule.custom_minimum_size = Vector2(300, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; box.add_child(rule)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 18); box.add_child(gap)
	box.visible = false
	add_child(box)
	return box

const BINDS := [
	["W A S D", "Move"], ["Shift", "Sprint"], ["Space", "Jump"], ["C", "Crouch: quieter, harder to see"],
	["E (hold)", "Interact, search, stoke, cook"], ["Mouse wheel", "Choose between actions"],
	["Left mouse / F", "Attack, fire"], ["Right mouse", "Aim / scope"], ["X", "Raise or lower the rifle"], ["R", "Reload"],
	["V", "Light a road flare"], ["B", "Build a campfire"], ["Tab", "Gear: clothing, food, crafting"], ["Esc", "Pause"],
]

func _build_controls() -> void:
	var box := _page("CONTROLS")
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 34); grid.add_theme_constant_override("v_separation", 2)  # Barlow lines are taller
	for row: Array in BINDS:
		grid.add_child(_text(String(row[0]).to_upper(), _menu_font(), 18, BRIGHT))
		grid.add_child(_text(String(row[1]), _font(["Bahnschrift", "Segoe UI", "Arial"], 300, 1), 18, TEXT))
	box.add_child(grid)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 22); box.add_child(gap)
	box.add_child(_item("Back", _show_main))
	_controls = box

func _build_confirm() -> void:
	var box := _page("NEW GAME")
	box.add_child(_text("Starting over replaces your saved game.", _menu_font(), 20, TEXT))
	box.add_child(_text(_save_note() if SaveGame.exists() else "", _menu_font(), 15, MUTED))
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 22); box.add_child(gap)
	box.add_child(_item("Start over", _new_game_now))
	box.add_child(_item("Back", _show_main))
	_confirm = box

func _build_loading() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 120.0; box.offset_bottom = -90.0
	box.grow_horizontal = Control.GROW_DIRECTION_END; box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.add_theme_constant_override("separation", 10)
	box.add_child(_text("ENTERING THE VALLEY", _menu_font(), 22, BRIGHT))
	box.add_child(_text(TIPS[randi() % TIPS.size()], _menu_font(), 17, MUTED))
	box.visible = false
	add_child(box)
	_loading = box

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not _starting and (_controls.visible or _confirm.visible):
		MenuStyle.sound(self, "back"); _show_main(); get_viewport().set_input_as_handled()

func _focus_first(page: Control) -> void:
	for c in page.get_children():
		if c is Button: (c as Button).grab_focus(); return

func _show_options() -> void:
	_main.visible = false; _options.visible = true

func _show_controls() -> void:
	_main.visible = false; _controls.visible = true; _focus_first(_controls)

func _show_main() -> void:
	_options.visible = false; _controls.visible = false; _confirm.visible = false
	_main.visible = true
	if not _items.is_empty(): _items[0].grab_focus()

# --- flow -------------------------------------------------------------------

func _new_game() -> void:
	if SaveGame.exists():
		_main.visible = false; _confirm.visible = true; _focus_first(_confirm)
	else:
		_new_game_now()

func _new_game_now() -> void:
	SaveGame.pending = {}
	_start()

func _continue() -> void:
	SaveGame.pending = SaveGame.read()
	_start()

func _start() -> void:
	if _starting: return
	_starting = true
	MenuStyle.sound(self, "start")
	_main.visible = false; _confirm.visible = false; _controls.visible = false
	_loading.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_wind, "volume_db", -40.0, 0.9)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME)

func _quit() -> void:
	var tw := create_tween(); tw.tween_property(_black, "modulate:a", 1.0, 0.5)
	await tw.finished
	get_tree().quit()
