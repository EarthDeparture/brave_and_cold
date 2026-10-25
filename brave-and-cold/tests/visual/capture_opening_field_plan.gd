extends SceneTree
## Actual opening modal and home stock; no save transactions or resource grants.
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child:Node in node.get_children():freeze(child)
func shot(id:String)->void:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/opening-quality/field-plan/"+id+".png")
func run()->void:
	create_timer(120).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 600:
		await process_frame
		if w.opening!=null and w.reading!=null:break
	if w.opening==null or w.reading==null:quit(1);return
	freeze(w);w._frames=100;w.out_path="capture-no-autosave"
	w.clock.hour=10;w.sky_rig.apply_hour(10);w.hud.hide();w.viewmodel.hide()
	var t:FireLookout=w.fire_lookout
	w.player.position=t.to_global(Vector3(.2,FireLookout.DECK_Y+1.7,-.5))
	w.player.cam.look_at(t.to_global(Vector3(1.9,FireLookout.DECK_Y+.8,1.7)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/opening-quality/field-plan"))
	await shot("home-stock")
	w.opening.read_log();await shot("assignment");w.reading.close()
	w.opening_state.repair_stage=3
	w.opening.read_log();await shot("independent-survival");w.reading.close()
	w.queue_free();await process_frame;SaveGame.pending={}
	print("OPENING_FIELD_PLAN_CAPTURE_COMPLETE");quit()
