extends StaticBody3D
## Finite wood items. Each press gathers one item.

@export var gather_stamina_cost: float = 15.0
@export var gather_noise_radius: float = 20.0
@export var wood_remaining: int = 5


func _ready() -> void:
	_update_prompt()


func interact(player: Node) -> void:
	if wood_remaining <= 0 or player.is_dead or not Stamina.can_use(gather_stamina_cost):
		return
	Stamina.drain(gather_stamina_cost)
	NoiseEvents.emit_noise(global_position, gather_noise_radius)
	wood_remaining -= 1
	player.add_wood(1)
	_update_prompt()


func _update_prompt() -> void:
	$Prompt.text = "E: Gather wood (%d) - costs stamina, makes noise" % wood_remaining if wood_remaining > 0 else "No wood remaining"
