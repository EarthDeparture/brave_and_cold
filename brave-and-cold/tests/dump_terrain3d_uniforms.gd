extends SceneTree
## Lists Terrain3D shader uniforms (needs a window, not --headless? works headless with dummy renderer only partially).
func _initialize() -> void:
	var t := Terrain3D.new()
	root.add_child(t)
	await process_frame
	await process_frame
	var rid: RID = t.material.get_shader_rid()
	for u in RenderingServer.get_shader_parameter_list(rid):
		print("U ", u.name)
	quit(0)
