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
	if boarded:
		boarded = false
	elif not is_open and Input.is_action_pressed("sprint") and player.consume_wood():
		boarded = true
	elif is_open:
		is_open = false
	else:
		is_open = true


func take_hit() -> void:
	if boarded or broken:
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
	# Keep the interaction collider so broken doors can still be boarded.
	$Boards.visible = boarded
	$Hinge/Panel.material_override.emission_enabled = not boarded and not is_open
	if boarded:
		$Prompt.text = "E: Remove boards"
	elif is_open:
		$Prompt.text = "E: Close door"
	else:
		$Prompt.text = "E: Open door (Sprint+E: board, 1 wood)"
