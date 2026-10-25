extends "res://tests/visual/capture_town_life.gd"
func shot(id:String)->void:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/store-supported/"+id+".png");print("STORE_CAPTURE ",id)
func run()->void:
	create_timer(150).timeout.connect(func()->void:quit(2))
	root.content_scale_size=Vector2i(1600,900);DisplayServer.window_set_size(Vector2i(1600,900));root.size=Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/store-supported"))
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.town_life!=null and w.gear!=null:break
	freeze(w);w._frames=100;w.out_path="capture-no-autosave";w.hud.visible=false
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0);w.clock.hour=12;w.sky_rig.apply_hour(12)
	var store:Store=w.stores[0]
	look(store,Vector3(.40,2.20,1.95),Vector3(1.60,1.43,.30));await shot("counter")
	look(store,Vector3(-1.05,1.95,.5),Vector3(-.9,1.45,-1.97));await shot("shelves")
	look(store,Vector3(-1.45,1.85,.3),Vector3(-2.47,1.26,-.92));await shot("crates")
	w.queue_free();await process_frame;SaveGame.pending={};print("STORE_CAPTURE_COMPLETE");quit()
