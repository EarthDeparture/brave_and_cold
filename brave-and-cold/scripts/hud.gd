extends CanvasLayer

@onready var stamina_label: Label = $StaminaLabel
@onready var temperature_label: Label = $TemperatureLabel


func _ready() -> void:
	Stamina.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(Stamina.current_stamina, Stamina.max_stamina)
	Temperature.temperature_changed.connect(_on_temperature_changed)
	_on_temperature_changed(Temperature.current_temperature, Temperature.max_temperature)


func _on_temperature_changed(current: float, maximum: float) -> void:
	temperature_label.text = "Warmth: %.1f / %.0f" % [current, maximum]
	if Temperature.is_frozen:
		temperature_label.text += " — FREEZING: half speed, sprint disabled"


func _on_stamina_changed(current: float, _maximum: float) -> void:
	stamina_label.text = str(current)
