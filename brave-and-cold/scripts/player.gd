extends CharacterBody2D

@export var move_speed: float = 200.0
@export var sprint_speed: float = 320.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := move_speed
	var sprint_cost := maxf(Stamina.drain_rate, 0.0) * delta
	if direction != Vector2.ZERO and Input.is_action_pressed("sprint") and Stamina.can_use(sprint_cost):
		speed = sprint_speed
		Stamina.drain(sprint_cost)
	velocity = direction * speed
	move_and_slide()
