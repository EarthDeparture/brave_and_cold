class_name OptionsPanel
extends VBoxContainer
## Volume, mouse sensitivity, graphics preset, developer menu. Applies live, saves on Back.
## Drawn in MenuStyle (no box): the title screen and the pause menu place it in their
## left column. Esc also goes back.

signal closed

var _first: Control

func _init() -> void:
	add_theme_constant_override("separation", 10)
	add_child(MenuStyle.heading("OPTIONS"))
	add_child(MenuStyle.rule(300))
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 16); add_child(gap)
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40); grid.add_theme_constant_override("v_separation", 16)
	add_child(grid)
	var vol := _slider(grid, "Master volume", 0.0, 1.0, Settings.master, func(v: float) -> void:
		Settings.master = v
		Settings.apply())
	_first = vol
	_slider(grid, "Mouse sensitivity", 0.0005, 0.006, Settings.sensitivity, func(v: float) -> void: Settings.sensitivity = v)
	grid.add_child(_label("Graphics"))
	var gfx := OptionButton.new()
	gfx.add_theme_font_override("font", MenuStyle.item_font()); gfx.add_theme_font_size_override("font_size", 18)
	gfx.add_theme_color_override("font_color", MenuStyle.TEXT); gfx.add_theme_color_override("font_hover_color", MenuStyle.BRIGHT)
	var flat := StyleBoxFlat.new(); flat.bg_color = Color(1, 1, 1, 0.06); flat.content_margin_left = 12; flat.content_margin_right = 12
	flat.content_margin_top = 4; flat.content_margin_bottom = 4
	var flat_h := flat.duplicate() as StyleBoxFlat; flat_h.bg_color = Color(1, 1, 1, 0.12); flat_h.border_color = MenuStyle.OCHRE; flat_h.border_width_left = 2
	for k in ["normal", "pressed"]: gfx.add_theme_stylebox_override(k, flat)
	for k in ["hover", "focus"]: gfx.add_theme_stylebox_override(k, flat_h)
	for preset: String in Settings.GRAPHICS:
		gfx.add_item(preset.capitalize())
	gfx.selected = Settings.GRAPHICS.find(Settings.graphics)
	gfx.custom_minimum_size = Vector2(260, 0)
	gfx.item_selected.connect(func(i: int) -> void:
		Settings.graphics = Settings.GRAPHICS[i]
		Settings.apply_graphics(get_viewport()))   # SSAO and tree shadow casters follow on the next load
	grid.add_child(gfx)
	grid.add_child(_label("Developer menu"))
	var dev := CheckButton.new()
	dev.text = "` key in game"
	dev.button_pressed = Settings.dev_menu
	dev.add_theme_font_override("font", MenuStyle.body_font()); dev.add_theme_font_size_override("font_size", 16)
	dev.add_theme_color_override("font_color", MenuStyle.MUTED); dev.add_theme_color_override("font_hover_color", MenuStyle.TEXT)
	dev.add_theme_color_override("font_focus_color", MenuStyle.TEXT); dev.add_theme_color_override("font_pressed_color", MenuStyle.TEXT)
	dev.toggled.connect(func(v: bool) -> void: Settings.dev_menu = v)
	grid.add_child(dev)
	var note := MenuStyle.text("Graphics changes to shadows and ambient occlusion apply on the next load.", MenuStyle.body_font(), 14, MenuStyle.MUTED)
	var gap2 := Control.new(); gap2.custom_minimum_size = Vector2(0, 8); add_child(gap2)
	add_child(note)
	var gap3 := Control.new(); gap3.custom_minimum_size = Vector2(0, 18); add_child(gap3)
	add_child(MenuStyle.item("Back", _back))
	visibility_changed.connect(func() -> void:
		if visible and _first != null: _first.grab_focus.call_deferred())

func _label(s: String) -> Label:
	var l := MenuStyle.text(s.to_upper(), MenuStyle.item_font(), 18, MenuStyle.TEXT)
	l.custom_minimum_size = Vector2(240, 0)
	return l

func _slider(grid: GridContainer, title: String, lo: float, hi: float, v: float, on_change: Callable) -> HSlider:
	grid.add_child(_label(title))
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = (hi - lo) / 100.0; s.value = v
	s.custom_minimum_size = Vector2(260, 22); s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.slider(s)
	s.value_changed.connect(on_change)
	grid.add_child(s)
	return s

func _back() -> void:
	Settings.save_all()
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		_back(); get_viewport().set_input_as_handled()
