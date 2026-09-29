extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var mouse_sensitivity: float = 0.002

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := basis * Vector3(input_direction.x, 0.0, input_direction.y)
	var speed := move_speed
	var sprint_cost := maxf(Stamina.drain_rate, 0.0) * delta
	if input_direction != Vector2.ZERO and Input.is_action_pressed("sprint") and Stamina.can_use(sprint_cost):
		speed = sprint_speed
		Stamina.drain(sprint_cost)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
