extends CharacterBody3D
## Recent audible noise takes priority over the nearest unboarded window.
@export var move_speed: float = 2.0
@export var light_detection_radius: float = 40.0
@export var noise_memory: float = 4.0

var target_window: Node3D
var noise_remaining: float = 0.0
var noise_position := Vector3.ZERO
var has_target := false
@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	add_to_group("zombies")
	NoiseEvents.emitted.connect(_hear_noise)


func _hear_noise(location: Vector3, radius: float) -> void:
	if global_position.distance_to(location) <= radius * DayNight.aggro_multiplier:
		noise_position = location
		noise_remaining = noise_memory


func _update_target(delta: float) -> void:
	noise_remaining = maxf(0.0, noise_remaining - delta)
	target_window = null
	has_target = false
	if noise_remaining > 0.0:
		agent.target_position = noise_position
		has_target = true
		return
	var detection_radius := light_detection_radius * DayNight.aggro_multiplier
	var nearest := detection_radius * detection_radius
	for window in get_tree().get_nodes_in_group("attracting_windows"):
		if window.boarded:
			continue
		var distance := global_position.distance_squared_to(window.global_position)
		if distance < nearest:
			nearest = distance
			target_window = window
	if is_instance_valid(target_window):
		agent.target_position = target_window.global_position
		has_target = true


func _physics_process(delta: float) -> void:
	_update_target(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Wait for the navigation server to synchronize before querying a path.
	if has_target and NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		if not agent.is_navigation_finished():
			var direction := agent.get_next_path_position() - global_position
			direction.y = 0.0
			direction = direction.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
	move_and_slide()
