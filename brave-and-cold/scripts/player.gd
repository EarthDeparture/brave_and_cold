extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var mouse_sensitivity: float = 0.002

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_interact()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)


func _physics_process(delta: float) -> void:
	_update_temperature_exposure()
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := basis * Vector3(input_direction.x, 0.0, input_direction.y)
	var speed := move_speed
	var sprint_cost := maxf(Stamina.drain_rate, 0.0) * delta
	if Temperature.is_frozen:
		speed *= 0.5
	elif input_direction != Vector2.ZERO and Input.is_action_pressed("sprint") and Stamina.can_use(sprint_cost):
		speed = sprint_speed
		Stamina.drain(sprint_cost)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


func _update_temperature_exposure() -> void:
	Temperature.is_outdoors = true
	for shelter in get_tree().get_nodes_in_group("temperature_shelters"):
		if shelter.contains_point(global_position):
			Temperature.is_outdoors = false
			break


func _interact() -> void:
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * 3.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("toggle_boarded"):
		hit.collider.toggle_boarded()
