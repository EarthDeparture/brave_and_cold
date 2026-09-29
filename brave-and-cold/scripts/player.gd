extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var mouse_sensitivity: float = 0.002

signal died(reason: String)
signal wood_changed(amount: int)
signal tool_changed(has_hammer: bool)
signal work_changed(seconds_remaining: float)

const BARRIER_WORK_SECONDS := 2.0
var has_hammer := false
var work_remaining := 0.0
var _work_target: Node
var _work_action := ""
var _work_origin := Vector3.ZERO

var is_dead := false

var wood: int = 0

var footstep_remaining: float = 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("players")
	get_parent().ready.connect(_update_temperature_exposure, CONNECT_ONE_SHOT)


func add_wood(amount: int) -> void:
	wood += maxi(amount, 0)
	wood_changed.emit(wood)


func consume_wood() -> bool:
	if wood <= 0:
		return false
	wood -= 1
	wood_changed.emit(wood)
	return true


func acquire_hammer() -> void:
	if has_hammer or is_dead:
		return
	has_hammer = true
	tool_changed.emit(has_hammer)


func start_barrier_work(target: Node, action: String) -> void:
	if is_dead or get_tree().paused or work_remaining > 0.0 or wood <= 0:
		return
	_work_target = target
	_work_action = action
	_work_origin = global_position
	work_remaining = BARRIER_WORK_SECONDS / (2.0 if has_hammer else 1.0)
	work_changed.emit(work_remaining)


func cancel_work() -> void:
	work_remaining = 0.0
	_work_target = null
	_work_action = ""
	work_changed.emit(0.0)


func _advance_work(delta: float) -> void:
	if work_remaining <= 0.0 or get_tree().paused:
		return
	if is_dead or not is_instance_valid(_work_target) or global_position.distance_to(_work_origin) > 0.5:
		cancel_work()
		return
	work_remaining = maxf(0.0, work_remaining - maxf(delta, 0.0))
	work_changed.emit(work_remaining)
	if work_remaining == 0.0:
		var target := _work_target
		var action := _work_action
		cancel_work()
		target.complete_barrier_work(self, action)


func die(reason: String) -> void:
	if is_dead:
		return
	is_dead = true
	cancel_work()
	velocity = Vector3.ZERO
	died.emit(reason)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or get_tree().paused:
		return
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
	if is_dead or get_tree().paused:
		return
	_advance_work(delta)
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
	var previous_position := global_position
	move_and_slide()
	for index in get_slide_collision_count():
		if get_slide_collision(index).get_collider().is_in_group("zombies"):
			die("A zombie caught you.")
			return
	footstep_remaining = maxf(0.0, footstep_remaining - delta)
	var horizontal_travel := Vector2(global_position.x - previous_position.x, global_position.z - previous_position.z)
	if input_direction != Vector2.ZERO and is_on_floor() and horizontal_travel.length() > 0.001 and footstep_remaining <= 0.0:
		var sprinting := speed == sprint_speed
		NoiseEvents.emit_noise(global_position, 18.0 if sprinting else 8.0)
		footstep_remaining = 0.3 if sprinting else 0.5


func _update_temperature_exposure() -> void:
	var outdoors := true
	for shelter in get_tree().get_nodes_in_group("temperature_shelters"):
		if shelter.contains_point(global_position):
			outdoors = shelter.has_breach() if shelter.has_method("has_breach") else false
			break
	Temperature.is_outdoors = outdoors


func _interact() -> void:
	if is_dead or get_tree().paused or work_remaining > 0.0:
		return
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * 3.0)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("interact"):
		hit.collider.interact(self)
