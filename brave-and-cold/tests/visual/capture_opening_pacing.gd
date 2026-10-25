extends SceneTree
const OUTPUT := "res://shots/opening-pacing-2026-10-06/"
var w: Node3D
func _initialize() -> void: call_deferred("run")
func freeze(n: Node) -> void:
	n.set_process(false); n.set_physics_process(false)
	for child: Node in n.get_children(): freeze(child)
func shot(id: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT+id+".png")
	print("OPENING_PACING_CAPTURE ",id)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size=Vector2i(1280,720); SaveGame.pending={}; seed(20261004)
	w=load("res://world/game_world.gd").new(); root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.reading!=null and w.gear!=null:break
	freeze(w); w.out_path="capture-no-autosave"; w._frames=100
	w.opening.read_log(); await shot("service-log-1280")
	root.size=Vector2i(800,600);await shot("service-log-800")
	w.reading.close();root.size=Vector2i(1280,720)
	w.gear.open();w.gear._process(0);await shot("starting-gear")
	w.gear.close()
	w.player.position=w.fire_lookout.to_global(Vector3(0,FireLookout.DECK_Y+Player.EYE,.3))
	w.player.cam.position=Vector3.ZERO
	w.player.cam.look_at(w.fire_lookout.to_global(w.opening.stove_point(Vector3(0,.7,.3))))
	w.hud.hide();w.viewmodel.hide();await shot("starting-home")
	print("OPENING_PACING_CAPTURE_DONE gpu=",RenderingServer.get_video_adapter_name())
	w.queue_free();await process_frame;SaveGame.pending={};quit()
