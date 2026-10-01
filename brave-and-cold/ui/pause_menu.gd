class_name PauseMenu
extends CanvasLayer
## Esc menu. Pauses the tree; this node keeps processing.

signal resumed
signal save_requested

var _save_btn: Button

var _box: VBoxContainer
var _wrap: PanelContainer
var _options: OptionsPanel
var _dim: ColorRect


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.012, 0.01, 0.74)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_wrap = UiKit.panel(34.0)
	_wrap.set_anchors_preset(Control.PRESET_CENTER)
	_wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wrap.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_wrap)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_wrap.add_child(_box)
	var t := UiKit.label("PAUSED", 44)
	_box.add_child(t)
	var rule := ColorRect.new()
	rule.color = DZ.EDGE
	rule.custom_minimum_size = Vector2(0, 2)
	_box.add_child(rule)
	for spec in [["Resume", resume], ["Save Game", func() -> void: save_requested.emit()], ["Options", _show_options], ["Main Menu", _to_menu], ["Quit Game", _quit]]:
		var b := UiKit.button(spec[0])
		b.pressed.connect(spec[1])
		if spec[0] == 'Save Game':
			_save_btn = b
		_box.add_child(b)
	_options = OptionsPanel.new()
	_options.set_anchors_preset(Control.PRESET_CENTER)
	_options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_options.grow_vertical = Control.GROW_DIRECTION_BOTH
	_options.visible = false
	_options.closed.connect(func() -> void:
		_options.visible = false
		_wrap.visible = true)
	add_child(_options)


func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE and not _options.visible:
		resume()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	if _save_btn != null:
		_save_btn.text = 'Save Game'
	_wrap.visible = true
	_options.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func save_status(ok: bool) -> void:
	_save_btn.text = 'Saved' if ok else 'Cannot save now'


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _show_options() -> void:
	_wrap.visible = false
	_options.visible = true


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _quit() -> void:
	get_tree().quit()
