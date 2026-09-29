extends Node3D
## Spawn on the exterior navigation mesh, bounded to prevent endless growth.

const ZOMBIE = preload("res://scenes/zombie.tscn")
@export var spawn_interval: float = 30.0
@export var max_zombies: int = 12
var spawn_progress: float = 0.0


func _ready() -> void:
	DayNight.time_advanced.connect(_advance)


func _advance(seconds: float, night: bool) -> void:
	spawn_progress += seconds * (2.0 if night else 1.0)
	var interval := maxf(spawn_interval, 0.1)
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
