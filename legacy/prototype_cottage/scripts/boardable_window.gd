extends StaticBody3D
## Each window owns its material so boarding never changes another window.

@export var hits_to_break: int = 3
var hits_taken := 0
var broken := false

@export var boarded: bool = false:
	set(value):
		boarded = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	add_to_group("attracting_windows")
	$Pane.material_override = $Pane.material_override.duplicate()
	_apply_state()


func interact(player: Node) -> void:
	if player.is_dead or player.work_remaining > 0.0:
		return
	if broken:
		player.start_barrier_work(self, "repair")
	elif boarded:
		boarded = false
	else:
		player.start_barrier_work(self, "board")


func complete_barrier_work(player: Node, action: String) -> void:
	if action == "repair" and broken and player.consume_wood():
		broken = false
		hits_taken = 0
		boarded = false
		_apply_state()
	elif action == "board" and not broken and not boarded and player.consume_wood():
		boarded = true


func take_hit() -> void:
	if boarded or broken:
		return
	hits_taken += 1
	if hits_taken >= hits_to_break:
		broken = true
		_apply_state()


func _apply_state() -> void:
	$Pane.visible = not broken
	# Layer 2 remains ray-selectable without blocking moving bodies.
	collision_layer = 2 if broken and not boarded else 1
	collision_mask = 0
	$Boards.visible = boarded
	$LightBleed.visible = not boarded
	$LightBleed.light_energy = 0.0 if boarded else 1.5
	$Pane.material_override.emission_enabled = not boarded
	$Prompt.text = "E: Repair window (1 wood) — cold breach!" if broken else ("E: Remove boards" if boarded else "E: Board window (1 wood)")
	if get_parent().has_method("update_window_breach"):
		get_parent().update_window_breach(self)


func is_passable() -> bool:
	return not boarded and broken
