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
	if boarded:
		boarded = false
	elif player.consume_wood():
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
	# Keep the interaction collider so broken windows can still be boarded.
	$Boards.visible = boarded
	$LightBleed.visible = not boarded
	$LightBleed.light_energy = 0.0 if boarded else 1.5
	$Pane.material_override.emission_enabled = not boarded
	$Prompt.text = "E: Remove boards" if boarded else "E: Board window (1 wood)"
