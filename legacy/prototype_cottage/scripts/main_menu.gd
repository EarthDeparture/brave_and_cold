extends Control


func _ready() -> void:
	# Keep the survival autoloads idle while the player is choosing.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/Menu/Start.grab_focus()


func _on_start_pressed() -> void:
	var tree := get_tree()
	var error := tree.change_scene_to_file("res://scenes/main.tscn")
	if error == OK:
		tree.paused = false
	else:
		push_error("Could not start game: %s" % error_string(error))


func _on_quit_pressed() -> void:
	get_tree().quit()
