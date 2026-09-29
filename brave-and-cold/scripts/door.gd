extends StaticBody3D
## Door in the cottage south wall. Free interact swings it open/closed;
## holding sprint while interacting on a closed door barricades it with wood,
## mirroring boardable_window.gd so zombies attack and gather at it the same way.

@export var hits_to_break: int = 3
var hits_taken := 0
var broken := false

@export var boarded: bool = false:
	set(value):
		boarded = value
		if is_node_ready():
			_apply_state()

@export var is_open: bool = false:
	set(value):
		is_open = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	add_to_group("attracting_windows")
	$Hinge/Panel.material_override = $Hinge/Panel.material_override.duplicate()
	_apply_state()


func interact(player: Node) -> void:
	if player.is_dead or player.work_remaining > 0.0:
		return
	if broken:
		player.start_barrier_work(self, "repair")
	elif boarded:
		boarded = false
	elif not is_open and Input.is_action_pressed("sprint"):
		player.start_barrier_work(self, "board")
	else:
		is_open = not is_open


func complete_barrier_work(player: Node, action: String) -> void:
	if action == "repair" and broken and player.consume_wood():
		broken = false
		hits_taken = 0
		boarded = false
		is_open = false
		_apply_state()
	elif action == "board" and not broken and not boarded and not is_open and player.consume_wood():
		boarded = true


func take_hit() -> void:
	if boarded or broken or is_open:
		return
	hits_taken += 1
	if hits_taken >= hits_to_break:
		broken = true
		_apply_state()


func _apply_state() -> void:
	var closed := not is_open or boarded
	$Hinge.rotation.y = 0.0 if closed else deg_to_rad(90.0)
	$CollisionShape3D.disabled = not closed
	$Hinge/Panel.visible = not broken
	# Layer 2 remains ray-selectable without blocking moving bodies.
	collision_layer = 2 if broken and not boarded else 1
	collision_mask = 0
	$Boards.visible = boarded
	$Hinge/Panel.material_override.emission_enabled = not boarded and not is_open
	if broken:
		$Prompt.text = "E: Repair door (1 wood) — cold breach!"
	elif boarded:
		$Prompt.text = "E: Remove boards"
	elif is_open:
		$Prompt.text = "E: Close door"
	else:
		$Prompt.text = "E: Open door (Sprint+E: board, 1 wood)"


func is_passable() -> bool:
	return not boarded and (broken or is_open)
