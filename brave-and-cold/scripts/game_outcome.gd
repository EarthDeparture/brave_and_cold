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
