extends SceneTree
const OUT:="res://shots/electrical-fieldwork-2026-10-07/"
var w:Node3D
func _initialize() -> void:call_deferred("run")
func freeze(n:Node) -> void:
	n.set_process(false);n.set_physics_process(false)
	for child:Node in n.get_children():freeze(child)
func view(position:Vector3,target:Vector3) -> void:
	w.player.position=position;w.player.cam.position=Vector3.ZERO;w.player.cam.look_at(target)
func shot(id:String) -> void:
	for frame in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png");print("ELECTRICAL_CAPTURE ",id)
func run() -> void:
	create_timer(120).timeout.connect(func()->void:quit(2))
	root.size=Vector2i(1600,900);DirAccess.make_dir_recursive_absolute(OUT)
	SaveGame.pending={};seed(20261004)
	w=load("res://world/game_world.gd").new();root.add_child(w)
	for frame in 600:
		await process_frame
		if w.opening!=null and w.opening.electrical!=null and w.gear!=null and w.reading!=null:break
	freeze(w);w.out_path="capture-no-autosave";w._frames=100;w.hud.hide();w.viewmodel.hide()
	w.weather.lock_state(Weather.S.CLEAR);w.clock.hour=12;w.clock.total_game_s=6.5*3600;w.sky_rig.apply_hour(12)
	var field:ElectricalFieldwork=w.opening.electrical
	var store:Node3D=w.stores[0]
	view(store.to_global(Vector3(.82,.30+Player.EYE,2.08)),store.to_global(Vector3(.95,1.5,1.02)));await shot("depot-controller-stock")
	var cache:Node3D=w.first_week.models[1]
	w.first_week._lid.rotation.x=-deg_to_rad(100)
	view(cache.to_global(Vector3(.2,Player.EYE,1.4)),cache.to_global(Vector3(0,.26,0)));await shot("crew-spare-packet")
	var spur:Node3D=w.first_week.models[2]
	view(spur.to_global(Vector3(-.8,Player.EYE,-1.0)),spur.to_global(Vector3(0,.60,-.1)));await shot("spur-cable-recovery")
	view(store.to_global(Vector3(.82,.30+Player.EYE,2.08)),store.to_global(Vector3(.95,1.5,1.02)))
	field.claim_packet();field.claim_controller();w.first_week.feeder_isolated=true;field.recover_cable()
	w.opening_state.last_s=20*3600;w.clock.day=2;field.update_presentation();await shot("depot-stock-issued")
	field.read_record();await shot("electrical-issue-record");w.reading.close()
	w.opening_state.grid_fail_s=0;w.opening_state.repair_stage=3;w.opening_state.solar.controller_ok=false
	w.opening.read_power_status();await shot("controller-diagnosis");w.reading.close()
	print("ELECTRICAL_CAPTURE_DONE gpu=",RenderingServer.get_video_adapter_name())
	w.queue_free();await process_frame;SaveGame.pending={};quit()
