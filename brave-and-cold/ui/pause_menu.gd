class_name PauseMenu
extends CanvasLayer
## Esc menu. Pauses the tree; this node keeps processing.

signal resumed

var _box: VBoxContainer
var _options: OptionsPanel
var _dim: ColorRect


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.04, 0.08, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	var t := UiKit.label("PAUSED", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	for spec in [["Resume", resume], ["Options", _show_options], ["Main Menu", _to_menu], ["Quit Game", _quit]]:
		var b := UiKit.button(spec[0])
		b.pressed.connect(spec[1])
		var c := CenterContainer.new()
		c.add_child(b)
		_box.add_child(c)
	_options = OptionsPanel.new()
	_options.set_anchors_preset(Control.PRESET_CENTER)
	_options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_options.grow_vertical = Control.GROW_DIRECTION_BOTH
	_options.visible = false
	_options.closed.connect(func() -> void:
		_options.visible = false
		_box.visible = true)
	add_child(_options)


func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE and not _options.visible:
		resume()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_box.visible = true
	_options.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _show_options() -> void:
	_box.visible = false
	_options.visible = true


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _quit() -> void:
	get_tree().quit()
