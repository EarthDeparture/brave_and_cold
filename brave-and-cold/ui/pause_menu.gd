class_name PauseMenu
extends CanvasLayer
## Esc menu in the title screen's style (MenuStyle): the paused game stays visible,
## darkened toward a left column of plain text items. Pauses the tree; this node keeps
## processing.

signal resumed
signal save_requested

var _save_btn: Button
var _box: VBoxContainer
var _options: OptionsPanel
var _dim: ColorRect
var _hidden: Array = []   # HUD / hands hidden while paused, restored on resume


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float a = mix(0.82, 0.45, smoothstep(0.0, 0.7, SCREEN_UV.x)); COLOR = vec4(0.012, 0.016, 0.026, a); }"
	var m := ShaderMaterial.new(); m.shader = sh; _dim.material = m
	add_child(_dim)
	_box = _column(VBoxContainer.new())
	_box.add_theme_constant_override("separation", 6)
	_box.add_child(MenuStyle.heading("PAUSED", 48))
	_box.add_child(MenuStyle.rule(260))
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 30); _box.add_child(gap)
	for spec in [["Resume", resume], ["Save Game", func() -> void: save_requested.emit()], ["Options", _show_options], ["Main Menu", _to_menu], ["Quit Game", _quit]]:
		var b := MenuStyle.item(spec[0], spec[1], 24)
		if spec[0] == "Save Game":
			_save_btn = b
		_box.add_child(b)
	_options = _column(OptionsPanel.new())
	_options.visible = false
	_options.closed.connect(func() -> void:
		_options.visible = false
		_box.visible = true
		_box.get_child(3).grab_focus())


func _column(c: Control) -> Control:
	c.anchor_left = 0.0; c.anchor_top = 0.16; c.anchor_right = 0.0; c.anchor_bottom = 0.16
	c.offset_left = 120.0
	c.grow_horizontal = Control.GROW_DIRECTION_END; c.grow_vertical = Control.GROW_DIRECTION_END
	add_child(c)
	return c


func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE and not _options.visible:
		resume()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	MenuStyle.quiet_until_ms = Time.get_ticks_msec() + 150  # opening focus grab is not a hover
	if _save_btn != null:
		_save_btn.text = "SAVE GAME"
	_box.visible = true
	_options.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_play_ui()
	_box.get_child(3).grab_focus.call_deferred()


func save_status(ok: bool) -> void:
	_save_btn.text = "SAVED" if ok else "CANNOT SAVE NOW"


func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_restore_play_ui()
	resumed.emit()


## The paused frame stays (TLD), but HUD text, status icons and the held tool go.
func _hide_play_ui() -> void:
	_hidden.clear()
	var w := get_parent()
	if w == null: return
	for key in ["hud", "viewmodel"]:
		var n: Object = w.get(key)
		if n != null and bool(n.get("visible")):
			n.set("visible", false); _hidden.append(n)

func _restore_play_ui() -> void:
	for n: Object in _hidden:
		if is_instance_valid(n): n.set("visible", true)
	_hidden.clear()


func _show_options() -> void:
	_box.visible = false
	_options.visible = true


func _to_menu() -> void:
	_restore_play_ui()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _quit() -> void:
	get_tree().quit()
