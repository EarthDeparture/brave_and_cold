class_name OptionsPanel
extends VBoxContainer
## Volume + mouse sensitivity. Applies live, saves on hide/back.

signal closed


func _init() -> void:
	add_theme_constant_override("separation", 16)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(UiKit.label("OPTIONS", 34))
	add_child(UiKit.slider_row("Master volume", 0.0, 1.0, Settings.master, func(v: float) -> void:
		Settings.master = v
		Settings.apply()))
	add_child(UiKit.slider_row("Mouse sensitivity", 0.0005, 0.006, Settings.sensitivity, func(v: float) -> void:
		Settings.sensitivity = v))
	var back := UiKit.button("Back")
	back.pressed.connect(func() -> void:
		Settings.save_all()
		closed.emit())
	add_child(back)
