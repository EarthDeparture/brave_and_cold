extends StaticBody3D

var collected := false


func interact(player: Node) -> void:
	if collected or player.is_dead or player.has_hammer:
		return
	collected = true
	player.acquire_hammer()
	hide()
	collision_layer = 0
	queue_free()
