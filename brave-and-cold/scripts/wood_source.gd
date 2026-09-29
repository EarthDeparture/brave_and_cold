extends StaticBody3D
## Finite wood items. Each press gathers one item.

@export var wood_remaining: int = 5


func _ready() -> void:
	_update_prompt()


func interact(player: Node) -> void:
	if wood_remaining <= 0:
		return
	wood_remaining -= 1
	player.add_wood(1)
	_update_prompt()


func _update_prompt() -> void:
	$Prompt.text = "E: Gather wood (%d)" % wood_remaining if wood_remaining > 0 else "No wood remaining"
