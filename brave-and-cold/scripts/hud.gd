extends CanvasLayer
## Displays the shared stamina pool and provides a manual smoke-test control.

@onready var stamina_label: Label = $MarginContainer/VBoxContainer/StaminaLabel


func _ready() -> void:
	Stamina.stamina_changed.connect(_update_stamina)
	_update_stamina(Stamina.current_stamina, Stamina.max_stamina)


func _update_stamina(current: float, maximum: float) -> void:
	stamina_label.text = "Stamina: %.0f / %.0f" % [current, maximum]


func _on_drain_pressed() -> void:
	Stamina.drain(25.0)
