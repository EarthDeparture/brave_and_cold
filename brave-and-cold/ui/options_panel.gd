class_name OptionsPanel
extends PanelContainer
## Volume + mouse sensitivity. Applies live, saves on hide/back.

signal closed


func _init() -> void:
	var sb: StyleBoxFlat = UiKit.panel(34.0).get_theme_stylebox("panel")
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.add_child(UiKit.label("OPTIONS", 34))
	box.add_child(UiKit.slider_row("Master volume", 0.0, 1.0, Settings.master, func(v: float) -> void:
		Settings.master = v
		Settings.apply()))
	box.add_child(UiKit.slider_row("Mouse sensitivity", 0.0005, 0.006, Settings.sensitivity, func(v: float) -> void:
		Settings.sensitivity = v))
	var dev := CheckBox.new()
	dev.text = "Developer menu  (press ` key in game)"
	dev.button_pressed = Settings.dev_menu
	dev.focus_mode = Control.FOCUS_NONE
	dev.add_theme_font_override("font", DZ.font())
	dev.add_theme_font_size_override("font_size", 20)
	dev.add_theme_color_override("font_color", DZ.TEXT)
	dev.toggled.connect(func(v: bool) -> void: Settings.dev_menu = v)
	box.add_child(dev)
	var back := UiKit.button("Back")
	back.pressed.connect(func() -> void:
		Settings.save_all()
		closed.emit())
	box.add_child(back)
