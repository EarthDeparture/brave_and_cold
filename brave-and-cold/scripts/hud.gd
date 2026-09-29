extends CanvasLayer

@onready var stamina_label: Label = $StaminaLabel


func _ready() -> void:
	Stamina.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(Stamina.current_stamina, Stamina.max_stamina)


func _on_stamina_changed(current: float, _maximum: float) -> void:
	stamina_label.text = str(current)
