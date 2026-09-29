extends WorldEnvironment
## Match the world's lighting to the same phase used by survival and AI.

@export var day_ambient_energy: float = 0.12
@export var night_ambient_energy: float = 0.02


func _ready() -> void:
	# Each world owns its environment, including after a scene reload.
	environment = environment.duplicate()
	DayNight.dawn.connect(_update_lighting)
	DayNight.dusk.connect(_update_lighting)
	_update_lighting()


func _update_lighting() -> void:
	var night := DayNight.is_night
	get_node("../Sun").visible = not night
	environment.ambient_light_energy = night_ambient_energy if night else day_ambient_energy
	environment.background_energy_multiplier = 0.05 if night else 1.0
