extends "res://tests/visual/capture_modular_human.gd"
func shot(id:String)->void:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/resident-presence-world/"+id+".png");print("PRESENCE_WORLD_CAPTURE ",id)
func run()->void:
	create_timer(150).timeout.connect(func()->void:quit(2))
	root.content_scale_size=Vector2i(1280,720);DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/resident-presence-world"))
	SaveGame.pending={};seed(20261004);w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 700:
		await process_frame
		if w.town_life!=null and w.gear!=null:break
	freeze(w);w._frames=100;w.out_path="capture-no-autosave";w.hud.visible=false
	w.weather.lock_state(Weather.S.CLOUDY);w.weather.advance(120,0);w.clock.hour=12;w.sky_rig.apply_hour(12)
	var life:TownLife=w.town_life;var a:TownResident=life.actors.rowan
	a.global_position=life.store.to_global(Vector3(2.52,Store.FLOOR_LOCAL_Y,.32))
	w.player.position=a.to_global(Vector3(.18,1.69,-1.1));a.talking=true
	for i in 180:a._process(1.0/60)
	var eye:=a.to_global(Vector3(.14,1.71,-.65));var target:=a.to_global(Vector3(0,1.68,-.035))
	w.player.cam.global_position=eye;w.player.cam.look_at(target)
	a._blink_mesh.set_blend_shape_value(a._blink_index,0);await shot("living-attention")
	a._blink_mesh.set_blend_shape_value(a._blink_index,1);await shot("living-blink")
	a._blink_mesh.set_blend_shape_value(a._blink_index,0);a.acknowledge("relay")
	for i in 20:a._process(1.0/60)
	await shot("equipment-glance")
	life.conversation.open(a);life.conversation.choose("relay");await shot("optional-exchange");life.conversation.close()
	w.clock.day=3;w.clock.hour=18;life.update(0)
	for i in 180:a._process(1.0/60)
	await shot("unresponsive")
	w.clock.hour=21;life.update(0);w.player.god=true
	for i in 205:a._process(1.0/60)
	await shot("infected")
	w.queue_free();await process_frame;SaveGame.pending={};print("RESIDENT_PRESENCE_WORLD_CAPTURE_COMPLETE");quit()
