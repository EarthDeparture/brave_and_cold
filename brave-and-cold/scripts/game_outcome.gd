extends Node3D
## A night is survived at dawn. The initial dawn does not count.

@export_range(1, 100) var nights_to_survive: int = 3

var finished := false
var nights_survived := 0
var result_label: Label


func _ready() -> void:
	$Player.died.connect(_lose)
	Temperature.frozen_changed.connect(_on_frozen)
	DayNight.dawn.connect(_on_dawn)
	var overlay := CanvasLayer.new()
	overlay.name = "EndScreen"
	overlay.layer = 10
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.85)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)
	result_label = Label.new()
	result_label.name = "Result"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 32)
	result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(result_label)
	var restart_button := Button.new()
	restart_button.name = "Restart"
	restart_button.text = "Press R to restart"
	restart_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	restart_button.offset_left = -120
	restart_button.offset_right = 120
	restart_button.offset_top = 72
	restart_button.offset_bottom = 120
	var restart_key := InputEventKey.new()
	restart_key.keycode = KEY_R
	restart_button.shortcut = Shortcut.new()
	restart_button.shortcut.events = [restart_key]
	restart_button.pressed.connect(_restart)
	backdrop.add_child(restart_button)
	overlay.hide()
	_on_frozen(Temperature.is_frozen)


func _on_frozen(frozen: bool) -> void:
	if frozen and not finished:
		$Player.die("You froze to death.")


func _lose(reason: String) -> void:
	_finish("GAME OVER\n" + reason)


func _on_dawn() -> void:
	if finished:
		return
	nights_survived += 1
	if nights_survived >= maxi(nights_to_survive, 1):
		_finish("YOU WIN\nSurvived %d nights." % nights_survived)


func _finish(message: String) -> void:
	if finished:
		return
	finished = true
	result_label.text = message
	$EndScreen.show()
	$Player.velocity = Vector3.ZERO
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restart() -> void:
	if not finished:
		return
	# Autoloads survive scene reloads; restore a fresh run before _ready().
	DayNight.cycle_time = 0.0
	DayNight.day_count = 1
	Temperature.cycle_time = 0.0
	Temperature.is_night = false
	Temperature.is_outdoors = true
	Temperature.current_temperature = Temperature.max_temperature
	Stamina.current_stamina = Stamina.max_stamina
	var tree := get_tree()
	var error := tree.reload_current_scene()
	if error == OK:
		tree.paused = false
	else:
		push_error("Could not restart scene: %s" % error_string(error))
