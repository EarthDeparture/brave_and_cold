extends StaticBody3D
## Each window owns its material so boarding never changes another window.

@export var boarded: bool = false:
	set(value):
		boarded = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	add_to_group("attracting_windows")
	$Pane.material_override = $Pane.material_override.duplicate()
	_apply_state()


func toggle_boarded() -> void:
	boarded = not boarded


func _apply_state() -> void:
	$Boards.visible = boarded
	$LightBleed.visible = not boarded
	$LightBleed.light_energy = 0.0 if boarded else 1.5
	$Pane.material_override.emission_enabled = not boarded
	$Prompt.text = "E: Remove boards" if boarded else "E: Board window"
