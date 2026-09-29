extends Node3D
## Night-only spawning on the exterior ring; each day increases frequency.

const ZOMBIE = preload("res://scenes/zombie.tscn")
@export var spawn_interval: float = 15.0
@export var max_zombies: int = 12
var spawn_progress: float = 0.0


func _ready() -> void:
	DayNight.time_advanced.connect(_advance)
	DayNight.dawn.connect(_reset_progress)


func _reset_progress() -> void:
	spawn_progress = 0.0


func _advance(seconds: float, night: bool) -> void:
	if not night:
		_reset_progress()
		return
	if not is_finite(seconds) or seconds <= 0.0:
		return
	spawn_progress += seconds
	var interval := maxf(spawn_interval / maxi(DayNight.day_count, 1), 0.1)
	if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
		spawn_progress = 0.0
		return
	while spawn_progress >= interval:
		spawn_progress -= interval
		var zombie := ZOMBIE.instantiate()
		add_child(zombie)
		var angle := randf() * TAU
		zombie.global_position = global_position + Vector3(cos(angle) * 30.0, 0.1, sin(angle) * 30.0)
		if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
			spawn_progress = 0.0
			break
