extends CanvasLayer

@export var low_wood_threshold: int = 2
@export_range(0.0, 1.0) var cold_threshold: float = 0.25

@onready var day_label: Label = $DayLabel
@onready var warning_label: Label = $WarningLabel

var wood_amount: int = 0

@onready var stamina_label: Label = $StaminaLabel
@onready var temperature_label: Label = $TemperatureLabel


func _ready() -> void:
	DayNight.dawn.connect(_update_day_state)
	DayNight.dusk.connect(_update_day_state)
	_update_day_state()
	var player = get_parent().get_node("Player")
	player.wood_changed.connect(_on_wood_changed)
	_on_wood_changed(player.wood)
	Stamina.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(Stamina.current_stamina, Stamina.max_stamina)
	Temperature.exposure_changed.connect(_on_exposure_changed)
	_on_exposure_changed(Temperature.is_outdoors)
	Temperature.temperature_changed.connect(_on_temperature_changed)
	_on_temperature_changed(Temperature.current_temperature, Temperature.max_temperature)
	var fireplace = get_parent().get_node("Cottage/Fireplace")
	fireplace.lit_changed.connect(_on_fire_lit_changed)
	_on_fire_lit_changed(fireplace.is_lit())


func _on_fire_lit_changed(lit: bool) -> void:
	$FireLabel.text = "Fire: Lit" if lit else "Fire: Unlit"


func _on_temperature_changed(current: float, maximum: float) -> void:
	temperature_label.text = "Warmth: %.1f / %.0f" % [current, maximum]
	if Temperature.is_frozen:
		temperature_label.text += " — FREEZING: no warmth remaining"

	_update_warnings()


func _on_stamina_changed(current: float, _maximum: float) -> void:
	stamina_label.text = str(current)


func _on_wood_changed(amount: int) -> void:
	wood_amount = amount
	_update_warnings()
	$WoodLabel.text = "Wood: %d carried | E: gather / fuel fire / board window" % amount


func _on_exposure_changed(outdoors: bool) -> void:
	$ExposureLabel.text = "Outside: exposed" if outdoors else "Inside: sheltered"
	_update_warnings()


func _update_day_state() -> void:
	day_label.text = "Day %d — %s" % [DayNight.day_count, "Night" if DayNight.is_night else "Daytime"]
	_update_warnings()


func _update_warnings() -> void:
	var warnings: PackedStringArray = []
	if Temperature.is_outdoors:
		warnings.append("DANGER: exposed to cold and zombies — return to shelter")
	if DayNight.is_night:
		warnings.append("NIGHT: colder, more zombies")
	if wood_amount <= low_wood_threshold:
		warnings.append("LOW WOOD: gather wood")
	if Temperature.is_frozen:
		warnings.append("FREEZING: no warmth remaining")
	elif Temperature.current_temperature <= Temperature.max_temperature * cold_threshold:
		warnings.append("COLD: warm up by a lit fire")
	warning_label.text = "\n".join(warnings)
	warning_label.visible = not warnings.is_empty()
