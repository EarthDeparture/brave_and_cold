extends SceneTree
const OUTPUT:="res://shots/watch-dual-monitor/"
var w:Node3D
func _initialize()->void:call_deferred("run")
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for c:Node in n.get_children():freeze(c)
func camera(local:Vector3,target:Vector3)->void:
	w.player.position=w.fire_lookout.to_global(local+Vector3.UP*FireLookout.DECK_Y)
	w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(w.fire_lookout.to_global(target+Vector3.UP*FireLookout.DECK_Y));w.player.cam.make_current()
func at(elapsed:float)->void:
	var s:LookoutAssignment=w.opening.state;var absolute:=elapsed+s.calendar_origin_s
	w.clock.total_game_s=elapsed;w.clock.day=int(floor(absolute/86400))+1;w.clock.hour=fposmod(absolute,86400)/3600
	s.last_s=elapsed;w.opening.update_presentation();w.opening._radio_update();w.sky_rig.apply_hour(w.clock.hour)
func shot(name:String)->void:
	w.hud._ui.queue_redraw();w.gear._c.queue_redraw()
	for i in 12:await process_frame
	root.get_texture().get_image().save_png(OUTPUT+name+".png");print("WATCH_WALKIE_CAPTURE ",name)
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	create_timer(150).timeout.connect(func()->void:print("FAIL capture timeout");quit(2))
	root.size=Vector2i(1600,900);SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for i in 600:
		await process_frame
		if w.opening!=null and w.gear!=null:break
	freeze(w);w._ensure_gear();w.out_path="test-no-autosave";w.hud.show_monitor=false;w.viewmodel.visible=false;w.player.cam.fov=64
	w.sky_rig.apply_shelter(1)
	camera(Vector3(1.8,1.5,-.38),Vector3(1.9,1.02,-1.13));at(23400+240)
	w.hud.visible=false;w.opening.state.receiver_on=true;w.opening.update_presentation();w.opening._radio_update()
	await shot("desk_full")
	camera(Vector3(2.18,1.2,-.67),Vector3(2.13,1.00,-1.09));w.opening.state.walkie_wh=3;w.opening.update_presentation();await shot("charging_detail")
	w.opening.state.walkie_carried=true;w.opening.update_presentation();await shot("empty_cradle")
	w.hud.visible=true;w.gear.open();await shot("inventory_carried_watch")
	at(18.5*3600+60);await shot("watch_midnight")
	w.gear._craft_mode=true;root.size=Vector2i(1280,720);await shot("watch_crafting_720p")
	w.gear._craft_mode=false;w.gear.close();root.size=Vector2i(1600,900)
	w.sky_rig.apply_shelter(0)
	w.player.position=w.opening.boundary.to_global(w.opening.boundary.ground_local(1.7,6.4)+Vector3.UP*w.player.eye_h)
	w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(w.opening.boundary.to_global(w.opening.boundary.ground_local(1.7,12)+Vector3.UP*w.player.eye_h))
	at(23400+240);w.opening._radio_update();await shot("public_walkie_outside")
	w.opening.state.walkie_wh=0;w.opening._radio_update();w.gear.open();await shot("inventory_empty_watch")
	w.gear.close();w.queue_free();await process_frame;await process_frame;print("WATCH_WALKIE_CAPTURE_DONE");quit()
